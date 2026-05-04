# ~/.bashrc
# Stub: source the shared config, then add bash-only setup.
# Keep this file thin. Real config lives in ~/dotfiles/shell/shared.sh.

# ----------------------------------------------------------------------------
# Shared config (used by both bash and zsh)
# ----------------------------------------------------------------------------
[ -f "$HOME/dotfiles/shell/shared.sh" ] && . "$HOME/dotfiles/shell/shared.sh"

# ----------------------------------------------------------------------------
# Prompt
# ----------------------------------------------------------------------------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
else
  # Fallback prompt: cyan time, green user, yellow path, magenta git branch.
  # parse_git_branch() is defined in shared.sh.
  PS1='\[\e[36m\]\t \[\e[32m\]\u \[\e[33m\]\w\[\e[35m\]$(parse_git_branch)\[\e[m\]\$ '
fi

# ----------------------------------------------------------------------------
# Local bash-only overrides (per-machine, NOT in this repo)
# ----------------------------------------------------------------------------
[ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"
