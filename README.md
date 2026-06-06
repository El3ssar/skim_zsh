# skim-zsh

Fast file & content search for the Zsh command line, built on the Rust
toolchain — [`skim`](https://github.com/skim-rs/skim) (`sk`),
[`ripgrep`](https://github.com/BurntSushi/ripgrep) (`rg`) and
[`bat`](https://github.com/sharkdp/bat) — the speedy replacements for
`fzf` / `grep` / `cat`.

| Key | What it does |
| --- | --- |
| <kbd>Ctrl</kbd>+<kbd>F</kbd> | Fuzzy-find files **by name** in the current directory, with a `bat` preview in the right pane. |
| <kbd>Alt</kbd>+<kbd>S</kbd> | Live-grep file **contents** in the current directory; the preview shows the matching regions of the file with the matched lines highlighted. |

On <kbd>Enter</kbd>, the selected path(s) are inserted (shell-quoted) at the
cursor, so you can drop them straight into `nvim`, `cat`, `cp`, a pipeline, etc.
Use <kbd>Tab</kbd> to select several.

## How the content preview works (Alt+S)

For the highlighted file, every match of your query gets **5 lines of context**
above and below it (configurable). When several matches sit close together
their context windows are **merged** into a single block spanning *5 lines
before the first match* to *5 lines after the last*. Matches that are far apart
are shown as separate blocks, divided by `bat`'s snip separator (`✂`). Every
matching line is highlighted.

```
  1   import os
  …   (match lines highlighted, context around them)
  9   def load(...):
 ────────────── 8< ──────────────
 35   # ... another region further down the file ...
 46   return result
```

## Requirements

All three are available via `cargo install` or your package manager:

- `sk`  — skim   (`cargo install skim`)
- `rg`  — ripgrep (`cargo install ripgrep`)
- `bat` — bat     (`cargo install bat`)
- *(optional)* `rga` — [ripgrep-all](https://github.com/phiresky/ripgrep-all),
  if you want content search to look inside PDFs / office docs (see
  [Configuration](#configuration); previews of converted formats are
  best-effort).

## Install

### With [antidote](https://antidote.sh) (recommended)

Add the plugin to your bundle file (`${ZDOTDIR:-$HOME}/.zsh_plugins.txt`):

```zsh
# from GitHub
El3ssar/skim-zsh
```

…or point at a local clone (handy while developing) — antidote accepts an
absolute path as a bundle:

```zsh
# in .zsh_plugins.txt
/home/elessar/Projects/skim_zsh
```

Then load it from your `.zshrc` as usual:

```zsh
source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh
antidote load
```

Or bundle a single path dynamically:

```zsh
antidote bundle /home/elessar/Projects/skim_zsh
```

### Manual

```zsh
git clone https://github.com/El3ssar/skim-zsh ~/.zsh/skim-zsh
echo 'source ~/.zsh/skim-zsh/skim-zsh.plugin.zsh' >> ~/.zshrc
```

## Keys inside skim

| Key | Action |
| --- | --- |
| <kbd>Tab</kbd> / <kbd>Shift</kbd>+<kbd>Tab</kbd> | Select / deselect (multi-select) |
| <kbd>Enter</kbd> | Accept and insert the selection |
| <kbd>Shift</kbd>+<kbd>↑</kbd> / <kbd>↓</kbd> | Scroll the preview one line |
| <kbd>Alt</kbd>+<kbd>↑</kbd> / <kbd>↓</kbd> | Scroll the preview one page |
| <kbd>Alt</kbd>+<kbd>W</kbd> | Toggle line wrap in the preview |
| <kbd>Esc</kbd> / <kbd>Ctrl</kbd>+<kbd>C</kbd> | Cancel |

For content search, the top prompt (`content>`) drives `ripgrep`; whatever you
type is the search pattern (smart-case, regex).

## Configuration

Set any of these in `.zshrc` **before** the keys are used (they are read live on
every invocation, so you can change them at any time):

| Variable | Default | Description |
| --- | --- | --- |
| `SKIM_ZSH_FILE_KEY` | `^F` | Keybinding for file search. |
| `SKIM_ZSH_CONTENT_KEY` | `^[s` (Alt+S) | Keybinding for content search. |
| `SKIM_ZSH_RG` | `rg` | ripgrep binary — set to `rga` to search inside documents. |
| `SKIM_ZSH_BAT` | `bat` | bat binary (some distros ship it as `batcat`). |
| `SKIM_ZSH_CONTEXT` | `5` | Context lines shown around each match in the content preview. |
| `SKIM_ZSH_PREVIEW_WINDOW` | `right:60%:wrap` | skim `--preview-window` spec. |
| `SKIM_ZSH_FILE_CMD` | `rg --files --hidden --glob '!**/.git/**'` | Command that lists files for Ctrl+F. |
| `SKIM_ZSH_GREP_TEMPLATE` | `rg --files-with-matches --hidden --smart-case --glob '!**/.git/**' --color=never -e {}` | Interactive grep command for Alt+S; `{}` is replaced by the query. |

### Examples

```zsh
# Wider context, bigger preview pane
SKIM_ZSH_CONTEXT=8
SKIM_ZSH_PREVIEW_WINDOW='right:70%:wrap'

# On Debian/Ubuntu where bat is installed as batcat
SKIM_ZSH_BAT=batcat

# Rebind to Ctrl+P (files) and Ctrl+G (content)
SKIM_ZSH_FILE_KEY='^P'
SKIM_ZSH_CONTENT_KEY='^G'

# Search inside PDFs / docx with ripgrep-all
SKIM_ZSH_RG=rga
```

## Notes

- <kbd>Ctrl</kbd>+<kbd>F</kbd> normally runs `forward-char`; this plugin
  rebinds it. Pick a different `SKIM_ZSH_FILE_KEY` if you rely on that.
- Both widgets operate on the **current directory** (`rg` respects
  `.gitignore`; the defaults add `--hidden` and exclude `.git/`).
- Content search lists files **containing** a match and previews the matched
  regions. The match pattern (top `content>` prompt) is a ripgrep regex with
  smart-case; you can additionally fuzzy-filter the file list from the
  `filter>` prompt.
- Filenames containing `:` are not special-cased in the preview's match
  parsing (an extremely rare edge case).

## License

MIT
