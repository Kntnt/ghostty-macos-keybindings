# macOS-style command-line editing for Bash in Ghostty.
# This file is sourced after ble.sh and before ble-attach.
# shellcheck disable=SC2154  # ble.sh owns the _ble_* editor state variables.

# Keep the editor close to GNU Readline: no syntax highlighting, automatic
# suggestions, completion menus, or prompt/status decorations.
ble-import -d config/readline

function ble/widget/ghostty-macos/select-all {
    local length=${#_ble_edit_str}
    ((length)) || { ble/widget/.bell 'empty command line'; return 1; }

    _ble_edit_mark=0
    _ble_edit_ind=$length
    _ble_edit_mark_active=S
    [[ $_ble_decode_keymap == selection ]] || ble/decode/keymap/push selection
}

function ble/widget/ghostty-macos/copy {
    if [[ ! $_ble_edit_mark_active || $_ble_edit_mark == "$_ble_edit_ind" ]]; then
        ble/widget/.bell 'no selection'
        return 1
    fi

    local begin=$_ble_edit_mark end=$_ble_edit_ind swap
    if ((begin > end)); then
        swap=$begin begin=$end end=$swap
    fi
    printf '%s' "${_ble_edit_str:begin:end-begin}" | /usr/bin/pbcopy
}

function ble/widget/ghostty-macos/cut {
    ble/widget/ghostty-macos/copy || return
    [[ $_ble_decode_keymap == selection ]] && ble/decode/keymap/pop
    ble/widget/delete-region
}

function ble/widget/ghostty-macos/bracketed-paste {
    [[ $_ble_decode_keymap == selection ]] && ble/decode/keymap/pop
    [[ $_ble_edit_mark_active ]] && ble/widget/delete-region
    ble/widget/emacs/bracketed-paste
}

function ble/ghostty-macos/emacs-load-hook {
    # Command: select all, clipboard, undo, and input-wide movement.
    ble-bind -m emacs -f 's-a' ghostty-macos/select-all
    ble-bind -m emacs -f 's-c' ghostty-macos/copy
    ble-bind -m emacs -f 's-x' ghostty-macos/cut
    ble-bind -m emacs -f 's-z' emacs/undo
    ble-bind -m emacs -f 's-S-z' emacs/redo
    ble-bind -m emacs -f 's-up' beginning-of-text
    ble-bind -m emacs -f 's-down' end-of-text
    ble-bind -m emacs -f 's-S-up' '@marked beginning-of-text'
    ble-bind -m emacs -f 's-S-down' '@marked end-of-text'
    ble-bind -m emacs -f 's-S-left' '@marked beginning-of-line'
    ble-bind -m emacs -f 's-S-right' '@marked end-of-line'

    # Option: move, select, or delete by word/line as in macOS text fields.
    ble-bind -m emacs -f 'M-S-left' '@marked backward-cword'
    ble-bind -m emacs -f 'M-S-right' '@marked forward-cword'
    ble-bind -m emacs -f 'M-up' beginning-of-line
    ble-bind -m emacs -f 'M-down' end-of-line
    ble-bind -m emacs -f 'M-S-up' '@marked beginning-of-line'
    ble-bind -m emacs -f 'M-S-down' '@marked end-of-line'
    ble-bind -m emacs -f 'M-C-?' 'kill-region-or kill-backward-cword'
    ble-bind -m emacs -f 'M-DEL' 'kill-region-or kill-backward-cword'
    ble-bind -m emacs -f 'M-BS' 'kill-region-or kill-backward-cword'
    ble-bind -m emacs -f 'M-delete' 'kill-region-or kill-forward-cword'

    # Command-Backspace/Delete remove to the corresponding end of the line.
    ble-bind -m emacs -f 's-C-?' 'kill-region-or kill-backward-line'
    ble-bind -m emacs -f 's-DEL' 'kill-region-or kill-backward-line'
    ble-bind -m emacs -f 's-BS' 'kill-region-or kill-backward-line'
    ble-bind -m emacs -f 's-delete' 'kill-region-or kill-forward-line'

    # Pasting over a marked range should replace it, as in a macOS text field.
    ble-bind -m emacs -f paste_begin ghostty-macos/bracketed-paste

    # Keep extending an existing selection instead of choosing a new anchor.
    ble-bind -m selection -f 's-a' ghostty-macos/select-all
    ble-bind -m selection -f 's-c' ghostty-macos/copy
    ble-bind -m selection -f 's-x' ghostty-macos/cut
    ble-bind -m selection -f 's-S-up' beginning-of-text
    ble-bind -m selection -f 's-S-down' end-of-text
    ble-bind -m selection -f 's-S-left' beginning-of-line
    ble-bind -m selection -f 's-S-right' end-of-line
    ble-bind -m selection -f 'M-S-left' backward-cword
    ble-bind -m selection -f 'M-S-right' forward-cword
    ble-bind -m selection -f 'M-S-up' beginning-of-line
    ble-bind -m selection -f 'M-S-down' end-of-line
    ble-bind -m selection -f paste_begin ghostty-macos/bracketed-paste
}
blehook/eval-after-load keymap_emacs ble/ghostty-macos/emacs-load-hook
