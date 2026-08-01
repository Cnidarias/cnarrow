package g

MAX_SIDE   :: 40
MAX_CELLS  :: MAX_SIDE * MAX_SIDE
MAX_ARROWS :: MAX_CELLS / 2
MAX_ARROW_LENGTH :: 128
MAX_ACTIVE_ANIMATIONS :: 32

Grid_Pos :: struct { x, y: int }
Path_Pos :: struct { x, y: u8 }

Direction :: enum { Up, Right, Down, Left }
Difficulty :: enum { Easy, Medium, Hard }
Grid_Size :: enum { Small, Medium, Large }
Game_Phase :: enum { Playing, Confirm_New, Complete }
Animation_Kind :: enum { None, Escaping, Blocked }

Arrow_Animation :: struct {
	kind:       Animation_Kind,
	arrow_id:   int,
	blocker_id: int,
	time:       f32,
	duration:   f32,
	offset:     f32,
	stretch:    f32,
}

Arrow :: struct {
	id:      int,
	tail:    Grid_Pos,
	length:  int,
	dir:     Direction,
	path_start:int,
	path_count:int,
	removed: bool,
}

Board :: struct {
	side:       int,
	arrows:     [MAX_ARROWS]Arrow,
	arrow_count:int,
	occupancy:  [MAX_CELLS]int, // zero is empty; otherwise arrow id + 1
	path_cells: [MAX_CELLS]Path_Pos,
	path_cell_count:int,
	solution:   [MAX_ARROWS]int,
	seed:       u64,
}

Game :: struct {
	board:              Board,
	animations:         [MAX_ACTIVE_ANIMATIONS]Arrow_Animation,
	phase:              Game_Phase,
	selected_size:      Grid_Size,
	selected_difficulty:Difficulty,
	applied_size:       Grid_Size,
	applied_difficulty: Difficulty,
	elapsed:            f32,
	blocked_taps:       int,
	removed_count:      int,
	seed_counter:       u64,
	celebration_time:   f32,
	board_zoom:         f32,
	board_pan:          [2]f32,
	input_suppressed:   bool,
	touch_down:         bool,
}

game: Game

grid_side :: proc(size: Grid_Size) -> int {
	switch size {
	case .Small:  return 24
	case .Medium: return 32
	case .Large:  return 40
	}
	return 8
}

direction_step :: proc(dir: Direction) -> Grid_Pos {
	switch dir {
	case .Up:    return {0, -1}
	case .Right: return {1, 0}
	case .Down:  return {0, 1}
	case .Left:  return {-1, 0}
	}
	return {}
}

pos_add :: proc(a, b: Grid_Pos, scale := 1) -> Grid_Pos {
	return {a.x + b.x * scale, a.y + b.y * scale}
}

in_bounds :: proc(board: ^Board, p: Grid_Pos) -> bool {
	return p.x >= 0 && p.y >= 0 && p.x < board.side && p.y < board.side
}

cell_index :: proc(board: ^Board, p: Grid_Pos) -> int {
	return p.y * board.side + p.x
}

arrow_cell :: proc(board: ^Board, arrow: ^Arrow, segment: int) -> Grid_Pos {
	if arrow.path_count > 0 {
		p := board.path_cells[arrow.path_start + segment]
		return {int(p.x), int(p.y)}
	}
	return pos_add(arrow.tail, direction_step(arrow.dir), segment)
}

arrow_head :: proc(board: ^Board, arrow: ^Arrow) -> Grid_Pos {
	return arrow_cell(board, arrow, arrow.length - 1)
}

arrow_direction :: proc(board: ^Board, arrow: ^Arrow) -> Direction {
	if arrow.path_count < 2 do return arrow.dir
	head := arrow_cell(board, arrow, arrow.path_count - 1)
	before := arrow_cell(board, arrow, arrow.path_count - 2)
	dx, dy := head.x - before.x, head.y - before.y
	if dx > 0 do return .Right
	if dx < 0 do return .Left
	if dy > 0 do return .Down
	return .Up
}

arrow_tail_direction :: proc(board: ^Board, arrow: ^Arrow) -> Direction {
	if arrow.path_count < 2 do return arrow.dir
	first, second := arrow_cell(board, arrow, 0), arrow_cell(board, arrow, 1)
	dx, dy := second.x - first.x, second.y - first.y
	if dx > 0 do return .Right
	if dx < 0 do return .Left
	if dy > 0 do return .Down
	return .Up
}
