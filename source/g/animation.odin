package g

import "core:math"

start_arrow_animation :: proc(game: ^Game, arrow_id: int) -> bool {
	if game.phase != .Playing || arrow_id < 0 || arrow_id >= game.board.arrow_count do return false
	if game.board.arrows[arrow_id].removed do return false
	existing := active_animation_for_arrow(game, arrow_id)
	if existing != nil {
		if existing.kind != .Blocked || !can_escape(&game.board, arrow_id) do return false
		existing^ = {}
	}
	animation: ^Arrow_Animation
	for i in 0..<len(game.animations) {
		if game.animations[i].kind == .None {
			animation = &game.animations[i]
			break
		}
	}
	if animation == nil do return false
	blocker, distance, blocked := nearest_blocker(&game.board, arrow_id)
	if blocked {
		game.blocked_taps += 1
		animation^ = {
			kind = .Blocked, arrow_id = arrow_id, blocker_id = blocker,
			duration = 0.46, stretch = min(f32(distance) - 0.28, 0.72),
		}
	} else {
		a := &game.board.arrows[arrow_id]
		head := arrow_head(&game.board, a)
		exit_distance := 1
		switch arrow_direction(&game.board, a) {
		case .Up:    exit_distance = head.y + 1
		case .Right: exit_distance = game.board.side - head.x
		case .Down:  exit_distance = game.board.side - head.y
		case .Left:  exit_distance = head.x + 1
		}
		travel := f32(a.length - 1 + exit_distance + 2)
		animation^ = {
			kind = .Escaping, arrow_id = arrow_id, blocker_id = -1,
			duration = min(2.2, max(0.78, 0.52 + travel * 0.018)),
			stretch = travel,
		}
		if !remove_arrow(&game.board, arrow_id) {
			animation^ = {}
			return false
		}
		game.removed_count += 1
	}
	return true
}

active_animation_for_arrow :: proc(game: ^Game, arrow_id: int) -> ^Arrow_Animation {
	for i in 0..<len(game.animations) {
		a := &game.animations[i]
		if a.kind != .None && a.arrow_id == arrow_id do return a
	}
	return nil
}

has_active_animations :: proc(game: ^Game) -> bool {
	for animation in game.animations do if animation.kind != .None do return true
	return false
}

update_animations :: proc(game: ^Game, dt: f32) {
	active := false
	for i in 0..<len(game.animations) {
		a := &game.animations[i]
		if a.kind == .None do continue
		a.time += dt
		t := min(a.time / a.duration, 1.0)
		switch a.kind {
		case .Blocked:
			// sin² gives a gentle contact and guarantees an exact zero endpoint.
			s := f32(math.sin(f64(t) * math.PI))
			a.offset = a.stretch * s * s
		case .Escaping:
			// Smooth acceleration; individual segment lag is applied while drawing.
			a.offset = a.stretch * t * t * (3 - 2 * t)
		case .None:
		}
		if t >= 1 {
			a^ = {}
		} else {
			active = true
		}
	}
	if game.removed_count == game.board.arrow_count && !active {
		game.phase = .Complete
		game.celebration_time = 0
	}
}

animation_segment_offset :: proc(animation: ^Arrow_Animation, segment, length: int) -> f32 {
	if animation.kind == .None do return 0
	// Every point advances the same path distance. Since points begin at
	// different positions, the body naturally follows every corner in order.
	return animation.offset
}

arrow_path_position :: proc(board: ^Board, arrow: ^Arrow, distance: f32) -> (x, y: f32) {
	if distance <= 0 {
		p := arrow_cell(board, arrow, 0)
		return f32(p.x), f32(p.y)
	}
	last := arrow.length - 1
	if distance < f32(last) {
		index := int(distance)
		fraction := distance - f32(index)
		from := arrow_cell(board, arrow, index)
		to := arrow_cell(board, arrow, index + 1)
		return f32(from.x) + f32(to.x - from.x) * fraction,
		       f32(from.y) + f32(to.y - from.y) * fraction
	}
	head := arrow_head(board, arrow)
	step := direction_step(arrow_direction(board, arrow))
	beyond := distance - f32(last)
	return f32(head.x) + f32(step.x) * beyond,
	       f32(head.y) + f32(step.y) * beyond
}
