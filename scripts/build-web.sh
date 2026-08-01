#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
odin_root="$(odin root)"
raylib_web="$odin_root/vendor/raylib/wasm/libraylib.web.a"
build_commit="${BUILD_COMMIT:-}"

if [[ -z "$build_commit" ]] && command -v git >/dev/null 2>&1; then
  build_commit="$(git -C "$project_dir" rev-parse --short HEAD 2>/dev/null || true)"
fi
if [[ ! "$build_commit" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
  build_commit="local"
else
  build_commit="${build_commit:0:7}"
fi

if ! command -v emcc >/dev/null 2>&1; then
  echo "error: emcc was not found; activate the Emscripten SDK first" >&2
  exit 1
fi
if [[ ! -f "$raylib_web" ]]; then
  echo "error: Odin's Raylib web archive was not found at $raylib_web" >&2
  exit 1
fi

mkdir -p "$project_dir/build"
odin build "$project_dir/source/web" \
  -collection:src="$project_dir/source" \
  -target:js_wasm32 \
  -build-mode:obj \
  -define:RAYLIB_WASM_LIB=env.o \
  -out:"$project_dir/build/cnarrow.obj" \
  -o:speed

emcc -c "$project_dir/web/emscripten-allocator.c" \
  -o "$project_dir/build/emscripten-allocator.o"

emcc "$project_dir/build/cnarrow.obj" "$project_dir/build/emscripten-allocator.o" \
  -Wl,--whole-archive "$raylib_web" -Wl,--no-whole-archive \
  -o "$project_dir/build/cnarrow.js" \
  --js-library "$project_dir/web/odin-emscripten-library.js" \
  -sUSE_GLFW=3 \
  -sINITIAL_MEMORY=67108864 \
  -sSTACK_SIZE=2097152 \
  -sENVIRONMENT=web \
  -sMODULARIZE=1 \
  -sEXPORT_NAME=createCnarrowModule \
  -sEXPORTED_FUNCTIONS='["_cnarrow_start","_cnarrow_frame","_cnarrow_resize","_cnarrow_set_board_view","_cnarrow_board_pan_x","_cnarrow_board_pan_y","_cnarrow_screen_width","_cnarrow_screen_height","_cnarrow_set_input_suppressed","_cnarrow_tap","_cnarrow_shutdown"]' \
  -sNO_EXIT_RUNTIME=1 \
  -sASSERTIONS=1

sed "s/__BUILD_COMMIT__/$build_commit/g" "$project_dir/web/index.html" > "$project_dir/build/index.html"
sed "s/__BUILD_COMMIT__/$build_commit/g" "$project_dir/web/service-worker.js" > "$project_dir/build/service-worker.js"
cp "$project_dir/web/manifest.webmanifest" "$project_dir/build/manifest.webmanifest"
cp "$project_dir/web/favicon.png" "$project_dir/build/favicon.png"
cp "$project_dir/web/apple-touch-icon.png" "$project_dir/build/apple-touch-icon.png"
cp "$project_dir/web/icon-192.png" "$project_dir/build/icon-192.png"
cp "$project_dir/web/icon-512.png" "$project_dir/build/icon-512.png"
cp "$project_dir/web/icon-maskable-512.png" "$project_dir/build/icon-maskable-512.png"
cp "$odin_root/core/sys/wasm/js/odin.js" "$project_dir/build/odin.js"
echo "Built browser game $build_commit in $project_dir/build"
