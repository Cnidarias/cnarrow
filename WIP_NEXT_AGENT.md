# Work-in-progress handoff

The `work-in-progress` branch contains the Docker web build and phone-friendly portrait layout work.

## Current state

- `Dockerfile` is a multi-stage Emscripten/Odin build with an unprivileged nginx runtime on port 8080.
- `nginx/default.conf` serves the generated bundle and gives `.wasm` the correct MIME type.
- `scripts/build-web.sh` builds Odin to a relocatable WebAssembly object, compiles `web/odin-raylib-shim.c`, and links Odin's Raylib web archive with Emscripten.
- `web/odin-emscripten-library.js` supplies Odin's `rand_bytes`, `sin`, and `write` imports.
- Portrait layouts hide size/difficulty selectors and enlarge touch targets; the gameplay/native tests pass.

## Verification already done

- `odin check source` passes.
- `./scripts/test.sh` passes all 8 tests.
- `docker build -t cnarrow-web:test .` succeeds.
- nginx smoke test returns 200 for `/` and `application/wasm` for `/cnarrow.wasm`; the container health check is healthy.

## Remaining browser issue

The browser reaches Raylib initialization, then Chrome reports `RuntimeError: memory access out of bounds` from `_cnarrow_start` while `g.game_init` generates the first puzzle. The earlier `freestanding_wasm32` link avoided unresolved runtime imports but caused this startup trap, so the current script has been switched back to `js_wasm32` to restore Odin's JavaScript runtime initialization. Rebuild and test this current version in a browser first.

If the trap remains, instrument `cnarrow_start` around `runtime.default_context`, `rl.InitWindow`, and `g.game_init`; compare the generated object/runtime startup between `js_wasm32` and `freestanding_wasm32`. Keep the Raylib shim: Odin namespaces foreign imports as `wasm/libraylib.web.a..Name`, while Raylib exports ordinary C names.
