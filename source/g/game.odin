package g

import rl "vendor:raylib"

start_puzzle :: proc(game: ^Game) {
	continue_auto := game.auto_solving
	seed_rng := Rng{state = game.seed_counter}
	game.seed_counter = rng_next(&seed_rng)
	game.applied_size = game.selected_size
	game.applied_difficulty = game.selected_difficulty
	seed := game.seed_counter + u64(game.selected_size) * 97 + u64(game.selected_difficulty) * 7919
	game.board = generate_board(grid_side(game.selected_size), game.selected_difficulty, seed)
	game.animations = {}
	game.phase = .Playing
	game.elapsed = 0
	game.blocked_taps = 0
	game.removed_count = 0
	game.celebration_time = 0
	game.auto_solving = continue_auto
	game.auto_solution_step = 0
	game.settings_open = false
}

game_init :: proc(game: ^Game, seed: u64) {
	game^ = {
		selected_size = .Size_40,
		selected_difficulty = .Medium,
		seed_counter = seed,
		board_zoom = 1,
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

toggle_auto_solve :: proc(game: ^Game) {
	if game.phase != .Playing do return
	game.auto_solving = !game.auto_solving
	if game.auto_solving do game.auto_solution_step = 0
}

update_auto_solve :: proc(game: ^Game) {
	if !game.auto_solving || game.phase != .Playing || has_active_animations(game) do return
	for game.auto_solution_step < game.board.arrow_count {
		id := game.board.solution[game.auto_solution_step]
		game.auto_solution_step += 1
		if game.board.arrows[id].removed do continue
		if !start_arrow_animation(game, id) do game.auto_solving = false
		return
	}
}

game_update :: proc(game: ^Game, dt: f32) {
	if game.phase == .Playing {
		game.elapsed += dt
		animation_dt := dt
		if game.auto_solving do animation_dt *= 2
		update_animations(game, animation_dt)
		update_auto_solve(game)
	} else if game.phase == .Complete {
		game.celebration_time += dt
		if game.auto_solving && game.celebration_time >= 5 do start_puzzle(game)
	}
	handle_input(game)
}

pointer_pressed :: proc(game: ^Game) -> (rl.Vector2, bool) {
	if rl.IsMouseButtonPressed(.LEFT) do return rl.GetMousePosition(), true
	touching := rl.GetTouchPointCount() > 0
	pressed := touching && !game.touch_down
	game.touch_down = touching
	if pressed do return rl.GetTouchPosition(0), true
	return {}, false
}

set_board_view :: proc(game: ^Game, zoom, pan_x, pan_y: f32) {
	game.board_zoom = max(1.0, min(3.0, zoom))
	game.board_pan = {pan_x, pan_y}
}
