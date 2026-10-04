#!/bin/sh
# Slow AI balance runs (full seeded matches played to a winner). Not part of
# test-all.sh; run it when tuning or changing AI behaviour. Uses the
# integration runner and harness, so it takes the same file arguments.
set -e

if [ "$#" -eq 0 ]; then
	set -- tests/balance/*_test.lua
fi

if command -v luajit >/dev/null 2>&1; then
	luajit tests/integration/run.lua "$@"
else
	lua tests/integration/run.lua "$@"
fi
