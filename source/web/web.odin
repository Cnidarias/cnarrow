package web

import "src:g"
import "core:mem"
import "base:runtime"
import rl "vendor:raylib"

web_game: g.Game
web_started: bool
web_context: runtime.Context

@(export)
cnarrow_start :: proc "c" (width, height: i32) {
	if web_started do return
	web_context = runtime.default_context()
	web_context.allocator = emscripten_allocator()
	context = web_context
	runtime.init_global_temporary_allocator(1 * mem.Megabyte)
	web_context = context
	rl.SetConfigFlags({.WINDOW_HIGHDPI, .MSAA_4X_HINT})
	rl.InitWindow(width, height, "Cnarrow")
	rl.SetTargetFPS(60)
	g.game_init(&web_game)
	web_started = true
}

@(export)
cnarrow_frame :: proc "c" () {
	if !web_started do return
	context = web_context
	dt := rl.GetFrameTime()
	g.game_update(&web_game, dt)
	rl.BeginDrawing()
	rl.ClearBackground(g.SAGE)
	g.game_draw(&web_game, dt)
	rl.EndDrawing()
	free_all(context.temp_allocator)
}

@(export)
cnarrow_resize :: proc "c" (width, height: i32) {
	context = web_context
	if web_started do rl.SetWindowSize(width, height)
}

@(export)
cnarrow_shutdown :: proc "c" () {
	if !web_started do return
	context = web_context
	g.game_destroy(&web_game)
	rl.CloseWindow()
	web_started = false
}

main :: proc() {}
