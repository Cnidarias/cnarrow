#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$project_dir/build"
odin build "$project_dir/source" -out:"$project_dir/build/cnarrow" -o:speed
echo "Built $project_dir/build/cnarrow"
