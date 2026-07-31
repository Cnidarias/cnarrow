package g

clear_occupancy :: proc(board: ^Board) {
	for i in 0..<MAX_CELLS { board.occupancy[i] = 0 }
}

rebuild_occupancy :: proc(board: ^Board) -> bool {
	clear_occupancy(board)
	for i in 0..<board.arrow_count {
		a := &board.arrows[i]
		if a.removed do continue
		if a.length < 2 do return false
		if a.path_count > 0 && a.path_count != a.length do return false
		for segment in 0..<a.length {
			p := arrow_cell(a, segment)
			if !in_bounds(board, p) do return false
			if segment > 0 {
				previous := arrow_cell(a, segment - 1)
				if abs(p.x - previous.x) + abs(p.y - previous.y) != 1 do return false
			}
			index := cell_index(board, p)
			if board.occupancy[index] != 0 do return false
			board.occupancy[index] = a.id + 1
		}
	}
	return true
}

nearest_blocker :: proc(board: ^Board, arrow_id: int) -> (blocker_id: int, distance: int, blocked: bool) {
	if arrow_id < 0 || arrow_id >= board.arrow_count do return -1, 0, false
	a := &board.arrows[arrow_id]
	if a.removed do return -1, 0, false
	step := direction_step(arrow_direction(a))
	p := pos_add(arrow_head(a), step)
	distance = 1
	for in_bounds(board, p) {
		owner := board.occupancy[cell_index(board, p)]
		if owner != 0 && owner - 1 != arrow_id {
			return owner - 1, distance, true
		}
		p = pos_add(p, step)
		distance += 1
	}
	return -1, distance, false
}

can_escape :: proc(board: ^Board, arrow_id: int) -> bool {
	_, _, blocked := nearest_blocker(board, arrow_id)
	return !blocked
}

remove_arrow :: proc(board: ^Board, arrow_id: int) -> bool {
	if arrow_id < 0 || arrow_id >= board.arrow_count do return false
	a := &board.arrows[arrow_id]
	if a.removed || !can_escape(board, arrow_id) do return false
	a.removed = true
	for segment in 0..<a.length {
		p := arrow_cell(a, segment)
		board.occupancy[cell_index(board, p)] = 0
	}
	return true
}

legal_move_count :: proc(board: ^Board) -> int {
	count := 0
	for i in 0..<board.arrow_count {
		if !board.arrows[i].removed && can_escape(board, i) do count += 1
	}
	return count
}

board_solvable :: proc(source: ^Board) -> bool {
	board := source^
	removed := 0
	for removed < board.arrow_count {
		progress := false
		for i in 0..<board.arrow_count {
			if !board.arrows[i].removed && can_escape(&board, i) {
				remove_arrow(&board, i)
				removed += 1
				progress = true
			}
		}
		if !progress do return false
	}
	return true
}

solution_clears :: proc(source: ^Board) -> bool {
	board := source^
	for n in 0..<board.arrow_count {
		if !remove_arrow(&board, board.solution[n]) do return false
	}
	return true
}
