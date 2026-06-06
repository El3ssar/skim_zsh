#                  _    _
#   ___ _ __ ___  (_)  / |   ___ ___  ___  ___  ___
#  (_-/| / // // |/ /  | |  / -_| -_)/ -_)/ _ \/ -_)
#  /__/|_\\_,_/|_/_/   |_|  \___|___|\___|\_, /\___|
#                                        /___/
# skim-zsh — fast file & content search for the command line.
#
#   Ctrl+F : fuzzy-find files by *name* in $PWD, preview with bat.
#   Alt+S  : live-grep file *contents* in $PWD, preview the matching
#            regions with bat (context + highlighted match lines).
#
# Built on skim (sk) + ripgrep (rg) + bat — the fast Rust replacements for
# fzf / grep / cat. On selection, the chosen path(s) are inserted (quoted)
# at the cursor so you can pipe them into $EDITOR, cat, etc.
#
# Configuration — set any of these before first use (e.g. in .zshrc, *before*
# the keys are pressed; they are read live on every invocation):
#
#   SKIM_ZSH_FILE_KEY       key for file search          (default: '^F'   = Ctrl+F)
#   SKIM_ZSH_CONTENT_KEY    key for content search       (default: '^[s'  = Alt+S)
#   SKIM_ZSH_RG             ripgrep binary               (default: 'rg', try 'rga')
#   SKIM_ZSH_BAT            bat binary                   (default: 'bat')
#   SKIM_ZSH_CONTEXT        context lines around matches (default: 5)
#   SKIM_ZSH_MIN_QUERY      min chars before Alt+S greps (default: 3)
#   SKIM_ZSH_MAX_RESULTS    cap on Alt+S result files    (default: 500, 0=off)
#   SKIM_ZSH_TIMEOUT        wall-clock cap per scan (s)  (default: 5, 0=off)
#   SKIM_ZSH_PREVIEW_WINDOW skim --preview-window spec   (default: 'right:60%:wrap')
#   SKIM_ZSH_FILE_CMD       command that lists files     (default: rg --files ...)
#   SKIM_ZSH_GREP_CMD       Alt+S grep cmd (no pattern)  (default: rg -l ...)
#
# Inside skim:
#   Tab / Shift-Tab  select multiple        Enter   accept
#   Shift-Up/Down    scroll preview a line  Alt-Up/Down  scroll preview a page
#   Alt-W            toggle preview wrap    Esc / Ctrl-C cancel

# --- resolve this file's own directory (Zsh Plugin Standard idiom) ----------
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"
typeset -g SKIM_ZSH_DIR="${0:A:h}"
typeset -g SKIM_ZSH_PREVIEW_HELPER="$SKIM_ZSH_DIR/bin/skim-zsh-content-preview"

# --- defaults (only set if the user hasn't already) -------------------------
# Use `typeset -g` rather than `: ${VAR:=default}` so that loaders which source
# this file from inside a function (e.g. antidote's `antidote-load`) do not emit
# "scalar parameter created globally" warnings under `setopt warn_create_global`.
# The `${VAR:-default}` form still honours any value the user set beforehand.
typeset -g SKIM_ZSH_RG="${SKIM_ZSH_RG:-rg}"
typeset -g SKIM_ZSH_BAT="${SKIM_ZSH_BAT:-bat}"
typeset -g SKIM_ZSH_CONTEXT="${SKIM_ZSH_CONTEXT:-5}"
# Don't run the live content search until the query is at least this many
# characters. Protects against full-tree scans on empty / 1–2 char queries,
# which is what makes Alt+S slow in huge directories like $HOME.
typeset -g SKIM_ZSH_MIN_QUERY="${SKIM_ZSH_MIN_QUERY:-3}"
# Stop each live scan after this many matching files: the result list is piped
# through `head`, so ripgrep takes a SIGPIPE and quits early. A fuzzy list never
# needs thousands of rows, and this is what stops a common word like "the" from
# enumerating the *entire* tree (11k+ files, seconds of disk thrash) on every
# keystroke. 0 disables the cap.
typeset -g SKIM_ZSH_MAX_RESULTS="${SKIM_ZSH_MAX_RESULTS:-500}"
# Hard wall-clock cap (seconds) on each live scan, applied with coreutils
# `timeout` (or `gtimeout` on macOS/Homebrew) when available. Stops a slow scan
# over a huge tree from piling up across keystrokes and churning after you have
# stopped typing — the "leave it a while and it lags" case. 0 disables.
typeset -g SKIM_ZSH_TIMEOUT="${SKIM_ZSH_TIMEOUT:-5}"
typeset -g SKIM_ZSH_FILE_KEY="${SKIM_ZSH_FILE_KEY:-^F}"
typeset -g SKIM_ZSH_CONTENT_KEY="${SKIM_ZSH_CONTENT_KEY:-^[s}"
typeset -g SKIM_ZSH_PREVIEW_WINDOW="${SKIM_ZSH_PREVIEW_WINDOW:-right:60%:wrap}"
typeset -g SKIM_ZSH_FILE_CMD="${SKIM_ZSH_FILE_CMD:-$SKIM_ZSH_RG --files -uuu --glob '!**/.git/**'}"
# Content search: the ripgrep invocation WITHOUT the pattern. The query is
# appended as `-e <query>` at run time (only once it reaches SKIM_ZSH_MIN_QUERY
# characters). `--no-messages` keeps unreadable-file errors out of the list.
typeset -g SKIM_ZSH_GREP_CMD="${SKIM_ZSH_GREP_CMD:-$SKIM_ZSH_RG --files-with-matches --hidden --no-ignore --smart-case --no-messages --glob '!**/.git/**' --color=never}"

# Shared skim key bindings for the preview pane.
typeset -g _SKIM_ZSH_BINDS='shift-up:preview-up,shift-down:preview-down,alt-up:preview-page-up,alt-down:preview-page-down,alt-w:toggle-preview-wrap'

# Verify the toolchain; emit a friendly message into the ZLE area if missing.
_skim-zsh-check-tools() {
  emulate -L zsh
  local -a missing
  command -v sk >/dev/null 2>&1                 || missing+=('sk (skim)')
  command -v "${SKIM_ZSH_RG%% *}" >/dev/null 2>&1 || missing+=("${SKIM_ZSH_RG%% *} (ripgrep)")
  command -v "${SKIM_ZSH_BAT%% *}" >/dev/null 2>&1 || missing+=("${SKIM_ZSH_BAT%% *} (bat)")
  if (( ${#missing} )); then
    zle -M "skim-zsh: missing dependencies: ${(j:, :)missing}"
    return 1
  fi
  return 0
}

# --- Ctrl+F : find files by name -------------------------------------------
skim-zsh-file-widget() {
  emulate -L zsh
  setopt local_options no_aliases pipe_fail
  _skim-zsh-check-tools || { zle reset-prompt; return 1; }

  local preview="$SKIM_ZSH_BAT --color=always --decorations=always --style=numbers -- {}"

  local out
  out=$(
    eval "$SKIM_ZSH_FILE_CMD" 2>/dev/null | sk \
      --multi \
      --reverse \
      --prompt='files> ' \
      --preview="$preview" \
      --preview-window="$SKIM_ZSH_PREVIEW_WINDOW" \
      --bind="$_SKIM_ZSH_BINDS"
  )

  if [[ -n $out ]]; then
    local -a picks quoted
    picks=("${(@f)out}")
    quoted=("${(@q)picks}")
    LBUFFER+="${(j: :)quoted} "
  fi
  zle reset-prompt
}

# --- Alt+S : live-grep file contents ---------------------------------------
skim-zsh-content-widget() {
  emulate -L zsh
  setopt local_options no_aliases pipe_fail
  _skim-zsh-check-tools || { zle reset-prompt; return 1; }

  # Helper path is single-quoted so a plugin dir containing spaces still works.
  local preview="'${SKIM_ZSH_PREVIEW_HELPER}' {} {cq}"

  # Length-gate the live search: ripgrep only runs once the query reaches
  # SKIM_ZSH_MIN_QUERY characters. Empty / 1–2 char queries otherwise match
  # almost everything, so skim re-scans the whole tree on every keystroke —
  # exactly what makes Alt+S crawl and thrash the disk in huge dirs like $HOME.
  # `{}` is skim's command-query placeholder; it is substituted as a quoted
  # string, so the `case` word is always one safe token (handles spaces, etc.).
  # `_q_glob` is one '?' per required character (e.g. '???' for the default 3),
  # so `case <query> in ???*)` only runs ripgrep when the query is long enough.
  local _q_glob="${(l:SKIM_ZSH_MIN_QUERY::?:)}"

  # A real query still scans a huge tree, and skim fires one scan per keystroke,
  # so two more caps keep each one cheap and stop them piling up:
  #   * `timeout` bounds wall-clock time (no runaway / idle churn / accumulation)
  #   * `| head -n N` bounds output — ripgrep gets SIGPIPE and quits as soon as
  #     SKIM_ZSH_MAX_RESULTS files match, so frequent words don't walk the whole
  #     tree. Rare / no-match queries (which must walk it all) are caught by the
  #     timeout instead.
  local _rg="$SKIM_ZSH_GREP_CMD"
  if (( SKIM_ZSH_TIMEOUT > 0 )); then
    if (( $+commands[timeout] )); then
      _rg="timeout ${SKIM_ZSH_TIMEOUT} $_rg"
    elif (( $+commands[gtimeout] )); then
      _rg="gtimeout ${SKIM_ZSH_TIMEOUT} $_rg"
    fi
  fi
  local _cap=''
  (( SKIM_ZSH_MAX_RESULTS > 0 )) && _cap=" | head -n ${SKIM_ZSH_MAX_RESULTS}"
  local gated_cmd="case {} in ${_q_glob}*) ${_rg} -e {} 2>/dev/null${_cap} ;; esac"

  local out
  out=$(
    SKIM_ZSH_BAT="$SKIM_ZSH_BAT" \
    SKIM_ZSH_RG="$SKIM_ZSH_RG" \
    SKIM_ZSH_CONTEXT="$SKIM_ZSH_CONTEXT" \
    sk \
      --interactive \
      --cmd="$gated_cmd" \
      --cmd-prompt="content (≥${SKIM_ZSH_MIN_QUERY})> " \
      --prompt='filter> ' \
      --multi \
      --reverse \
      --preview="$preview" \
      --preview-window="$SKIM_ZSH_PREVIEW_WINDOW" \
      --bind="$_SKIM_ZSH_BINDS"
  )

  if [[ -n $out ]]; then
    local -a picks quoted
    picks=("${(@f)out}")
    quoted=("${(@q)picks}")
    LBUFFER+="${(j: :)quoted} "
  fi
  zle reset-prompt
}

# --- register widgets & bind keys (interactive shells only) -----------------
if [[ -o interactive ]]; then
  zle -N skim-zsh-file-widget
  zle -N skim-zsh-content-widget
  bindkey "$SKIM_ZSH_FILE_KEY" skim-zsh-file-widget
  bindkey "$SKIM_ZSH_CONTENT_KEY" skim-zsh-content-widget
fi
