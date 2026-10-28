#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
engine=${GODOT_BIN:-godot}
"$engine" --headless --path "$project_dir/game" --script res://tests/run_tests.gd
"$engine" --headless --path "$project_dir/game" --script res://tests/smoke_transitions.gd
