package tests

import "core:testing"
import g "src:g"
import rl "vendor:raylib"

@(test)
test_cells_heads_and_blockers :: proc(t: ^testing.T) {
	board := g.Board{side = 6, arrow_count = 3}
	board.arrows[0] = {id = 0, tail = {0, 2}, length = 3, dir = .Right}
	board.arrows[1] = {id = 1, tail = {4, 0}, length = 3, dir = .Down}
	board.arrows[2] = {id = 2, tail = {1, 5}, length = 2, dir = .Left}
	testing.expect(t, g.rebuild_occupancy(&board))
	testing.expect_value(t, g.arrow_head(&board, &board.arrows[0]), g.Grid_Pos{2, 2})
	testing.expect(t, g.in_bounds(&board, {5, 5}))
	testing.expect(t, !g.in_bounds(&board, {6, 5}))
	blocker, distance, blocked := g.nearest_blocker(&board, 0)
	testing.expect(t, blocked)
	testing.expect_value(t, blocker, 1)
	testing.expect_value(t, distance, 2)
	testing.expect(t, g.can_escape(&board, 1))
	testing.expect(t, g.can_escape(&board, 2))
	testing.expect(t, !g.remove_arrow(&board, 0))
	testing.expect(t, g.remove_arrow(&board, 1))
	testing.expect(t, g.remove_arrow(&board, 0))
}

@(test)
test_overlap_and_invalid_bounds_rejected :: proc(t: ^testing.T) {
	board := g.Board{side = 6, arrow_count = 2}
	board.arrows[0] = {id = 0, tail = {0, 0}, length = 3, dir = .Right}
	board.arrows[1] = {id = 1, tail = {2, 0}, length = 2, dir = .Down}
	testing.expect(t, !g.rebuild_occupancy(&board))
	board.arrow_count = 1
	board.arrows[0] = {id = 0, tail = {5, 5}, length = 2, dir = .Right}
	testing.expect(t, !g.rebuild_occupancy(&board))
}

@(test)
test_arrow_hit_area_covers_full_stroke :: proc(t: ^testing.T) {
	game := g.Game{}
	game.board = g.Board{side = 6, arrow_count = 2}
	game.board.arrows[0] = {id = 0, tail = {0, 1}, length = 5, dir = .Right}
	game.board.arrows[1] = {id = 1, tail = {0, 3}, length = 5, dir = .Right}
	testing.expect(t, g.rebuild_occupancy(&game.board))
	layout := g.make_layout(900, 700)
	start := g.grid_to_screen(&game.board, &layout, {1, 1})
	end := g.grid_to_screen(&game.board, &layout, {2, 1})
	midpoint := rl.Vector2{(start.x + end.x) / 2, (start.y + end.y) / 2 + 5}
	testing.expect_value(t, g.arrow_at_point(&game, midpoint, &layout), 0)
	second := g.grid_to_screen(&game.board, &layout, {2, 3})
	testing.expect_value(t, g.arrow_at_point(&game, second, &layout), 1)
}

@(test)
test_portrait_arrow_hit_area_accepts_coarse_taps :: proc(t: ^testing.T) {
	game := g.Game{}
	game.board = g.Board{side = 6, arrow_count = 1}
	game.board.arrows[0] = {id = 0, tail = {0, 2}, length = 5, dir = .Right}
	testing.expect(t, g.rebuild_occupancy(&game.board))
	layout := g.make_layout(975, 2110)
	stroke := g.grid_to_screen(&game.board, &layout, {2, 2})
	coarse_tap := rl.Vector2{stroke.x, stroke.y + 20}
	testing.expect_value(t, g.arrow_at_point(&game, coarse_tap, &layout), 0)
	head := g.grid_to_screen(&game.board, &layout, {4, 2})
	head_tap := rl.Vector2{head.x, head.y + 45}
	testing.expect_value(t, g.arrow_at_point(&game, head_tap, &layout), 0)
}

@(test)
test_zoomed_board_pans_through_the_full_play_area :: proc(t: ^testing.T) {
	game := g.Game{board_zoom = 2, board_pan = {10000, 10000}}
	layout := g.game_layout(&game, 975, 2110)
	testing.expect(t, layout.board.x <= 0)
	testing.expect(t, layout.board.y <= layout.panel.y + layout.panel.height)
	game.board_pan = {-10000, -10000}
	layout = g.game_layout(&game, 975, 2110)
	testing.expect(t, layout.board.x + layout.board.width >= 975)
	testing.expect(t, layout.board.y + layout.board.height >= layout.new_button.y)
}

@(test)
test_portrait_layout_hides_settings_and_keeps_touch_targets :: proc(t: ^testing.T) {
	layout := g.make_layout(975, 2110)
	testing.expect(t, layout.compact)
	testing.expect_value(t, layout.size_buttons, [3]rl.Rectangle{})
	testing.expect_value(t, layout.diff_buttons, [3]rl.Rectangle{})
	testing.expectf(t, layout.new_button.height >= 96, "compact New Puzzle target is only %.1f pixels high", layout.new_button.height)
	panel := g.confirmation_panel(&layout)
	cancel, confirm := g.confirmation_buttons(&layout, panel)
	testing.expect(t, cancel.height >= 96 && confirm.height >= 96)
}

@(test)
test_new_puzzle_advances_to_a_different_board :: proc(t: ^testing.T) {
	game: g.Game
	g.game_init(&game, 0x434e4152524f57)
	first := game.board
	g.start_puzzle(&game)
	testing.expect(t, first.seed != game.board.seed)
	testing.expect(t, first.path_cells != game.board.path_cells)
}

@(test)
test_generation_is_bounded_valid_and_replayable :: proc(t: ^testing.T) {
	for size in g.Grid_Size {
		for difficulty in g.Difficulty {
			for seed in 1..=12 {
				board := g.generate_board(g.grid_side(size), difficulty, u64(seed) * 1234567)
				testing.expectf(t, board.arrow_count > 0, "empty board for %v %v seed %d", size, difficulty, seed)
				testing.expectf(t, g.rebuild_occupancy(&board), "invalid occupancy for %v %v seed %d", size, difficulty, seed)
				occupied := 0
				total_turns := 0
				longest := 0
				short_count := 0
				long_count := 0
				short_limit := 10
				if difficulty == .Medium do short_limit = 8
				if difficulty == .Hard do short_limit = 6
				for i in 0..<board.arrow_count {
					a := &board.arrows[i]
					occupied += a.length
					longest = max(longest, a.length)
					if a.length <= short_limit do short_count += 1
					if a.length >= board.side do long_count += 1
					testing.expect(t, a.length >= 2 && a.length <= g.MAX_ARROW_LENGTH)
					for segment in 0..<a.length {
						testing.expect(t, g.in_bounds(&board, g.arrow_cell(&board, a, segment)))
						if segment >= 2 {
							p0 := g.arrow_cell(&board, a, segment - 2)
							p1 := g.arrow_cell(&board, a, segment - 1)
							p2 := g.arrow_cell(&board, a, segment)
							if p1.x - p0.x != p2.x - p1.x || p1.y - p0.y != p2.y - p1.y do total_turns += 1
						}
					}
				}
				ratio := f32(occupied) / f32(board.side * board.side)
				testing.expectf(t, ratio == 1, "board is not completely filled for %v %v seed %d", size, difficulty, seed)
				testing.expectf(t, longest >= board.side, "board has no region-spanning arrow for %v %v seed %d", size, difficulty, seed)
				testing.expectf(t, short_count * 2 >= board.arrow_count, "small arrows are not the majority for %v %v seed %d", size, difficulty, seed)
				testing.expectf(t, long_count >= 2, "board needs multiple long gate arrows for %v %v seed %d", size, difficulty, seed)
				testing.expectf(t, total_turns >= board.side, "board is not maze-like enough for %v %v seed %d", size, difficulty, seed)
				initial_moves := g.legal_move_count(&board)
				if difficulty == .Medium do testing.expectf(t, initial_moves <= 4, "medium board exposes %d initial moves", initial_moves)
				if difficulty == .Hard do testing.expectf(t, initial_moves <= 2, "hard board exposes %d initial moves", initial_moves)
				replay := board
				max_long_unlock := 0
				for step in 0..<replay.arrow_count {
					before: [g.MAX_ARROWS]bool
					for i in 0..<replay.arrow_count do before[i] = !replay.arrows[i].removed && g.can_escape(&replay, i)
					id := replay.solution[step]
					was_long := replay.arrows[id].length >= replay.side
					testing.expect(t, g.remove_arrow(&replay, id))
					if was_long {
						unlocked := 0
						for i in 0..<replay.arrow_count {
							if !replay.arrows[i].removed && !before[i] && g.can_escape(&replay, i) do unlocked += 1
						}
						max_long_unlock = max(max_long_unlock, unlocked)
					}
				}
				testing.expectf(t, max_long_unlock > 0, "long arrows never unlock another arrow for %v %v seed %d", size, difficulty, seed)
				testing.expectf(t, g.board_solvable(&board), "unsolvable board for %v %v seed %d", size, difficulty, seed)
				testing.expectf(t, g.solution_clears(&board), "recorded solution failed for %v %v seed %d", size, difficulty, seed)
			}
		}
	}
}

@(test)
test_animation_endpoints_and_game_states :: proc(t: ^testing.T) {
	game := g.Game{phase = .Playing}
	game.board = g.Board{side = 6, arrow_count = 2}
	game.board.arrows[0] = {id = 0, tail = {0, 2}, length = 2, dir = .Right}
	game.board.arrows[1] = {id = 1, tail = {3, 0}, length = 3, dir = .Down}
	testing.expect(t, g.rebuild_occupancy(&game.board))
	testing.expect(t, g.start_arrow_animation(&game, 0))
	testing.expect_value(t, game.animations[0].kind, g.Animation_Kind.Blocked)
	g.update_animations(&game, 1)
	testing.expect_value(t, game.animations[0].kind, g.Animation_Kind.None)
	testing.expect_value(t, game.blocked_taps, 1)
	testing.expect_value(t, game.removed_count, 0)
	testing.expect(t, g.start_arrow_animation(&game, 0))
	testing.expect(t, g.start_arrow_animation(&game, 1))
	testing.expect(t, game.board.arrows[1].removed)
	testing.expect_value(t, game.removed_count, 1)
	testing.expect(t, g.start_arrow_animation(&game, 0))
	testing.expect(t, game.board.arrows[0].removed)
	testing.expect_value(t, game.removed_count, 2)
	g.update_animations(&game, 2)
	testing.expect_value(t, game.phase, g.Game_Phase.Complete)
	g.request_new_puzzle(&game)
	testing.expect_value(t, game.phase, g.Game_Phase.Playing)
}

@(test)
test_animation_follows_arrow_path :: proc(t: ^testing.T) {
	board := g.Board{side = 6, arrow_count = 1, path_cell_count = 4}
	board.path_cells[0] = {0, 2}
	board.path_cells[1] = {1, 2}
	board.path_cells[2] = {1, 1}
	board.path_cells[3] = {2, 1}
	board.arrows[0] = {id = 0, length = 4, path_start = 0, path_count = 4}
	testing.expect(t, g.rebuild_occupancy(&board))
	x, y := g.arrow_path_position(&board, &board.arrows[0], 1.5)
	testing.expectf(t, x == 1 && y == 1.5, "expected path interpolation at (1, 1.5), got (%.2f, %.2f)", x, y)
	x, y = g.arrow_path_position(&board, &board.arrows[0], 4)
	testing.expectf(t, x == 3 && y == 1, "expected head extension at (3, 1), got (%.2f, %.2f)", x, y)
}

@(test)
test_completion_and_next_puzzle_flow :: proc(t: ^testing.T) {
	game := g.Game{phase = .Playing, selected_size = .Small, selected_difficulty = .Easy}
	game.board = g.Board{side = 6, arrow_count = 1}
	game.board.arrows[0] = {id = 0, tail = {1, 1}, length = 2, dir = .Right}
	testing.expect(t, g.rebuild_occupancy(&game.board))
	g.start_arrow_animation(&game, 0)
	g.update_animations(&game, 2)
	testing.expect_value(t, game.phase, g.Game_Phase.Complete)
	g.start_puzzle(&game)
	testing.expect_value(t, game.phase, g.Game_Phase.Playing)
	testing.expect_value(t, game.removed_count, 0)
	testing.expect(t, game.board.arrow_count > 0)
}
