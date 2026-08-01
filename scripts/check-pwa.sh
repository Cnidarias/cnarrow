#!/usr/bin/env bash
set -euo pipefail

site_dir="${1:-build}"
required_files=(
  index.html
  manifest.webmanifest
  service-worker.js
  odin.js
  cnarrow.js
  cnarrow.wasm
  favicon.png
  apple-touch-icon.png
  icon-192.png
  icon-512.png
  icon-maskable-512.png
)

for file in "${required_files[@]}"; do
  if [[ ! -s "$site_dir/$file" ]]; then
    echo "error: PWA bundle is missing $file" >&2
    exit 1
  fi
done

grep -Fq '<link rel="manifest" href="manifest.webmanifest">' "$site_dir/index.html"
grep -Fq "navigator.serviceWorker.register('service-worker.js'" "$site_dir/index.html"
grep -Fq '"display": "standalone"' "$site_dir/manifest.webmanifest"
grep -Fq '"purpose": "maskable"' "$site_dir/manifest.webmanifest"
grep -Fq "'./cnarrow.wasm'" "$site_dir/service-worker.js"

if grep -R -Fq '__BUILD_COMMIT__' "$site_dir/index.html" "$site_dir/service-worker.js"; then
  echo "error: build commit placeholder was not replaced" >&2
  exit 1
fi

echo "PWA bundle checks passed in $site_dir"
