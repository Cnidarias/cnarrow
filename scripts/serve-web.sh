#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir/build"
echo "Serving Cnarrow at http://localhost:8000"
python3 -m http.server 8000
