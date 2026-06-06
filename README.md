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

For content search, the top prompt (`content (≥3)>`) drives `ripgrep`; whatever
you type is the search pattern (smart-case, regex). Ripgrep isn't launched until
the query reaches `SKIM_ZSH_MIN_QUERY` characters (default 3) — see
[Performance in large directories](#performance-in-large-directories).

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
| `SKIM_ZSH_MIN_QUERY` | `3` | Minimum query length before Alt+S runs ripgrep. Prevents full-tree scans — and the lag / disk thrashing they cause — on empty or 1–2 character queries in huge directories. See [Performance in large directories](#performance-in-large-directories). |
| `SKIM_ZSH_MAX_RESULTS` | `500` | Cap on files listed per Alt+S scan; ripgrep is piped through `head` and quits early once reached, so a common word can't enumerate the whole tree. `0` disables. |
| `SKIM_ZSH_TIMEOUT` | `5` | Wall-clock seconds each Alt+S scan may run, via `timeout` / `gtimeout` (if installed). Stops slow scans from piling up across keystrokes and churning while idle. `0` disables. |
| `SKIM_ZSH_PREVIEW_WINDOW` | `right:60%:wrap` | skim `--preview-window` spec. |
| `SKIM_ZSH_FILE_CMD` | `rg --files --hidden --glob '!**/.git/**'` | Command that lists files for Ctrl+F. |
| `SKIM_ZSH_GREP_CMD` | `rg --files-with-matches --hidden --smart-case --no-messages --glob '!**/.git/**' --color=never` | ripgrep invocation for Alt+S, **without** the pattern. The query is appended as `-e <query>` at run time — but only once it reaches `SKIM_ZSH_MIN_QUERY` characters. |

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

## Performance in large directories

`Alt+S` runs ripgrep **live, on every keystroke**. In a directory that isn't
covered by a `.gitignore` — your `$HOME`, for instance — a 1- or 2-character
query matches almost everything, so each keystroke kicks off a scan of the
*entire* tree — and because skim fires one scan per keystroke, those scans pile
up and keep churning long after you stop typing. That is what makes content
search feel slow and thrash the disk. Four caps keep it fast — the first bounds
*how often* a scan starts, the rest bound *how expensive* each one is:

- **Minimum query length.** Ripgrep is not launched until the query reaches
  `SKIM_ZSH_MIN_QUERY` characters (default **3**); empty and 1–2 character
  queries do no work at all. Raise it in very large trees:

  ```zsh
  SKIM_ZSH_MIN_QUERY=4
  ```

- **Result cap** (`SKIM_ZSH_MAX_RESULTS`, default **500**). The result list is
  piped through `head`, so ripgrep takes a `SIGPIPE` and stops as soon as that
  many files match. A common word like `the` would otherwise enumerate the whole
  tree — tens of thousands of files, several seconds of disk thrash — on every
  keystroke; with the cap it returns near-instantly. Refine with the `content>`
  and `filter>` prompts rather than scrolling thousands of rows.

- **Per-scan timeout** (`SKIM_ZSH_TIMEOUT`, default **5** seconds). Each scan is
  wrapped in `timeout` (or `gtimeout` on macOS / Homebrew, when present), so a
  slow walk over a giant tree is killed instead of piling up across keystrokes —
  this is what stops the "leave it a while and it keeps lagging" behaviour. Rare
  or no-match queries, which have to walk the whole tree, are caught here. Set
  either cap to `0` to disable it.

- **Ignore files.** Ripgrep honours `.gitignore`, `.ignore` and `.rgignore`
  from the current directory upward. Outside a git repo, drop a `~/.ignore`
  listing the big, uninteresting trees so they stay out of every search:

  ```
  # ~/.ignore — skipped everywhere ripgrep runs
  node_modules/
  .cache/
  .local/
  .cargo/
  *.iso
  ```

`Ctrl+F` (file-name search) lists files once and filters them in memory, so it
stays responsive regardless of directory size — these notes are about `Alt+S`.

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
