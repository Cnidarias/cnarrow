#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$project_dir/build"
odin test "$project_dir/tests" -collection:src="$project_dir/source" -out:"$project_dir/build/cnarrow-tests" -o:speed
