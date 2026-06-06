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
#   SKIM_ZSH_PREVIEW_WINDOW skim --preview-window spec   (default: 'right:60%:wrap')
#   SKIM_ZSH_FILE_CMD       command that lists files     (default: rg --files ...)
#   SKIM_ZSH_GREP_TEMPLATE  interactive grep cmd, {}=query(default: rg -l ...)
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
: ${SKIM_ZSH_RG:=rg}
: ${SKIM_ZSH_BAT:=bat}
: ${SKIM_ZSH_CONTEXT:=5}
: ${SKIM_ZSH_FILE_KEY:='^F'}
: ${SKIM_ZSH_CONTENT_KEY:='^[s'}
: ${SKIM_ZSH_PREVIEW_WINDOW:='right:60%:wrap'}
: ${SKIM_ZSH_FILE_CMD:="$SKIM_ZSH_RG --files --hidden --glob '!**/.git/**'"}
: ${SKIM_ZSH_GREP_TEMPLATE:="$SKIM_ZSH_RG --files-with-matches --hidden --smart-case --glob '!**/.git/**' --color=never -e {}"}

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

  local out
  out=$(
    SKIM_ZSH_BAT="$SKIM_ZSH_BAT" \
    SKIM_ZSH_RG="$SKIM_ZSH_RG" \
    SKIM_ZSH_CONTEXT="$SKIM_ZSH_CONTEXT" \
    sk \
      --interactive \
      --cmd="$SKIM_ZSH_GREP_TEMPLATE" \
      --cmd-prompt='content> ' \
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
