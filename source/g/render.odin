package g

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

SAGE       :: rl.Color{211, 224, 205, 255}
SAGE_DARK  :: rl.Color{151, 174, 148, 255}
INK        :: rl.Color{29, 35, 31, 255}
PANEL      :: rl.Color{227, 235, 222, 255}
SELECTED   :: rl.Color{111, 139, 111, 255}
SOFT_WHITE :: rl.Color{244, 247, 241, 255}

draw_text_centered :: proc(text: cstring, rect: rl.Rectangle, size: int, color: rl.Color) {
	w := f32(rl.MeasureText(text, i32(size)))
	rl.DrawText(text, i32(rect.x + (rect.width - w) / 2), i32(rect.y + (rect.height - f32(size)) / 2), i32(size), color)
}

draw_button :: proc(rect: rl.Rectangle, label: cstring, selected := false) {
	color := SOFT_WHITE
	text_color := INK
	if selected { color = SELECTED; text_color = SOFT_WHITE }
	rl.DrawRectangleRounded(rect, 0.28, 8, color)
	rl.DrawRectangleRoundedLinesEx(rect, 0.28, 8, 1.5, SAGE_DARK)
	font_size := int(max(16.0, min(21.0, rect.height * 0.4)))
	draw_text_centered(label, rect, font_size, text_color)
}

grid_to_screen :: proc(board: ^Board, layout: ^Layout, p: Grid_Pos, offset: f32 = 0, dir: Direction = .Right) -> rl.Vector2 {
	step := direction_step(dir)
	return grid_coordinates_to_screen(board, layout, f32(p.x) + f32(step.x) * offset, f32(p.y) + f32(step.y) * offset)
}

grid_coordinates_to_screen :: proc(board: ^Board, layout: ^Layout, x, y: f32) -> rl.Vector2 {
	pad := layout.board.width * 0.065
	spacing := (layout.board.width - pad * 2) / f32(board.side - 1)
	return {
		layout.board.x + pad + x * spacing,
		layout.board.y + pad + y * spacing,
	}
}

draw_arrow :: proc(game: ^Game, arrow: ^Arrow, layout: ^Layout) {
	points: [MAX_ARROW_LENGTH]rl.Vector2
	head_dir := arrow_direction(&game.board, arrow)
	for segment in 0..<arrow.length {
		travel: f32
		if game.animation.kind != .None && game.animation.arrow_id == arrow.id {
			travel = animation_segment_offset(&game.animation, segment, arrow.length)
		}
		x, y := arrow_path_position(&game.board, arrow, f32(segment) + travel)
		points[segment] = grid_coordinates_to_screen(&game.board, layout, x, y)
	}
	spacing := (layout.board.width * 0.87) / f32(game.board.side - 1)
	thickness := max(4.0, spacing * 0.16)
	tail_dx, tail_dy := points[1].x - points[0].x, points[1].y - points[0].y
	tail_length := f32(math.sqrt(f64(tail_dx * tail_dx + tail_dy * tail_dy)))
	if tail_length > 0.001 {
		points[0].x -= tail_dx / tail_length * spacing * 0.28
		points[0].y -= tail_dy / tail_length * spacing * 0.28
	}
	for i in 0..<arrow.length - 1 {
		rl.DrawLineEx(points[i], points[i + 1], thickness, INK)
	}
	for i in 0..<arrow.length - 1 do rl.DrawCircleV(points[i], thickness * 0.5, INK)
	head := points[arrow.length - 1]
	head_step := direction_step(head_dir)
	forward := rl.Vector2{f32(head_step.x), f32(head_step.y)}
	side := rl.Vector2{-forward.y, forward.x}
	tip := rl.Vector2{head.x + forward.x * thickness * 2.15, head.y + forward.y * thickness * 2.15}
	left := rl.Vector2{head.x - forward.x * thickness * 0.35 + side.x * thickness, head.y - forward.y * thickness * 0.35 + side.y * thickness}
	right := rl.Vector2{head.x - forward.x * thickness * 0.35 - side.x * thickness, head.y - forward.y * thickness * 0.35 - side.y * thickness}
	rl.DrawTriangle(tip, right, left, INK)
}

draw_board :: proc(game: ^Game, layout: ^Layout) {
	rl.DrawRectangleRounded(layout.board, 0.04, 12, PANEL)
	dot_radius := max(2.0, layout.board.width / f32(game.board.side) * 0.045)
	for y in 0..<game.board.side {
		for x in 0..<game.board.side {
			p := grid_to_screen(&game.board, layout, {x, y})
			rl.DrawCircleV(p, dot_radius, SAGE_DARK)
		}
	}
	for i in 0..<game.board.arrow_count {
		if !game.board.arrows[i].removed do draw_arrow(game, &game.board.arrows[i], layout)
	}
}

draw_settings :: proc(game: ^Game, layout: ^Layout) {
	p := layout.panel
	title_size := int(max(27.0, min(42.0, p.width * 0.12)))
	if layout.compact {
		measured := max(1, rl.MeasureText("CNARROW", 10))
		title_size = int(max(42.0, min(72.0, p.width * 0.44 * 10 / f32(measured))))
	}
	rl.DrawText("CNARROW", i32(p.x), i32(p.y + 4), i32(title_size), INK)
	label_size := int(max(15.0, min(19.0, p.width * 0.055)))
	if layout.compact {
		label_size = int(max(20.0, min(30.0, f32(title_size) * 0.42)))
		stats := fmt.ctprintf("%d left  |  %d blocked", game.board.arrow_count - game.removed_count, game.blocked_taps)
		rl.DrawText(stats, i32(p.x), i32(p.y + f32(title_size) + 14), i32(label_size), SAGE_DARK)
		draw_button(layout.new_button, "New Puzzle")
		return
	}
	rl.DrawText("NEXT GRID", i32(p.x), i32(layout.size_buttons[0].y - 25), i32(label_size), SAGE_DARK)
	rl.DrawText("DIFFICULTY", i32(p.x), i32(layout.diff_buttons[0].y - 25), i32(label_size), SAGE_DARK)
	size_labels := [3]cstring{"24 x 24", "32 x 32", "40 x 40"}
	diff_labels := [3]cstring{"Easy", "Medium", "Hard"}
	for i in 0..<3 {
		draw_button(layout.size_buttons[i], size_labels[i], int(game.selected_size) == i)
		draw_button(layout.diff_buttons[i], diff_labels[i], int(game.selected_difficulty) == i)
	}
	draw_button(layout.new_button, "New Puzzle")
	stats := fmt.ctprintf("%d left   |   %d blocked", game.board.arrow_count - game.removed_count, game.blocked_taps)
	rl.DrawText(stats, i32(p.x), i32(layout.new_button.y - 28), i32(label_size), SAGE_DARK)
}

draw_confirmation :: proc(game: ^Game, layout: ^Layout) {
	rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), {29, 35, 31, 80})
	panel := confirmation_panel(layout)
	rl.DrawRectangleRounded(panel, 0.12, 10, SOFT_WHITE)
	title_size, body_size := 25, 16
	if layout.compact { title_size, body_size = 46, 28 }
	draw_text_centered("Start a new puzzle?", {panel.x, panel.y + 24, panel.width, f32(title_size + 10)}, title_size, INK)
	draw_text_centered("Your current progress will be cleared.", {panel.x, panel.y + 44 + f32(title_size), panel.width, f32(body_size + 10)}, body_size, SAGE_DARK)
	cancel, confirm := confirmation_buttons(layout, panel)
	draw_button(cancel, "Keep Playing")
	draw_button(confirm, "New Puzzle", true)
}

draw_completion :: proc(game: ^Game, layout: ^Layout) {
	// Sparse drifting dots keep the celebration quiet and asset-free.
	for i in 0..<18 {
		phase := game.celebration_time * (0.22 + f32(i % 4) * 0.03) + f32(i) * 0.371
		x := layout.board.x + f32((i * 47) % 101) / 100.0 * layout.board.width
		y := layout.board.y + f32(math.mod(f64(phase), 1.0)) * layout.board.height
		rl.DrawCircleV({x, y}, 2.5 + f32(i % 3), {111, 139, 111, 120})
	}
	panel := confirmation_panel(layout)
	rl.DrawRectangleRounded(panel, 0.12, 10, SOFT_WHITE)
	title_size, stats_size := 29, 17
	if layout.compact { title_size, stats_size = 48, 28 }
	draw_text_centered("Puzzle cleared", {panel.x, panel.y + 20, panel.width, f32(title_size + 8)}, title_size, INK)
	minutes := int(game.elapsed) / 60
	seconds := int(game.elapsed) % 60
	stats := fmt.ctprintf("%02d:%02d   |   %d blocked taps", minutes, seconds, game.blocked_taps)
	draw_text_centered(stats, {panel.x, panel.y + 38 + f32(title_size), panel.width, f32(stats_size + 8)}, stats_size, SAGE_DARK)
	draw_button(completion_button(layout), "Next Puzzle", true)
}

game_draw :: proc(game: ^Game, dt: f32) {
	layout := game_layout(game, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
	if layout.compact {
		play_top := i32(layout.panel.y + layout.panel.height)
		play_bottom := i32(layout.new_button.y)
		rl.BeginScissorMode(0, play_top, rl.GetScreenWidth(), play_bottom - play_top)
	}
	draw_board(game, &layout)
	if layout.compact do rl.EndScissorMode()
	draw_settings(game, &layout)
	if game.phase == .Confirm_New do draw_confirmation(game, &layout)
	if game.phase == .Complete do draw_completion(game, &layout)
}
