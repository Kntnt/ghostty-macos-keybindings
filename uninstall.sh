#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME=ghostty-macos-keybindings
BASHRC_BEGIN='# ghostty-macos-keybindings bashrc begin'
BASHRC_END='# ghostty-macos-keybindings bashrc end'
BASHRC_ATTACH_BEGIN='# ghostty-macos-keybindings attach begin'
BASHRC_ATTACH_END='# ghostty-macos-keybindings attach end'
LOGIN_BEGIN='# ghostty-macos-keybindings login begin'
LOGIN_END='# ghostty-macos-keybindings login end'
GHOSTTY_BEGIN='# ghostty-macos-keybindings include begin'
GHOSTTY_END='# ghostty-macos-keybindings include end'

strip_block_in_place() {
    local file=$1 begin=$2 end=$3
    [ -f "$file" ] || return 0
    local temporary
    temporary=$(mktemp "${TMPDIR:-/tmp}/ghostty-macos-keybindings-uninstall.XXXXXX")
    awk -v begin="$begin" -v end="$end" '
        $0 == begin { managed = 1; next }
        $0 == end { managed = 0; next }
        !managed { print }
    ' "$file" > "$temporary"
    chmod "$(/usr/bin/stat -f '%Lp' "$file")" "$temporary"
    mv "$temporary" "$file"
}

project_config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/$PROJECT_NAME
project_data_dir=${XDG_DATA_HOME:-$HOME/.local/share}/$PROJECT_NAME

strip_block_in_place "$HOME/.bashrc" "$BASHRC_BEGIN" "$BASHRC_END"
strip_block_in_place "$HOME/.bashrc" "$BASHRC_ATTACH_BEGIN" "$BASHRC_ATTACH_END"

for login_file in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
    strip_block_in_place "$login_file" "$LOGIN_BEGIN" "$LOGIN_END"
done

for ghostty_directory in \
    "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty"; do
    for ghostty_config in "$ghostty_directory/config.ghostty" "$ghostty_directory/config"; do
        strip_block_in_place "$ghostty_config" "$GHOSTTY_BEGIN" "$GHOSTTY_END"
    done
    rm -f "$ghostty_directory/ghostty-macos-keybindings.conf"
done

rm -rf "$project_data_dir"
rm -f "$project_config_dir/blesh-macos-bindings.bash"

printf 'ghostty-macos-keybindings: uninstalled\n'
if [ -d "$project_config_dir/backups" ]; then
    printf 'Backups were kept in %s\n' "$project_config_dir/backups"
fi
printf 'Reload Ghostty with Command+Shift+, then run: exec bash -l\n'
