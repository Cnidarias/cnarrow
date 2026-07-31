package g

import rl "vendor:raylib"

start_puzzle :: proc(game: ^Game) {
	game.seed_counter += 1
	game.applied_size = game.selected_size
	game.applied_difficulty = game.selected_difficulty
	seed := game.seed_counter * 0x9e3779b97f4a7c15 + u64(game.selected_size) * 97 + u64(game.selected_difficulty) * 7919
	game.board = generate_board(grid_side(game.selected_size), game.selected_difficulty, seed)
	game.animation = {}
	game.phase = .Playing
	game.elapsed = 0
	game.blocked_taps = 0
	game.removed_count = 0
	game.celebration_time = 0
}

game_init :: proc(game: ^Game) {
	game^ = {
		selected_size = .Medium,
		selected_difficulty = .Medium,
		seed_counter = 0x434e4152524f57,
	}
	start_puzzle(game)
}

game_destroy :: proc(game: ^Game) {}

request_new_puzzle :: proc(game: ^Game) {
	if game.phase == .Playing && game.removed_count > 0 {
		game.phase = .Confirm_New
	} else {
		start_puzzle(game)
	}
}

game_update :: proc(game: ^Game, dt: f32) {
	if game.phase == .Playing {
		game.elapsed += dt
		update_animation(game, dt)
	} else if game.phase == .Complete {
		game.celebration_time += dt
	}
	handle_input(game)
}

pointer_pressed :: proc() -> (rl.Vector2, bool) {
	if rl.IsMouseButtonPressed(.LEFT) do return rl.GetMousePosition(), true
	if rl.GetTouchPointCount() > 0 do return rl.GetTouchPosition(0), true
	return {}, false
}
