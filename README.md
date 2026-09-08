# Fix Ghostty Shift+Arrow Selection in Bash on macOS

[![test](https://github.com/Kntnt/ghostty-macos-keybindings/actions/workflows/test.yml/badge.svg)](https://github.com/Kntnt/ghostty-macos-keybindings/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Make the Ghostty terminal command line behave like a macOS text field when you use Bash. This project fixes the problem where **Shift+Left Arrow prints `D`**, **Shift+Right Arrow prints `C`**, or Shift+Arrow moves the cursor without selecting text. It also adds familiar Command and Option keyboard shortcuts for selecting, copying, cutting, pasting, moving, deleting, undoing, and redoing text.

If you searched for any of the following, this project is intended to solve that problem:

- Ghostty Shift Arrow does not select text
- Ghostty Shift Left prints D or Shift Right prints C
- Bash select text with Shift+Arrow on macOS
- GNU Readline macOS keyboard shortcuts
- Ghostty Command+A, Command+C, Command+X, or Command+Z in Bash
- macOS terminal Option+Arrow or Command+Arrow keybindings
- `\e[1;2D` or `\e[1;2C` appears in a Bash prompt

## Install

Requirements:

- macOS
- [Ghostty](https://ghostty.org/) as the terminal
- Bash as the interactive shell
- `curl`, `tar`, and standard macOS command-line tools

Run the installer:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Kntnt/ghostty-macos-keybindings/main/install.sh)"
```

Then reload Ghostty with <kbd>Command</kbd>+<kbd>Shift</kbd>+<kbd>,</kbd> and restart the current Bash session:

```bash
exec bash -l
```

You can instead inspect the code before running it:

```bash
git clone https://github.com/Kntnt/ghostty-macos-keybindings.git
cd ghostty-macos-keybindings
./install.sh
```

The installer is safe to run again when the project is updated. It replaces its own marked configuration blocks instead of adding duplicates.

## Keyboard shortcuts

| Shortcut | Bash command-line behavior |
| --- | --- |
| <kbd>Shift</kbd>+<kbd>Left/Right</kbd> | Select one character at a time |
| <kbd>Shift</kbd>+<kbd>Up/Down</kbd> | Extend the selection vertically |
| <kbd>Option</kbd>+<kbd>Left/Right</kbd> | Move one word |
| <kbd>Option</kbd>+<kbd>Shift</kbd>+<kbd>Left/Right</kbd> | Select one word at a time |
| <kbd>Command</kbd>+<kbd>Left/Right</kbd> | Move to the beginning/end of the line |
| <kbd>Command</kbd>+<kbd>Shift</kbd>+<kbd>Left/Right</kbd> | Select to the beginning/end of the line |
| <kbd>Option</kbd>+<kbd>Up/Down</kbd> | Move to the beginning/end of the logical line |
| <kbd>Option</kbd>+<kbd>Shift</kbd>+<kbd>Up/Down</kbd> | Select to the beginning/end of the logical line |
| <kbd>Command</kbd>+<kbd>Up/Down</kbd> | Move to the beginning/end of a multiline command |
| <kbd>Command</kbd>+<kbd>Shift</kbd>+<kbd>Up/Down</kbd> | Select to the beginning/end of a multiline command |
| <kbd>Command</kbd>+<kbd>A</kbd> | Select the complete current command |
| <kbd>Command</kbd>+<kbd>C</kbd> | Copy selected command text to the macOS clipboard |
| <kbd>Command</kbd>+<kbd>X</kbd> | Cut selected command text to the macOS clipboard |
| <kbd>Command</kbd>+<kbd>V</kbd> | Paste, replacing selected command text |
| <kbd>Command</kbd>+<kbd>Z</kbd> | Undo |
| <kbd>Command</kbd>+<kbd>Shift</kbd>+<kbd>Z</kbd> | Redo |
| <kbd>Option</kbd>+<kbd>Backspace/Delete</kbd> | Delete the previous/next word |
| <kbd>Command</kbd>+<kbd>Backspace/Delete</kbd> | Delete to the beginning/end of the line |

Normal Readline bindings such as <kbd>Control</kbd>+<kbd>A</kbd>, <kbd>Control</kbd>+<kbd>E</kbd>, <kbd>Control</kbd>+<kbd>R</kbd>, and history navigation continue to work. When Ghostty has a native mouse selection, <kbd>Command</kbd>+<kbd>C</kbd> copies that selection. Otherwise, it copies the selection in the current Bash command. <kbd>Control</kbd>+<kbd>C</kbd> still interrupts the foreground command.

## Why Ghostty prints C or D instead of selecting text

Ghostty encodes modified cursor keys as terminal escape sequences. Shift+Left commonly reaches Bash as `ESC [ 1 ; 2 D`, while Shift+Right arrives as `ESC [ 1 ; 2 C`.

GNU Readline, Bash's usual command-line editor, does not provide a complete selection-aware widget for these sequences. With no suitable binding, part of the escape sequence may be consumed while its final `D` or `C` is inserted as ordinary text. Simple `.inputrc` macros can move the cursor and set a mark, but repeated Shift+Arrow presses tend to reset the selection anchor. That does not behave like selection in a normal macOS text field.

This project uses [ble.sh](https://github.com/akinomyoga/ble.sh), a Bash line editor with a real selection state. A small Ghostty configuration fragment lets the relevant Command shortcuts reach ble.sh. The included ble.sh profile disables syntax highlighting, automatic suggestions, completion menus, completion candidate coloring, and status decorations so the result remains close to normal GNU Readline.

## What the installer changes

The installer:

1. Downloads a pinned ble.sh build from the official project and verifies its SHA-256 checksum.
2. Installs it under `~/.local/share/ghostty-macos-keybindings/` (or `$XDG_DATA_HOME`).
3. Installs the macOS editing bindings under `~/.config/ghostty-macos-keybindings/` (or `$XDG_CONFIG_HOME`).
4. Adds clearly marked loading blocks to `~/.bashrc`.
5. Ensures the active Bash login file loads `~/.bashrc` when needed.
6. Adds a `config-file` include to the active Ghostty configuration.
7. Saves the original files under `~/.config/ghostty-macos-keybindings/backups/` before changing them.

The ble.sh source code is not copied into this repository. It remains a separately maintained dependency downloaded from its official release.

## Troubleshooting

### The shortcuts still do not work

Confirm that the current shell is Bash:

```bash
printf '%s\n' "$BASH_VERSION"
```

An empty result means you are probably using zsh, fish, or another shell. This project configures Bash only.

Reload Ghostty and Bash after installation:

```bash
exec bash -l
```

You can validate the active Ghostty configuration with:

```bash
/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config
```

### Command+C does not interrupt a process

That is intentional macOS behavior: <kbd>Command</kbd>+<kbd>C</kbd> copies text. Use <kbd>Control</kbd>+<kbd>C</kbd> to interrupt a running command.

### I use zsh or fish

zsh uses ZLE and fish has its own line editor, so neither uses GNU Readline or these ble.sh bindings. Their keymaps require a different solution.

### I use tmux or SSH

Shift+Arrow uses broadly supported terminal sequences. Command shortcuts require the modified-key protocol to pass through every layer between Ghostty and Bash. Older multiplexers and remote terminal configurations may filter those keys.

## Uninstall

From a clone of the repository:

```bash
./uninstall.sh
```

Or run the standalone uninstaller:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Kntnt/ghostty-macos-keybindings/main/uninstall.sh)"
```

The uninstaller removes only this project's marked blocks, configuration fragment, and private ble.sh installation. Backups are retained.

## License

MIT. See [LICENSE](LICENSE).

ble.sh is a separate project with its own license and copyright holders. Ghostty is a separate project and is not affiliated with this repository.
