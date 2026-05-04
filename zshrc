# ~/.zshrc
# Stub: source the shared config, then add zsh-only setup.
# Keep this file thin. Real config lives in ~/dotfiles/shell/shared.sh.

# ----------------------------------------------------------------------------
# Shared config (used by both bash and zsh)
# ----------------------------------------------------------------------------
[ -f "$HOME/dotfiles/shell/shared.sh" ] && . "$HOME/dotfiles/shell/shared.sh"

# ----------------------------------------------------------------------------
# Oh My Zsh
# ----------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
# Theme is intentionally blank because Starship handles the prompt below.
# If Starship isn't installed, robbyrussell will be used as a fallback.
ZSH_THEME=""
plugins=(git)
[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# ----------------------------------------------------------------------------
# Prompt
# ----------------------------------------------------------------------------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  # Fallback: use Oh My Zsh's robbyrussell
  ZSH_THEME="robbyrussell"
fi

# Suppress zsh's "missing trailing newline" indicator (the inverse-video %
# that appears after `cat`ing a file without a final \n, common with JSON).
PROMPT_EOL_MARK=''

# ----------------------------------------------------------------------------
# Local zsh-only overrides (per-machine, NOT in this repo)
# ----------------------------------------------------------------------------
[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"
