#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME=ghostty-macos-keybindings
PROJECT_REPOSITORY=TBarregren/ghostty-macos-keybindings
PROJECT_SOURCE_REF=${GHOSTTY_MACOS_KEYBINDINGS_REF:-main}
BLESH_ARCHIVE_NAME=ble-nightly-20260711+d69e4d5.tar.xz
BLESH_ARCHIVE_URL=https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly-20260711%2Bd69e4d5.tar.xz
BLESH_ARCHIVE_SHA256=e4b467045519ab3c0eb8feb23b23998ee0aa26488603c7fcb437fd47f8591278

BASHRC_BEGIN='# ghostty-macos-keybindings bashrc begin'
BASHRC_END='# ghostty-macos-keybindings bashrc end'
BASHRC_ATTACH_BEGIN='# ghostty-macos-keybindings attach begin'
BASHRC_ATTACH_END='# ghostty-macos-keybindings attach end'
LOGIN_BEGIN='# ghostty-macos-keybindings login begin'
LOGIN_END='# ghostty-macos-keybindings login end'
GHOSTTY_BEGIN='# ghostty-macos-keybindings include begin'
GHOSTTY_END='# ghostty-macos-keybindings include end'

info() {
    printf 'ghostty-macos-keybindings: %s\n' "$*"
}

warn() {
    printf 'ghostty-macos-keybindings: warning: %s\n' "$*" >&2
}

die() {
    printf 'ghostty-macos-keybindings: error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

shell_quote() {
    printf '%q' "$1"
}

marker_count() {
    local file=$1 marker=$2
    [ -f "$file" ] || { printf '0\n'; return; }
    awk -v marker="$marker" '$0 == marker { count++ } END { print count + 0 }' "$file"
}

strip_managed_block() {
    local file=$1 begin=$2 end=$3 output=$4
    local begin_count end_count
    begin_count=$(marker_count "$file" "$begin")
    end_count=$(marker_count "$file" "$end")

    [ "$begin_count" = "$end_count" ] ||
        die "unmatched managed markers in $file; restore the file from backup before retrying"
    [ "$begin_count" -le 1 ] ||
        die "duplicate managed markers in $file; restore the file from backup before retrying"

    if [ ! -f "$file" ]; then
        : > "$output"
        return
    fi

    awk -v begin="$begin" -v end="$end" '
        $0 == begin { managed = 1; next }
        $0 == end { managed = 0; next }
        !managed { print }
    ' "$file" > "$output"
}

replace_file() {
    local source=$1 destination=$2
    if [ -f "$destination" ]; then
        chmod "$(/usr/bin/stat -f '%Lp' "$destination")" "$source"
    else
        chmod 600 "$source"
    fi
    mv "$source" "$destination"
}

prepend_managed_block() {
    local file=$1 begin=$2 end=$3 block=$4
    local cleaned result
    cleaned=$(mktemp "$PROJECT_TEMP_DIR/cleaned.XXXXXX")
    result=$(mktemp "$PROJECT_TEMP_DIR/result.XXXXXX")
    strip_managed_block "$file" "$begin" "$end" "$cleaned"
    {
        cat "$block"
        [ ! -s "$cleaned" ] || printf '\n'
        cat "$cleaned"
    } > "$result"
    replace_file "$result" "$file"
}

append_managed_block() {
    local file=$1 begin=$2 end=$3 block=$4
    local cleaned result
    cleaned=$(mktemp "$PROJECT_TEMP_DIR/cleaned.XXXXXX")
    result=$(mktemp "$PROJECT_TEMP_DIR/result.XXXXXX")
    strip_managed_block "$file" "$begin" "$end" "$cleaned"
    {
        cat "$cleaned"
        [ ! -s "$cleaned" ] || printf '\n'
        cat "$block"
    } > "$result"
    replace_file "$result" "$file"
}

backup_file() {
    local file=$1 name=$2
    [ -f "$file" ] || return 0
    mkdir -p "$PROJECT_BACKUP_DIR"
    cp -p "$file" "$PROJECT_BACKUP_DIR/$name"
}

download_project_file() {
    local relative_path=$1 destination=$2
    local local_file=
    if [ -n "${PROJECT_SCRIPT_DIR:-}" ]; then
        local_file=$PROJECT_SCRIPT_DIR/$relative_path
    fi

    if [ -n "$local_file" ] && [ -f "$local_file" ]; then
        cp "$local_file" "$destination"
    else
        curl -fsSL --retry 3 \
            "https://raw.githubusercontent.com/$PROJECT_REPOSITORY/$PROJECT_SOURCE_REF/$relative_path" \
            -o "$destination"
    fi
}

find_ghostty_config() {
    local xdg_directory=${XDG_CONFIG_HOME:-$HOME/.config}/ghostty
    local mac_directory=$HOME/Library/Application\ Support/com.mitchellh.ghostty

    if [ -f "$mac_directory/config.ghostty" ]; then
        printf '%s\n' "$mac_directory/config.ghostty"
    elif [ -f "$mac_directory/config" ]; then
        printf '%s\n' "$mac_directory/config"
    elif [ -f "$xdg_directory/config.ghostty" ]; then
        printf '%s\n' "$xdg_directory/config.ghostty"
    elif [ -f "$xdg_directory/config" ]; then
        printf '%s\n' "$xdg_directory/config"
    else
        printf '%s\n' "$xdg_directory/config.ghostty"
    fi
}

find_ghostty_binary() {
    if [ -n "${GHOSTTY_MACOS_KEYBINDINGS_GHOSTTY_BIN:-}" ]; then
        printf '%s\n' "$GHOSTTY_MACOS_KEYBINDINGS_GHOSTTY_BIN"
    elif command -v ghostty >/dev/null 2>&1; then
        command -v ghostty
    elif [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
        printf '%s\n' /Applications/Ghostty.app/Contents/MacOS/ghostty
    elif [ -x "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
        printf '%s\n' "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty"
    fi
}

install_blesh() {
    local version_file=$PROJECT_DATA_DIR/blesh-version
    if [ -r "$PROJECT_DATA_DIR/blesh/ble.sh" ] &&
       [ -r "$version_file" ] &&
       [ "$(cat "$version_file")" = "$BLESH_ARCHIVE_NAME" ]; then
        info "ble.sh $BLESH_ARCHIVE_NAME is already installed"
        return
    fi

    local archive=$PROJECT_TEMP_DIR/$BLESH_ARCHIVE_NAME
    if [ -n "${GHOSTTY_MACOS_KEYBINDINGS_BLESH_ARCHIVE:-}" ]; then
        cp "$GHOSTTY_MACOS_KEYBINDINGS_BLESH_ARCHIVE" "$archive"
    else
        info 'downloading ble.sh'
        curl -fL --retry 3 --silent --show-error "$BLESH_ARCHIVE_URL" -o "$archive"
    fi

    local actual_sha
    actual_sha=$(shasum -a 256 "$archive" | awk '{ print $1 }')
    [ "$actual_sha" = "$BLESH_ARCHIVE_SHA256" ] ||
        die "ble.sh checksum mismatch (expected $BLESH_ARCHIVE_SHA256, got $actual_sha)"

    local extracted=$PROJECT_TEMP_DIR/blesh-source
    mkdir -p "$extracted"
    tar -xJf "$archive" -C "$extracted"

    local source_script='' candidate
    for candidate in "$extracted"/*/ble.sh "$extracted"/ble.sh; do
        if [ -f "$candidate" ]; then
            source_script=$candidate
            break
        fi
    done
    [ -n "$source_script" ] || die 'ble.sh archive did not contain ble.sh'

    rm -rf "$PROJECT_DATA_DIR/blesh"
    mkdir -p "$PROJECT_DATA_DIR"
    /bin/bash "$source_script" --install "$PROJECT_DATA_DIR"
    [ -r "$PROJECT_DATA_DIR/blesh/ble.sh" ] || die 'ble.sh installation failed'
    printf '%s\n' "$BLESH_ARCHIVE_NAME" > "$version_file"
}

[ "$(uname -s)" = Darwin ] || die 'this installer supports macOS only'
require_command awk
require_command cat
require_command curl
require_command shasum
require_command tar

case ${SHELL##*/} in
    bash) ;;
    *) warn "your login shell is ${SHELL:-unknown}; these bindings apply only to interactive Bash" ;;
esac

PROJECT_CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/$PROJECT_NAME
PROJECT_DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/$PROJECT_NAME
PROJECT_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/$PROJECT_NAME.XXXXXX")
PROJECT_BACKUP_DIR=$PROJECT_CONFIG_DIR/backups/$(date '+%Y%m%d-%H%M%S')-$$
trap 'rm -rf "$PROJECT_TEMP_DIR"' EXIT HUP INT TERM

PROJECT_SCRIPT_DIR=
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    PROJECT_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fi

mkdir -p "$PROJECT_CONFIG_DIR" "$PROJECT_DATA_DIR"
ghostty_binary=$(find_ghostty_binary || true)
[ -n "$ghostty_binary" ] ||
    die 'Ghostty was not found in PATH, /Applications, or ~/Applications'

install_blesh

bindings_source=$PROJECT_TEMP_DIR/blesh-macos-bindings.bash
download_project_file config/blesh-macos-bindings.bash "$bindings_source"
/bin/bash -n "$bindings_source"

ghostty_fragment_source=$PROJECT_TEMP_DIR/ghostty-macos-keybindings.conf
download_project_file config/ghostty-macos-keybindings.conf "$ghostty_fragment_source"
"$ghostty_binary" +validate-config --config-file="$ghostty_fragment_source" ||
    die 'the bundled Ghostty configuration failed validation'

cp "$bindings_source" "$PROJECT_CONFIG_DIR/blesh-macos-bindings.bash"

bashrc=$HOME/.bashrc
touch "$bashrc"
backup_file "$bashrc" bashrc

quoted_blesh=$(shell_quote "$PROJECT_DATA_DIR/blesh/ble.sh")
quoted_bindings=$(shell_quote "$PROJECT_CONFIG_DIR/blesh-macos-bindings.bash")
bashrc_block=$PROJECT_TEMP_DIR/bashrc-block
cat > "$bashrc_block" <<EOF
$BASHRC_BEGIN
if [[ \$- == *i* ]]; then
    if [[ ! \${BLE_VERSION-} && -r $quoted_blesh ]]; then
        source -- $quoted_blesh --attach=none
    fi
    if [[ \${BLE_VERSION-} && -r $quoted_bindings ]]; then
        source -- $quoted_bindings
    fi
fi
$BASHRC_END
EOF
prepend_managed_block "$bashrc" "$BASHRC_BEGIN" "$BASHRC_END" "$bashrc_block"

attach_block=$PROJECT_TEMP_DIR/attach-block
cat > "$attach_block" <<EOF
$BASHRC_ATTACH_BEGIN
[[ ! \${BLE_VERSION-} ]] || ble-attach
$BASHRC_ATTACH_END
EOF
append_managed_block "$bashrc" "$BASHRC_ATTACH_BEGIN" "$BASHRC_ATTACH_END" "$attach_block"

login_file=
for candidate in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
    if [ -f "$candidate" ]; then
        login_file=$candidate
        break
    fi
done
if [ -z "$login_file" ]; then
    login_file=$HOME/.bash_profile
    touch "$login_file"
fi

if ! grep -Eq '(^|[;&|()[:space:]])(source|\.)[[:space:]]+.*\.bashrc' "$login_file"; then
    backup_file "$login_file" "$(basename "$login_file")"
    quoted_bashrc=$(shell_quote "$bashrc")
    login_block=$PROJECT_TEMP_DIR/login-block
    cat > "$login_block" <<EOF
$LOGIN_BEGIN
[[ -r $quoted_bashrc ]] && source -- $quoted_bashrc
$LOGIN_END
EOF
    append_managed_block "$login_file" "$LOGIN_BEGIN" "$LOGIN_END" "$login_block"
fi

ghostty_config=$(find_ghostty_config)
ghostty_directory=$(dirname "$ghostty_config")
ghostty_fragment=$ghostty_directory/ghostty-macos-keybindings.conf
mkdir -p "$ghostty_directory"
touch "$ghostty_config"
backup_file "$ghostty_config" "ghostty-$(basename "$ghostty_config")"

cp "$ghostty_fragment_source" "$ghostty_fragment"
ghostty_block=$PROJECT_TEMP_DIR/ghostty-block
cat > "$ghostty_block" <<EOF
$GHOSTTY_BEGIN
config-file = ghostty-macos-keybindings.conf
$GHOSTTY_END
EOF
append_managed_block "$ghostty_config" "$GHOSTTY_BEGIN" "$GHOSTTY_END" "$ghostty_block"

/bin/bash -n "$bashrc"
if ! "$ghostty_binary" +validate-config; then
    warn "Ghostty reported a configuration error; inspect $ghostty_config"
fi

info 'installation complete'
info "Bash configuration: $bashrc"
info "Ghostty configuration: $ghostty_config"
[ ! -d "$PROJECT_BACKUP_DIR" ] || info "Backups: $PROJECT_BACKUP_DIR"
printf '\nReload Ghostty with Command+Shift+, then run: exec bash -l\n'
