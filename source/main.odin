package game

import "g"
import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI, .MSAA_4X_HINT})
	rl.InitWindow(1100, 760, "Cnarrow")
	defer rl.CloseWindow()
	rl.SetWindowMinSize(360, 600)

	rl.SetTargetFPS(60)

	g.game_init(&g.game)
	defer g.game_destroy(&g.game)

	for !rl.WindowShouldClose() {
		ft := rl.GetFrameTime()

		g.game_update(&g.game, ft)

		rl.BeginDrawing()
		rl.ClearBackground(g.SAGE)
		g.game_draw(&g.game, ft)
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}
}
