# Cnarrow

Cnarrow is a calm, asset-free arrow-clearing puzzle written in Odin and drawn entirely with Raylib primitives. Select an arrow whose head has a clear path to the edge. Clear arrows slither away; blocked arrows gently compress and return. There is no penalty for trying.

Puzzles completely tile the starting grid, then are checked with the same occupancy/collision logic used during play. A randomized spanning maze is converted into winding multi-turn arrows, including long paths that cross several areas. Carefully selected path cuts provide a guaranteed clearing order without leaving empty starting points. The three grid sizes (24×24, 32×32, 40×40) and Easy, Medium, and Hard presets configure the next puzzle.

Most arrows are deliberately short, while occasional long “gate” arrows cross several regions and block multiple later paths. Difficulty changes that distribution and the opening frontier: Hard emphasizes very short pieces around stronger long gates and normally exposes no more than two initial moves; Medium allows up to four; Easy leaves a broader set of choices.

## Prerequisites

- A recent [Odin compiler](https://odin-lang.org/docs/install/) with its bundled `vendor:raylib` package.
- Clang and the usual desktop graphics/X11 development libraries required by Raylib on Linux.
- For browser builds, an activated [Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html) that provides `emcc`. The build uses Odin's bundled `vendor/raylib/wasm/libraylib.web.a` and follows Raylib's [web build model](https://github.com/raysan5/raylib/wiki/Working-for-Web-(HTML5)).

No textures, fonts, sounds, or other runtime assets are required.

## Desktop

```sh
./scripts/build-desktop.sh
./build/cnarrow
```

The window is resizable and supports high-DPI displays. The interface switches between side-by-side and stacked layouts for landscape and portrait windows.

## Tests

```sh
./scripts/test.sh
```

Tests cover grid occupancy, heads and bounds, blockers and removal, deterministic generation across every preset, recorded-solution replay, animation endpoints, confirmation, completion, and next-puzzle flow.

## Browser

Activate Emscripten first (usually `source /path/to/emsdk/emsdk_env.sh`), then run:

```sh
./scripts/build-web.sh
./scripts/serve-web.sh
```

Open <http://localhost:8000>. A local HTTP server is required; opening `index.html` directly from disk will not reliably load WebAssembly. The HTML shell handles touch input, responsive canvas resizing, safe areas, high-DPI backing resolution, loading feedback, and startup errors. The generated module uses a fixed 64 MiB wasm memory and Emscripten's GLFW/raylib WebGL path.

### Docker

The multi-stage image installs the pinned Odin and Emscripten toolchains, builds the browser bundle, and copies only the static output into an unprivileged nginx image:

```sh
docker build -t cnarrow-web .
docker run --rm -p 8080:8080 cnarrow-web
```

Open <http://localhost:8080>. The container includes a health check and serves WebAssembly with the correct MIME type. Portrait layouts put the title and puzzle status above the centered board, with a touch-sized New Puzzle button anchored at the bottom. Pinch with two fingers to zoom, then drag with one finger to pan the board for more precise taps.

Or use Compose:

```sh
docker compose up --build
```

### GitHub Pages

The repository includes a GitHub Actions workflow that builds the static browser bundle with the Docker builder stage and deploys it to GitHub Pages on pushes to `master`:

```sh
.github/workflows/pages.yml
```

In the repository settings, set Pages to use GitHub Actions as the publishing source.

## Project layout

- `source/g/`: board model, collision, generation, animations, UI, and rendering
- `source/main.odin`: desktop Raylib loop
- `source/web/web.odin`: four exported browser lifecycle procedures
- `tests/`: headless gameplay and generation tests
- `web/index.html`: responsive browser shell
