package g

Rng :: struct { state: u64 }

rng_next :: proc(rng: ^Rng) -> u64 {
	x := rng.state
	if x == 0 do x = 0x9e3779b97f4a7c15
	x = x ~ (x << 13)
	x = x ~ (x >> 7)
	x = x ~ (x << 17)
	rng.state = x
	return x
}

rng_range :: proc(rng: ^Rng, low, high: int) -> int {
	if high <= low do return low
	return low + int(rng_next(rng) % u64(high - low))
}

difficulty_parameters :: proc(difficulty: Difficulty) -> (low, high: f32, min_length, max_length, wanted_moves: int) {
	switch difficulty {
	case .Easy:   return 0.35, 0.45, 2, 3, 3
	case .Medium: return 0.45, 0.58, 2, 4, 2
	case .Hard:   return 0.58, 0.70, 2, 5, 1
	}
	return 0.45, 0.58, 2, 4, 2
}

placement_fits :: proc(board: ^Board, tail: Grid_Pos, length: int, dir: Direction) -> bool {
	step := direction_step(dir)
	for segment in 0..<length {
		p := pos_add(tail, step, segment)
		if !in_bounds(board, p) || board.occupancy[cell_index(board, p)] != 0 do return false
	}
	return true
}

insert_arrow :: proc(board: ^Board, tail: Grid_Pos, length: int, dir: Direction) -> bool {
	if board.arrow_count >= MAX_ARROWS || !placement_fits(board, tail, length, dir) do return false
	id := board.arrow_count
	board.arrows[id] = {id = id, tail = tail, length = length, dir = dir}
	for segment in 0..<length {
		p := arrow_cell(board, &board.arrows[id], segment)
		board.occupancy[cell_index(board, p)] = id + 1
	}
	board.arrow_count += 1
	// Reverse construction invariant: this new arrow must be removable before
	// future arrows are added. Reversing insertion order is therefore a proof.
	if !can_escape(board, id) {
		for segment in 0..<length {
			p := arrow_cell(board, &board.arrows[id], segment)
			board.occupancy[cell_index(board, p)] = 0
		}
		board.arrow_count -= 1
		return false
	}
	return true
}

build_candidate :: proc(side: int, difficulty: Difficulty, seed: u64) -> Board {
	board := Board{side = side, seed = seed}
	rng := Rng{state = seed}
	low, high, min_length, max_length, wanted := difficulty_parameters(difficulty)
	target_ratio := low + f32(rng_next(&rng) % 1001) / 1000.0 * (high - low)
	capacity := side * side
	min_cells := int(low * f32(capacity) + 0.999)
	max_cells := int(high * f32(capacity))
	target_cells := max(min_cells, min(max_cells, int(target_ratio * f32(capacity) + 0.5)))
	occupied := 0
	rounds := 0
	for occupied < target_cells && rounds < capacity {
		rounds += 1
		best_trial := Board{}
		best_length := 0
		best_placement_score := -1000000
		// First try placements that cross the open ray of a currently legal
		// arrow. The inserted arrow remains legal by construction, so this can
		// replace one available move with another and form long dependency chains.
		for victim in 0..<board.arrow_count {
			if !can_escape(&board, victim) do continue
			victim_step := direction_step(board.arrows[victim].dir)
			block_cell := pos_add(arrow_head(&board, &board.arrows[victim]), victim_step)
			for in_bounds(&board, block_cell) {
				for raw_dir in 0..<4 {
					dir := Direction(raw_dir)
					step := direction_step(dir)
					for length in min_length..=max_length {
						if occupied + length > max_cells do continue
						for segment in 0..<length {
							tail := Grid_Pos{block_cell.x - step.x * segment, block_cell.y - step.y * segment}
							trial := board
							if !insert_arrow(&trial, tail, length, dir) do continue
							moves := legal_move_count(&trial)
							placement_score := -abs(moves - wanted) * 100 + int(rng_next(&rng) % 19)
							if difficulty == .Easy && moves >= 3 do placement_score += 180
							if difficulty == .Medium && moves >= 2 && moves <= 3 do placement_score += 240
							if difficulty == .Hard && moves <= 2 do placement_score += 320
							if placement_score > best_placement_score {
								best_trial = trial
								best_length = length
								best_placement_score = placement_score
							}
						}
					}
				}
				block_cell = pos_add(block_cell, victim_step)
			}
		}
		// Choose among many valid reverse insertions. Preferring a small legal
		// frontier creates meaningful dependencies instead of relying on luck.
		for sample in 0..<160 {
			length := rng_range(&rng, min_length, max_length + 1)
			if occupied + length > max_cells do continue
			dir := Direction(rng_range(&rng, 0, 4))
			tail := Grid_Pos{rng_range(&rng, 0, side), rng_range(&rng, 0, side)}
			trial := board
			if !insert_arrow(&trial, tail, length, dir) do continue
			moves := legal_move_count(&trial)
			placement_score := -abs(moves - wanted) * 100 + int(rng_next(&rng) % 19)
			if difficulty == .Easy && moves >= 3 do placement_score += 180
			if difficulty == .Medium && moves >= 2 && moves <= 3 do placement_score += 240
			if difficulty == .Hard && moves <= 2 do placement_score += 320
			if placement_score > best_placement_score {
				best_trial = trial
				best_length = length
				best_placement_score = placement_score
			}
		}
		if best_length == 0 do break
		board = best_trial
		occupied += best_length
	}
	for i in 0..<board.arrow_count {
		board.solution[i] = board.arrow_count - 1 - i
	}
	return board
}

dependency_depth :: proc(board: ^Board) -> int {
	best := 0
	for start in 0..<board.arrow_count {
		depth := 1
		current := start
		seen: [MAX_ARROWS]bool
		seen[current] = true
		for {
			blocker, _, blocked := nearest_blocker(board, current)
			if !blocked || blocker < 0 || seen[blocker] do break
			seen[blocker] = true
			depth += 1
			current = blocker
		}
		best = max(best, depth)
	}
	return best
}

candidate_score :: proc(board: ^Board, difficulty: Difficulty) -> int {
	if board.arrow_count == 0 || !rebuild_occupancy(board) || !solution_clears(board) || !board_solvable(board) do return -1000000
	occupied := 0
	for i in 0..<board.arrow_count do occupied += board.arrows[i].length
	low, high, _, _, wanted := difficulty_parameters(difficulty)
	ratio := f32(occupied) / f32(board.side * board.side)
	score := occupied * 4
	if ratio >= low && ratio <= high do score += 500
	moves := legal_move_count(board)
	score -= abs(moves - wanted) * 35
	if difficulty == .Easy && moves >= 3 do score += 180
	if difficulty == .Medium && moves >= 2 && moves <= 3 do score += 180
	if difficulty == .Hard && moves >= 1 && moves <= 2 do score += 240
	depth := dependency_depth(board)
	if difficulty == .Medium do score += depth * 12
	if difficulty == .Hard {
		score += depth * 18
		if depth * 2 >= board.arrow_count do score += 250
	}
	return score
}

generate_sparse_board :: proc(side: int, difficulty: Difficulty, seed: u64) -> Board {
	best := Board{}
	best_score := -1000001
	for attempt in 0..<32 {
		candidate := build_candidate(side, difficulty, seed + u64(attempt) * 0x9e3779b97f4a7c15)
		score := candidate_score(&candidate, difficulty)
		if score > best_score {
			best = candidate
			best_score = score
		}
	}
	return best
}

partition_line :: proc(length, min_length, max_length: int, rng: ^Rng, parts: ^[MAX_SIDE]int) -> int {
	count := 0
	remaining := length
	for remaining > 0 {
		piece := rng_range(rng, min_length, min(max_length, remaining) + 1)
		if remaining - piece == 1 {
			if piece < max_length { piece += 1 } else { piece -= 1 }
		}
		parts[count] = piece
		count += 1
		remaining -= piece
	}
	return count
}

add_horizontal_stripe :: proc(board: ^Board, y, min_length, max_length: int, rng: ^Rng) -> bool {
	parts: [MAX_SIDE]int
	count := partition_line(board.side, min_length, max_length, rng, &parts)
	starts: [MAX_SIDE]int
	x := 0
	for i in 0..<count { starts[i] = x; x += parts[i] }
	pivot := rng_range(rng, 0, count)
	if !insert_arrow(board, {starts[pivot], y}, parts[pivot], .Right) do return false
	for i := pivot - 1; i >= 0; i -= 1 {
		tail := Grid_Pos{starts[i] + parts[i] - 1, y}
		if !insert_arrow(board, tail, parts[i], .Left) do return false
	}
	for i in pivot + 1..<count {
		if !insert_arrow(board, {starts[i], y}, parts[i], .Right) do return false
	}
	return true
}

add_vertical_stripe :: proc(board: ^Board, x, y_start, height, min_length, max_length: int, rng: ^Rng) -> bool {
	parts: [MAX_SIDE]int
	count := partition_line(height, min_length, max_length, rng, &parts)
	starts: [MAX_SIDE]int
	y := y_start
	for i in 0..<count { starts[i] = y; y += parts[i] }
	pivot := rng_range(rng, 0, count)
	if !insert_arrow(board, {x, starts[pivot]}, parts[pivot], .Down) do return false
	for i := pivot - 1; i >= 0; i -= 1 {
		tail := Grid_Pos{x, starts[i] + parts[i] - 1}
		if !insert_arrow(board, tail, parts[i], .Up) do return false
	}
	for i in pivot + 1..<count {
		if !insert_arrow(board, {x, starts[i]}, parts[i], .Down) do return false
	}
	return true
}

build_full_candidate :: proc(side: int, difficulty: Difficulty, seed: u64) -> Board {
	board := Board{side = side, seed = seed}
	rng := Rng{state = seed}
	_, _, min_length, max_length, _ := difficulty_parameters(difficulty)
	block_size := 4
	blocks := side / block_size
	// Build a checkerboard of horizontal and vertical regions from bottom-right
	// toward top-left. Every new arrow points left or up into an unfilled region,
	// so it is legal when inserted and becomes part of the final dependency maze.
	for by := blocks - 1; by >= 0; by -= 1 {
		for bx := blocks - 1; bx >= 0; bx -= 1 {
			x0, y0 := bx * block_size, by * block_size
			vertical := (bx + by + int(seed & 1)) % 2 == 0
			if vertical {
				for x in x0..<x0 + block_size {
					parts: [MAX_SIDE]int
					count := partition_line(block_size, min_length, max_length, &rng, &parts)
					y := y0 + block_size
					for i := count - 1; i >= 0; i -= 1 {
						y -= parts[i]
						tail := Grid_Pos{x, y + parts[i] - 1}
						if !insert_arrow(&board, tail, parts[i], .Up) do return {}
					}
				}
			} else {
				for y in y0..<y0 + block_size {
					parts: [MAX_SIDE]int
					count := partition_line(block_size, min_length, max_length, &rng, &parts)
					x := x0 + block_size
					for i := count - 1; i >= 0; i -= 1 {
						x -= parts[i]
						tail := Grid_Pos{x + parts[i] - 1, y}
						if !insert_arrow(&board, tail, parts[i], .Left) do return {}
					}
				}
			}
		}
	}
	for i in 0..<board.arrow_count do board.solution[i] = board.arrow_count - 1 - i
	return board
}

transform_spiral_pos :: proc(p: Grid_Pos, side, transform: int) -> Grid_Pos {
	result := p
	if transform >= 4 do result.x = side - 1 - result.x
	for _ in 0..<(transform % 4) {
		result = {side - 1 - result.y, result.x}
	}
	return result
}

make_spiral_path :: proc(side: int, transform: int, path: ^[MAX_CELLS]Grid_Pos) -> int {
	count := 0
	left, right := 0, side - 1
	top, bottom := 0, side - 1
	for left <= right && top <= bottom {
		for x in left..=right {
			path[count] = transform_spiral_pos({x, top}, side, transform)
			count += 1
		}
		top += 1
		for y in top..=bottom {
			path[count] = transform_spiral_pos({right, y}, side, transform)
			count += 1
		}
		right -= 1
		if top <= bottom {
			for x := right; x >= left; x -= 1 {
				path[count] = transform_spiral_pos({x, bottom}, side, transform)
				count += 1
			}
			bottom -= 1
		}
		if left <= right {
			for y := bottom; y >= top; y -= 1 {
				path[count] = transform_spiral_pos({left, y}, side, transform)
				count += 1
			}
			left += 1
		}
	}
	return count
}

snake_length :: proc(rng: ^Rng, difficulty: Difficulty, remaining: int) -> int {
	low, high := 3, 9
	long_chance := 12
	switch difficulty {
	case .Easy:   low, high, long_chance = 3, 8, 8
	case .Medium: low, high, long_chance = 4, 14, 22
	case .Hard:   low, high, long_chance = 6, 22, 34
	}
	if int(rng_next(rng) % 100) < long_chance {
		low = high
		high = min(MAX_ARROW_LENGTH, high * 3)
	}
	if remaining <= high do return remaining
	length := rng_range(rng, low, high + 1)
	if remaining - length == 1 {
		if length < MAX_ARROW_LENGTH { length += 1 } else { length -= 1 }
	}
	return length
}

append_snake_arrow :: proc(board: ^Board, spiral: []Grid_Pos, start, length: int) -> bool {
	if length < 2 || length > MAX_ARROW_LENGTH || board.arrow_count >= MAX_ARROWS || board.path_cell_count + length > MAX_CELLS do return false
	id := board.arrow_count
	a := &board.arrows[id]
	a.id = id
	a.length = length
	a.path_start = board.path_cell_count
	a.path_count = length
	// Store tail-to-head. The head faces backward through the already-cleared
	// prefix of the spiral when the recorded solution is replayed.
	for i in 0..<length {
		p := spiral[start + length - 1 - i]
		if !in_bounds(board, p) || board.occupancy[cell_index(board, p)] != 0 do return false
		board.path_cells[a.path_start + i] = {u8(p.x), u8(p.y)}
	}
	a.tail = arrow_cell(board, a, 0)
	a.dir = arrow_direction(board, a)
	for i in 0..<length {
		board.occupancy[cell_index(board, arrow_cell(board, a, i))] = id + 1
	}
	board.path_cell_count += length
	board.arrow_count += 1
	return true
}

build_snake_candidate :: proc(side: int, difficulty: Difficulty, seed: u64) -> Board {
	board := Board{side = side, seed = seed}
	rng := Rng{state = seed}
	spiral: [MAX_CELLS]Grid_Pos
	total := make_spiral_path(side, int(rng_next(&rng) % 8), &spiral)
	start := 0
	for start < total {
		length := snake_length(&rng, difficulty, total - start)
		if !append_snake_arrow(&board, spiral[:], start, length) do return {}
		board.solution[board.arrow_count - 1] = board.arrow_count - 1
		start += length
	}
	return board
}

ray_has_no_empty_cells :: proc(board: ^Board, head: Grid_Pos, outward: Direction) -> bool {
	step := direction_step(outward)
	p := pos_add(head, step)
	for in_bounds(board, p) {
		if board.occupancy[cell_index(board, p)] == 0 do return false
		p = pos_add(p, step)
	}
	return true
}

choose_exposed_head :: proc(board: ^Board, rng: ^Rng) -> (Grid_Pos, Direction, bool) {
	chosen: Grid_Pos
	chosen_dir: Direction
	count := 0
	for y in 0..<board.side {
		for x in 0..<board.side {
			head := Grid_Pos{x, y}
			if board.occupancy[cell_index(board, head)] != 0 do continue
			for raw_dir in 0..<4 {
				outward := Direction(raw_dir)
				inward := pos_add(head, direction_step(outward), -1)
				if !in_bounds(board, inward) || board.occupancy[cell_index(board, inward)] != 0 do continue
				if !ray_has_no_empty_cells(board, head, outward) do continue
				count += 1
				if rng_next(rng) % u64(count) == 0 {
					chosen = head
					chosen_dir = outward
				}
			}
		}
	}
	return chosen, chosen_dir, count > 0
}

direction_between :: proc(from, to: Grid_Pos) -> Direction {
	if to.x > from.x do return .Right
	if to.x < from.x do return .Left
	if to.y > from.y do return .Down
	return .Up
}

build_frontier_snake_candidate :: proc(side: int, difficulty: Difficulty, seed: u64) -> Board {
	board := Board{side = side, seed = seed}
	rng := Rng{state = seed}
	remaining := side * side
	turn_chance := 58
	if difficulty == .Easy do turn_chance = 42
	if difficulty == .Hard do turn_chance = 72
	for remaining > 0 {
		if remaining == 1 do return {}
		head, outward, found := choose_exposed_head(&board, &rng)
		if !found do return {}
		grown: [MAX_ARROW_LENGTH]Grid_Pos
		used: [MAX_CELLS]bool
		grown[0] = head
		used[cell_index(&board, head)] = true
		inward := pos_add(head, direction_step(outward), -1)
		grown[1] = inward
		used[cell_index(&board, inward)] = true
		length := 2
		desired := max(2, snake_length(&rng, difficulty, remaining))
		current_dir := direction_between(head, inward)
		for length < desired && length < remaining {
			current := grown[length - 1]
			options: [4]Grid_Pos
			option_dirs: [4]Direction
			option_count := 0
			for raw_dir in 0..<4 {
				dir := Direction(raw_dir)
				p := pos_add(current, direction_step(dir))
				if !in_bounds(&board, p) do continue
				index := cell_index(&board, p)
				if board.occupancy[index] != 0 || used[index] do continue
				options[option_count] = p
				option_dirs[option_count] = dir
				option_count += 1
			}
			if option_count == 0 do break
			choice := rng_range(&rng, 0, option_count)
			if int(rng_next(&rng) % 100) < turn_chance {
				turns: [4]int
				turn_count := 0
				for i in 0..<option_count {
					if option_dirs[i] != current_dir {
						turns[turn_count] = i
						turn_count += 1
					}
				}
				if turn_count > 0 do choice = turns[rng_range(&rng, 0, turn_count)]
			}
			grown[length] = options[choice]
			used[cell_index(&board, options[choice])] = true
			current_dir = option_dirs[choice]
			length += 1
		}
		if remaining - length == 1 {
			current := grown[length - 1]
			for raw_dir in 0..<4 {
				p := pos_add(current, direction_step(Direction(raw_dir)))
				if in_bounds(&board, p) && board.occupancy[cell_index(&board, p)] == 0 && !used[cell_index(&board, p)] {
					grown[length] = p
					used[cell_index(&board, p)] = true
					length += 1
					break
				}
			}
		}
		// append_snake_arrow reverses its input, so pass the grown head-to-tail
		// path directly and retain the intended exposed cell as the arrowhead.
		if !append_snake_arrow(&board, grown[:], 0, length) do return {}
		board.solution[board.arrow_count - 1] = board.arrow_count - 1
		remaining -= length
	}
	return board
}

graph_add_edge :: proc(neighbors: ^[MAX_CELLS][2]int, degree: ^[MAX_CELLS]int, a, b: int) {
	neighbors[a][degree[a]] = b
	degree[a] += 1
	neighbors[b][degree[b]] = a
	degree[b] += 1
}

graph_remove_edge :: proc(neighbors: ^[MAX_CELLS][2]int, degree: ^[MAX_CELLS]int, a, b: int) {
	for i in 0..<degree[a] {
		if neighbors[a][i] == b {
			degree[a] -= 1
			neighbors[a][i] = neighbors[a][degree[a]]
			break
		}
	}
	for i in 0..<degree[b] {
		if neighbors[b][i] == a {
			degree[b] -= 1
			neighbors[b][i] = neighbors[b][degree[b]]
			break
		}
	}
}

splice_maze_cells :: proc(neighbors: ^[MAX_CELLS][2]int, degree: ^[MAX_CELLS]int, side, ax, ay, bx, by: int) {
	index_of :: proc(x, y, width: int) -> int { return y * width + x }
	if bx == ax + 1 {
		a_top := index_of(ax * 2 + 1, ay * 2, side)
		a_bottom := index_of(ax * 2 + 1, ay * 2 + 1, side)
		b_top := index_of(bx * 2, by * 2, side)
		b_bottom := index_of(bx * 2, by * 2 + 1, side)
		graph_remove_edge(neighbors, degree, a_top, a_bottom)
		graph_remove_edge(neighbors, degree, b_top, b_bottom)
		graph_add_edge(neighbors, degree, a_top, b_top)
		graph_add_edge(neighbors, degree, a_bottom, b_bottom)
	} else if bx == ax - 1 {
		splice_maze_cells(neighbors, degree, side, bx, by, ax, ay)
	} else if by == ay + 1 {
		a_left := index_of(ax * 2, ay * 2 + 1, side)
		a_right := index_of(ax * 2 + 1, ay * 2 + 1, side)
		b_left := index_of(bx * 2, by * 2, side)
		b_right := index_of(bx * 2 + 1, by * 2, side)
		graph_remove_edge(neighbors, degree, a_left, a_right)
		graph_remove_edge(neighbors, degree, b_left, b_right)
		graph_add_edge(neighbors, degree, a_left, b_left)
		graph_add_edge(neighbors, degree, a_right, b_right)
	} else {
		splice_maze_cells(neighbors, degree, side, bx, by, ax, ay)
	}
}

make_maze_path :: proc(side: int, rng: ^Rng, path: ^[MAX_CELLS]Grid_Pos, order: ^[MAX_CELLS]int) -> bool {
	neighbors: [MAX_CELLS][2]int
	degree: [MAX_CELLS]int
	coarse := side / 2
	// Begin with one four-cell cycle per coarse cell.
	for cy in 0..<coarse {
		for cx in 0..<coarse {
			tl := (cy * 2) * side + cx * 2
			tr := tl + 1
			bl := tl + side
			br := bl + 1
			graph_add_edge(&neighbors, &degree, tl, tr)
			graph_add_edge(&neighbors, &degree, tr, br)
			graph_add_edge(&neighbors, &degree, br, bl)
			graph_add_edge(&neighbors, &degree, bl, tl)
		}
	}
	// A randomized depth-first spanning tree tells us which cycles to splice.
	visited: [MAX_CELLS]bool
	stack: [MAX_CELLS]int
	stack_count := 1
	stack[0] = rng_range(rng, 0, coarse * coarse)
	visited[stack[0]] = true
	for stack_count > 0 {
		current := stack[stack_count - 1]
		cx, cy := current % coarse, current / coarse
		options: [4]int
		option_count := 0
		if cx > 0 && !visited[current - 1] { options[option_count] = current - 1; option_count += 1 }
		if cx + 1 < coarse && !visited[current + 1] { options[option_count] = current + 1; option_count += 1 }
		if cy > 0 && !visited[current - coarse] { options[option_count] = current - coarse; option_count += 1 }
		if cy + 1 < coarse && !visited[current + coarse] { options[option_count] = current + coarse; option_count += 1 }
		if option_count == 0 { stack_count -= 1; continue }
		next := options[rng_range(rng, 0, option_count)]
		nx, ny := next % coarse, next / coarse
		splice_maze_cells(&neighbors, &degree, side, cx, cy, nx, ny)
		visited[next] = true
		stack[stack_count] = next
		stack_count += 1
	}
	for i in 0..<side * side do if degree[i] != 2 do return false
	current, previous := 0, -1
	for i in 0..<side * side {
		path[i] = {current % side, current / side}
		order[current] = i
		next := neighbors[current][0]
		if next == previous do next = neighbors[current][1]
		previous, current = current, next
	}
	return current == 0
}

maze_cut_is_exposed :: proc(path: ^[MAX_CELLS]Grid_Pos, order: ^[MAX_CELLS]int, cut, total, side: int) -> bool {
	if cut >= total - 1 do return false
	head, after := path[cut], path[cut + 1]
	step := Grid_Pos{head.x - after.x, head.y - after.y}
	p := pos_add(head, step)
	for p.x >= 0 && p.y >= 0 && p.x < side && p.y < side {
		if order[p.y * side + p.x] >= cut do return false
		p = pos_add(p, step)
	}
	return true
}

profiled_snake_length :: proc(rng: ^Rng, difficulty: Difficulty, arrow_index, remaining: int) -> (length: int, gate: bool) {
	small_low, small_high := 3, 9
	gate_low, gate_high := 18, 32
	gate_interval := 10
	switch difficulty {
	case .Easy:
		small_low, small_high = 4, 10
		gate_low, gate_high, gate_interval = 16, 28, 11
	case .Medium:
		small_low, small_high = 3, 8
		gate_low, gate_high, gate_interval = 24, 44, 8
	case .Hard:
		small_low, small_high = 2, 6
		gate_low, gate_high, gate_interval = 32, MAX_ARROW_LENGTH, 6
	}
	gate = arrow_index == 0 || arrow_index % gate_interval == 0
	if gate {
		length = rng_range(rng, gate_low, gate_high + 1)
	} else {
		length = rng_range(rng, small_low, small_high + 1)
	}
	return min(length, remaining), gate
}

build_maze_snake_candidate :: proc(side: int, difficulty: Difficulty, seed: u64) -> Board {
	board := Board{side = side, seed = seed}
	rng := Rng{state = seed}
	path: [MAX_CELLS]Grid_Pos
	order: [MAX_CELLS]int
	total := side * side
	if !make_maze_path(side, &rng, &path, &order) do return {}
	start := 0
	for start < total {
		remaining := total - start
		desired, _ := profiled_snake_length(&rng, difficulty, board.arrow_count, remaining)
		if remaining <= desired && remaining <= MAX_ARROW_LENGTH {
			if !append_snake_arrow(&board, path[:], start, remaining) do return {}
			board.solution[board.arrow_count - 1] = board.arrow_count - 1
			break
		}
		best_length, best_distance := 0, MAX_ARROW_LENGTH + 1
		upper := min(MAX_ARROW_LENGTH, remaining - 2)
		for length in 2..=upper {
			if !maze_cut_is_exposed(&path, &order, start + length, total, side) do continue
			distance := abs(length - desired)
			if distance < best_distance {
				best_length, best_distance = length, distance
			}
		}
		if best_length == 0 do return {}
		if !append_snake_arrow(&board, path[:], start, best_length) do return {}
		board.solution[board.arrow_count - 1] = board.arrow_count - 1
		start += best_length
	}
	return board
}

maze_candidate_score :: proc(source: ^Board, difficulty: Difficulty) -> int {
	if source.arrow_count == 0 do return -1000000
	short_limit, wanted_moves := 9, 5
	switch difficulty {
	case .Easy:   short_limit, wanted_moves = 10, 5
	case .Medium: short_limit, wanted_moves = 8, 3
	case .Hard:   short_limit, wanted_moves = 6, 1
	}
	short_count, long_count := 0, 0
	for i in 0..<source.arrow_count {
		length := source.arrows[i].length
		if length <= short_limit do short_count += 1
		if length >= source.side do long_count += 1
	}
	board := source^
	initial_moves := legal_move_count(&board)
	max_unlock, max_long_unlock := 0, 0
	frontier_total := 0
	for step in 0..<board.arrow_count {
		before: [MAX_ARROWS]bool
		for i in 0..<board.arrow_count {
			before[i] = !board.arrows[i].removed && can_escape(&board, i)
			if before[i] do frontier_total += 1
		}
		id := board.solution[step]
		length := board.arrows[id].length
		if !remove_arrow(&board, id) do return -1000000
		unlocked := 0
		for i in 0..<board.arrow_count {
			if !board.arrows[i].removed && !before[i] && can_escape(&board, i) do unlocked += 1
		}
		max_unlock = max(max_unlock, unlocked)
		if length >= source.side do max_long_unlock = max(max_long_unlock, unlocked)
	}
	score := source.arrow_count * 20 + short_count * 45 + long_count * 90
	score -= abs(initial_moves - wanted_moves) * 240
	if difficulty == .Medium && initial_moves > 4 do score -= (initial_moves - 4) * 2000
	if difficulty == .Hard && initial_moves > 2 do score -= (initial_moves - 2) * 5000
	score += max_unlock * 80 + max_long_unlock * 260
	if max_long_unlock == 0 do score -= 10000
	if difficulty == .Medium do score -= frontier_total / 3
	if difficulty == .Hard do score -= frontier_total / 2
	if short_count * 5 >= source.arrow_count * 3 do score += 500
	if long_count >= 2 do score += 350
	return score
}

generate_board :: proc(side: int, difficulty: Difficulty, seed: u64) -> Board {
	best := Board{}
	best_score := -1000001
	for attempt in 0..<256 {
		candidate := build_maze_snake_candidate(side, difficulty, seed + u64(attempt) * 0x9e3779b97f4a7c15)
		if candidate.arrow_count == 0 || !rebuild_occupancy(&candidate) || !solution_clears(&candidate) do continue
		score := maze_candidate_score(&candidate, difficulty)
		if score > best_score {
			best = candidate
			best_score = score
		}
	}
	if best.arrow_count > 0 do return best
	// Exact deterministic fallback for exceptionally unlucky maze cuts.
	return build_snake_candidate(side, difficulty, seed)
}
