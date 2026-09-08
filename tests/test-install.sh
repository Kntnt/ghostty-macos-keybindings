#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ghostty-macos-keybindings-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

TEST_HOME=$TEST_ROOT/home
TEST_BIN=$TEST_ROOT/bin
mkdir -p "$TEST_HOME/.config/ghostty" "$TEST_BIN"

cat > "$TEST_HOME/.bashrc" <<'EOF'
# existing bashrc content
export EXISTING_BASHRC_VALUE=preserved
EOF

cat > "$TEST_HOME/.bash_profile" <<'EOF'
# existing login content
export EXISTING_LOGIN_VALUE=preserved
EOF

cat > "$TEST_HOME/.config/ghostty/config.ghostty" <<'EOF'
# existing Ghostty content
font-size = 14
EOF

cat > "$TEST_BIN/ghostty" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TEST_BIN/ghostty"

export HOME=$TEST_HOME
export SHELL=/bin/bash
export XDG_CONFIG_HOME=$TEST_HOME/.config
export XDG_DATA_HOME=$TEST_HOME/.local/share
export GHOSTTY_MACOS_KEYBINDINGS_GHOSTTY_BIN=$TEST_BIN/ghostty

"$PROJECT_ROOT/install.sh"
"$PROJECT_ROOT/install.sh"

assert_count() {
    local expected=$1 pattern=$2 file=$3 actual
    actual=$(grep -cF "$pattern" "$file" || true)
    [ "$actual" = "$expected" ] || {
        printf 'expected %s occurrence(s) of %s in %s, got %s\n' "$expected" "$pattern" "$file" "$actual" >&2
        exit 1
    }
}

assert_count 1 '# ghostty-macos-keybindings bashrc begin' "$HOME/.bashrc"
assert_count 1 '# ghostty-macos-keybindings attach begin' "$HOME/.bashrc"
assert_count 1 '# ghostty-macos-keybindings login begin' "$HOME/.bash_profile"
assert_count 1 '# ghostty-macos-keybindings include begin' "$HOME/.config/ghostty/config.ghostty"
assert_count 1 'export EXISTING_BASHRC_VALUE=preserved' "$HOME/.bashrc"
assert_count 1 'export EXISTING_LOGIN_VALUE=preserved' "$HOME/.bash_profile"
assert_count 1 'font-size = 14' "$HOME/.config/ghostty/config.ghostty"

[ -r "$XDG_DATA_HOME/ghostty-macos-keybindings/blesh/ble.sh" ]
[ -r "$XDG_CONFIG_HOME/ghostty-macos-keybindings/blesh-macos-bindings.bash" ]
[ -r "$XDG_CONFIG_HOME/ghostty/ghostty-macos-keybindings.conf" ]

if [ "${GHOSTTY_MACOS_KEYBINDINGS_SKIP_PTY_TEST:-0}" = 1 ]; then
    printf 'PTY behavior test skipped: hosted CI does not provide a terminal emulator\n'
elif [ -x /usr/bin/expect ]; then
    TEST_BASHRC=$HOME/.bashrc /usr/bin/expect "$PROJECT_ROOT/tests/test-keybindings.exp"
fi

"$PROJECT_ROOT/uninstall.sh"

assert_count 0 '# ghostty-macos-keybindings' "$HOME/.bashrc"
assert_count 0 '# ghostty-macos-keybindings' "$HOME/.bash_profile"
assert_count 0 '# ghostty-macos-keybindings' "$HOME/.config/ghostty/config.ghostty"
assert_count 1 'export EXISTING_BASHRC_VALUE=preserved' "$HOME/.bashrc"
assert_count 1 'export EXISTING_LOGIN_VALUE=preserved' "$HOME/.bash_profile"
assert_count 1 'font-size = 14' "$HOME/.config/ghostty/config.ghostty"
[ ! -e "$XDG_DATA_HOME/ghostty-macos-keybindings" ]
[ ! -e "$XDG_CONFIG_HOME/ghostty/ghostty-macos-keybindings.conf" ]

printf 'installer test passed\n'
