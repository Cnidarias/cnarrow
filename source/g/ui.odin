package g

import rl "vendor:raylib"

Layout :: struct {
	board:       rl.Rectangle,
	panel:       rl.Rectangle,
	new_button:  rl.Rectangle,
	size_buttons:[3]rl.Rectangle,
	diff_buttons:[3]rl.Rectangle,
	compact:     bool,
}

make_layout :: proc(width, height: f32) -> Layout {
	landscape := width >= height * 1.12
	margin := max(18.0, min(width, height) * 0.035)
	layout: Layout
	layout.compact = !landscape
	if landscape {
		panel_width := max(270.0, min(390.0, width * 0.29))
		board_size := min(height - margin * 2, width - panel_width - margin * 3)
		layout.board = {margin, (height - board_size) / 2, board_size, board_size}
		layout.panel = {layout.board.x + board_size + margin, margin, panel_width, height - margin * 2}
	} else {
		panel_height: f32 = 128
		button_height: f32 = 104
		layout.panel = {margin, margin, width - margin * 2, panel_height}
		layout.new_button = {margin, height - margin - button_height, width - margin * 2, button_height}
		play_top := layout.panel.y + panel_height + margin
		play_bottom := layout.new_button.y - margin
		board_size := min(width - margin * 2, play_bottom - play_top)
		board_y := play_top + (play_bottom - play_top - board_size) / 2
		layout.board = {(width - board_size) / 2, board_y, board_size, board_size}
	}
	p := layout.panel
	if layout.compact {
		return layout
	}
	button_gap: f32 = 8
	button_h: f32 = max(42, min(54, p.height * 0.15))
	row_w := (p.width - button_gap * 2) / 3
	row1 := p.y + 72
	row2 := row1 + button_h + 48
	for i in 0..<3 {
		layout.size_buttons[i] = {p.x + f32(i) * (row_w + button_gap), row1, row_w, button_h}
		layout.diff_buttons[i] = {p.x + f32(i) * (row_w + button_gap), row2, row_w, button_h}
	}
	layout.new_button = {p.x, min(p.y + p.height - button_h, row2 + button_h + 48), p.width, button_h}
	return layout
}

game_layout :: proc(game: ^Game, width, height: f32) -> Layout {
	layout := make_layout(width, height)
	if !layout.compact do return layout
	zoom := max(1.0, min(3.0, game.board_zoom))
	base := layout.board
	size := base.width * zoom
	max_pan := (size - base.width) / 2
	pan_x := max(-max_pan, min(max_pan, game.board_pan[0]))
	pan_y := max(-max_pan, min(max_pan, game.board_pan[1]))
	layout.board = {
		base.x + (base.width - size) / 2 + pan_x,
		base.y + (base.height - size) / 2 + pan_y,
		size,
		size,
	}
	return layout
}

point_in :: proc(point: rl.Vector2, rect: rl.Rectangle) -> bool {
	return rl.CheckCollisionPointRec(point, rect)
}

point_segment_distance_squared :: proc(point, start, end: rl.Vector2) -> f32 {
	dx, dy := end.x - start.x, end.y - start.y
	length_squared := dx * dx + dy * dy
	if length_squared <= 0.0001 {
		x, y := point.x - start.x, point.y - start.y
		return x * x + y * y
	}
	t := ((point.x - start.x) * dx + (point.y - start.y) * dy) / length_squared
	t = max(0.0, min(1.0, t))
	closest_x := start.x + dx * t
	closest_y := start.y + dy * t
	x, y := point.x - closest_x, point.y - closest_y
	return x * x + y * y
}

arrow_at_point :: proc(game: ^Game, point: rl.Vector2, layout: ^Layout) -> int {
	board := &game.board
	if !point_in(point, layout.board) do return -1
	pad := layout.board.width * 0.065
	span := layout.board.width - pad * 2
	spacing := span / f32(board.side - 1)
	// The whole stroke is interactive, with a forgiving but non-overlapping
	// target on dense boards. Resolve overlaps by choosing the nearest path.
	hit_radius := min(14.0, max(7.0, spacing * 0.46))
	threshold_sq := hit_radius * hit_radius
	best_distance := threshold_sq
	best_arrow := -1
	for i in 0..<board.arrow_count {
		a := &board.arrows[i]
		if a.removed do continue
		previous := grid_to_screen(board, layout, arrow_cell(board, a, 0))
		if a.length == 1 {
			distance := point_segment_distance_squared(point, previous, previous)
			if distance <= best_distance { best_distance, best_arrow = distance, i }
			continue
		}
		for segment in 1..<a.length {
			current := grid_to_screen(board, layout, arrow_cell(board, a, segment))
			distance := point_segment_distance_squared(point, previous, current)
			if distance <= best_distance {
				best_distance, best_arrow = distance, i
			}
			previous = current
		}
	}
	return best_arrow
}

handle_input :: proc(game: ^Game) {
	if game.input_suppressed do return
	point, pressed := pointer_pressed()
	if !pressed do return
	layout := game_layout(game, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
	if game.phase == .Confirm_New {
		panel := confirmation_panel(&layout)
		cancel, confirm := confirmation_buttons(&layout, panel)
		if point_in(point, cancel) do game.phase = .Playing
		if point_in(point, confirm) do start_puzzle(game)
		return
	}
	if game.phase == .Complete {
		if point_in(point, completion_button(&layout)) do start_puzzle(game)
		return
	}
	if game.animation.kind != .None do return
	if !layout.compact {
		for i in 0..<3 {
			if point_in(point, layout.size_buttons[i]) { game.selected_size = Grid_Size(i); return }
			if point_in(point, layout.diff_buttons[i]) { game.selected_difficulty = Difficulty(i); return }
		}
	}
	if point_in(point, layout.new_button) { request_new_puzzle(game); return }
	if layout.compact && (point.y < layout.panel.y + layout.panel.height || point.y > layout.new_button.y) do return
	id := arrow_at_point(game, point, &layout)
	if id >= 0 do start_arrow_animation(game, id)
}

confirmation_panel :: proc(layout: ^Layout) -> rl.Rectangle {
	w: f32 = min(420, layout.board.width * 0.88)
	h: f32 = 200
	if layout.compact {
		w = layout.board.width * 0.94
		h = min(360, layout.board.height * 0.55)
	}
	return {layout.board.x + (layout.board.width - w) / 2, layout.board.y + (layout.board.height - h) / 2, w, h}
}

confirmation_buttons :: proc(layout: ^Layout, panel: rl.Rectangle) -> (cancel, confirm: rl.Rectangle) {
	height: f32 = 44
	bottom: f32 = 22
	if layout.compact { height = min(110, panel.height * 0.3); bottom = 28 }
	cancel = {panel.x + 22, panel.y + panel.height - height - bottom, (panel.width - 54) / 2, height}
	confirm = {cancel.x + cancel.width + 10, cancel.y, cancel.width, cancel.height}
	return
}

completion_button :: proc(layout: ^Layout) -> rl.Rectangle {
	panel := confirmation_panel(layout)
	height: f32 = 46
	bottom: f32 = 22
	if layout.compact { height = min(110, panel.height * 0.3); bottom = 28 }
	return {panel.x + 24, panel.y + panel.height - height - bottom, panel.width - 48, height}
}
