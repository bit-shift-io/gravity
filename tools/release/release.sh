#!/bin/sh
# Release tooling entry point. Run from anywhere.
#   tools/release/release.sh build [windows|macos|linux|all]   run all tests, then bundles into build/
#   tools/release/release.sh upload [--dry-run]                 Steam upload of build/
#   tools/release/release.sh all                                tests, build everything, then upload
# build and all abort if any test tier fails; SKIP_TESTS=1 skips them (local packaging checks only).
# One Steam depot (OS: All) holds all three platforms. Launch options to configure in Steamworks:
#   windows windows/gravity.exe, macOS macos/gravity.app, linux linux/gravity.sh
set -e
cd "$(dirname "$0")/../.."

if command -v luajit >/dev/null 2>&1; then LUA=luajit; else LUA=lua; fi

run_tests() {
	if [ -n "$SKIP_TESTS" ]; then
		echo "warning: SKIP_TESTS set; not running tests"
		return
	fi
	sh test-all.sh || { echo "release aborted: tests failed" >&2; exit 1; }
}

cmd="${1:-}"
[ $# -gt 0 ] && shift
case "$cmd" in
	build)
		run_tests
		$LUA tools/release/build.lua "$@"
		;;
	upload) $LUA tools/release/steam_upload.lua "$@" ;;
	all)
		run_tests
		$LUA tools/release/build.lua all
		$LUA tools/release/steam_upload.lua "$@"
		;;
	*) sed -n '2,7p' tools/release/release.sh; exit 1 ;;
esac
