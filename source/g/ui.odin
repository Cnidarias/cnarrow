package g

import rl "vendor:raylib"

Layout :: struct {
	board:       rl.Rectangle,
	panel:       rl.Rectangle,
	new_button:  rl.Rectangle,
	size_buttons:[3]rl.Rectangle,
	diff_buttons:[3]rl.Rectangle,
}

make_layout :: proc(width, height: f32) -> Layout {
	landscape := width >= height * 1.12
	margin := max(18.0, min(width, height) * 0.035)
	layout: Layout
	if landscape {
		panel_width := max(270.0, min(390.0, width * 0.29))
		board_size := min(height - margin * 2, width - panel_width - margin * 3)
		layout.board = {margin, (height - board_size) / 2, board_size, board_size}
		layout.panel = {layout.board.x + board_size + margin, margin, panel_width, height - margin * 2}
	} else {
		panel_height := max(260.0, min(330.0, height * 0.36))
		board_size := min(width - margin * 2, height - panel_height - margin * 3)
		layout.board = {(width - board_size) / 2, margin, board_size, board_size}
		layout.panel = {margin, layout.board.y + board_size + margin, width - margin * 2, panel_height}
	}
	p := layout.panel
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

point_in :: proc(point: rl.Vector2, rect: rl.Rectangle) -> bool {
	return rl.CheckCollisionPointRec(point, rect)
}

arrow_at_point :: proc(game: ^Game, point: rl.Vector2, layout: ^Layout) -> int {
	board := &game.board
	if !point_in(point, layout.board) do return -1
	pad := layout.board.width * 0.065
	span := layout.board.width - pad * 2
	spacing := span / f32(board.side - 1)
	threshold_sq := spacing * spacing * 0.18
	for i in 0..<board.arrow_count {
		a := &board.arrows[i]
		if a.removed do continue
		for segment in 0..<a.length {
			p := arrow_cell(a, segment)
			x := layout.board.x + pad + f32(p.x) * spacing
			y := layout.board.y + pad + f32(p.y) * spacing
			dx, dy := point.x - x, point.y - y
			if dx * dx + dy * dy <= threshold_sq do return i
		}
	}
	return -1
}

handle_input :: proc(game: ^Game) {
	point, pressed := pointer_pressed()
	if !pressed do return
	layout := make_layout(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
	if game.phase == .Confirm_New {
		panel := confirmation_panel(&layout)
		cancel := rl.Rectangle{panel.x + 22, panel.y + panel.height - 66, (panel.width - 54) / 2, 44}
		confirm := rl.Rectangle{cancel.x + cancel.width + 10, cancel.y, cancel.width, cancel.height}
		if point_in(point, cancel) do game.phase = .Playing
		if point_in(point, confirm) do start_puzzle(game)
		return
	}
	if game.phase == .Complete {
		if point_in(point, completion_button(&layout)) do start_puzzle(game)
		return
	}
	if game.animation.kind != .None do return
	for i in 0..<3 {
		if point_in(point, layout.size_buttons[i]) { game.selected_size = Grid_Size(i); return }
		if point_in(point, layout.diff_buttons[i]) { game.selected_difficulty = Difficulty(i); return }
	}
	if point_in(point, layout.new_button) { request_new_puzzle(game); return }
	id := arrow_at_point(game, point, &layout)
	if id >= 0 do start_arrow_animation(game, id)
}

confirmation_panel :: proc(layout: ^Layout) -> rl.Rectangle {
	w: f32 = min(420, layout.board.width * 0.88)
	h: f32 = 200
	return {layout.board.x + (layout.board.width - w) / 2, layout.board.y + (layout.board.height - h) / 2, w, h}
}

completion_button :: proc(layout: ^Layout) -> rl.Rectangle {
	panel := confirmation_panel(layout)
	return {panel.x + 24, panel.y + panel.height - 68, panel.width - 48, 46}
}
