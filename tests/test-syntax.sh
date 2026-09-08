#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

for script in \
    "$PROJECT_ROOT/install.sh" \
    "$PROJECT_ROOT/uninstall.sh" \
    "$PROJECT_ROOT/config/blesh-macos-bindings.bash" \
    "$PROJECT_ROOT/tests/test-install.sh" \
    "$PROJECT_ROOT/tests/test-syntax.sh"; do
    /bin/bash -n "$script"
done

if [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
    TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ghostty-macos-keybindings-config-test.XXXXXX")
    trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM
    cp "$PROJECT_ROOT/config/ghostty-macos-keybindings.conf" "$TEST_ROOT/config.ghostty"
    /Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config --config-file="$TEST_ROOT/config.ghostty"
fi

printf 'syntax test passed\n'
