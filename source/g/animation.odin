package g

import "core:math"

start_arrow_animation :: proc(game: ^Game, arrow_id: int) -> bool {
	if game.animation.kind != .None || game.phase != .Playing do return false
	blocker, distance, blocked := nearest_blocker(&game.board, arrow_id)
	if blocked {
		game.blocked_taps += 1
		game.animation = {
			kind = .Blocked, arrow_id = arrow_id, blocker_id = blocker,
			duration = 0.46, stretch = min(f32(distance) - 0.28, 0.72),
		}
	} else {
		game.animation = {
			kind = .Escaping, arrow_id = arrow_id, blocker_id = -1,
			duration = 0.72, stretch = f32(game.board.side + game.board.arrows[arrow_id].length + 2),
		}
	}
	return true
}

update_animation :: proc(game: ^Game, dt: f32) {
	a := &game.animation
	if a.kind == .None do return
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
		if a.kind == .Escaping {
			if remove_arrow(&game.board, a.arrow_id) {
				game.removed_count += 1
				if game.removed_count == game.board.arrow_count {
					game.phase = .Complete
					game.celebration_time = 0
				}
			}
		}
		game.animation = {}
	}
}

animation_segment_offset :: proc(animation: ^Arrow_Animation, segment, length: int) -> f32 {
	if animation.kind == .None do return 0
	if animation.kind == .Blocked do return animation.offset
	// Heads lead and tails follow, creating the slithering stretch.
	progress := min(animation.time / animation.duration, 1.0)
	lag := f32(length - 1 - segment) * 0.055
	local := max(0.0, min(1.0, (progress - lag) / max(0.15, 1.0 - lag)))
	return animation.stretch * local * local * (3 - 2 * local)
}
