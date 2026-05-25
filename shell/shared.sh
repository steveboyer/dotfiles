# shellcheck shell=sh
# ~/dotfiles/shell/shared.sh
#
# Shell config shared between bash and zsh, on both macOS and Linux.
# Keep this POSIX-compatible: no zsh-only or bash-only constructs.
# Anything shell-specific belongs in the per-shell stub (zshrc / bashrc).
# Anything machine-specific belongs in ~/.shellrc.local (NOT in this repo).

# ----------------------------------------------------------------------------
# Platform detection
# ----------------------------------------------------------------------------
case "$(uname -s)" in
  Darwin) export PLATFORM="mac" ;;
  Linux)  export PLATFORM="linux" ;;
  *)      export PLATFORM="unknown" ;;
esac

# ----------------------------------------------------------------------------
# PATH
# ----------------------------------------------------------------------------
# Prepend a directory to PATH only if it exists and isn't already on PATH.
prepend_path() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
  esac
  [ -d "$1" ] && PATH="$1:$PATH"
}

# Personal bin directories (highest priority)
prepend_path "$HOME/bin"
prepend_path "$HOME/.local/bin"

# Homebrew
if [ "$PLATFORM" = "mac" ]; then
  prepend_path "/opt/homebrew/bin"
  prepend_path "/opt/homebrew/sbin"
  prepend_path "/usr/local/bin"

  # Prefer GNU coreutils on Mac so scripts behave the same as on Linux.
  # Install once with: brew install coreutils gnu-sed findutils gawk
  prepend_path "/opt/homebrew/opt/coreutils/libexec/gnubin"
  prepend_path "/opt/homebrew/opt/gnu-sed/libexec/gnubin"
  prepend_path "/opt/homebrew/opt/findutils/libexec/gnubin"
  prepend_path "/opt/homebrew/opt/gawk/libexec/gnubin"
elif [ "$PLATFORM" = "linux" ]; then
  prepend_path "/home/linuxbrew/.linuxbrew/bin"
  prepend_path "/home/linuxbrew/.linuxbrew/sbin"
fi

# Maven (any version, no hardcoded version number)
for _maven_dir in "$HOME"/apache-maven-*; do
  if [ -d "$_maven_dir/bin" ]; then
    export M2_HOME="$_maven_dir"
    prepend_path "$M2_HOME/bin"
    break
  fi
done
unset _maven_dir

# Mac-only extras
if [ "$PLATFORM" = "mac" ]; then
  prepend_path "/Library/TeX/texbin"
  prepend_path "/Applications/iTerm.app/Contents/Resources/utilities"
  prepend_path "/Library/Frameworks/Mono.framework/Versions/Current/Commands"
  prepend_path "/opt/X11/bin"
fi

export PATH

# ----------------------------------------------------------------------------
# Environment
# ----------------------------------------------------------------------------
if command -v nvim >/dev/null 2>&1; then
  export EDITOR="nvim"
else
  export EDITOR="vim"
fi
# Fall back to vim over SSH for compatibility
if [ -n "$SSH_CONNECTION" ]; then
  export EDITOR="vim"
fi
export VISUAL="$EDITOR"

# ----------------------------------------------------------------------------
# Aliases
# ----------------------------------------------------------------------------
# Shell management
alias e='exit'
alias src='exec $SHELL -l'   # cleanly re-exec the login shell instead of `source ~/.zshrc`

# Editing
alias v='nvim'
alias nv='nvim'
alias vim='nvim'

# Formatting
# md files
alias mdf='npx prettier --prose-wrap always --print-width 120 --write *.md'
# python files
alias pyf='ruff format *.py **/*.py'

# Listing
alias ll='ls -l'

# Cheatsheet
alias cc='cat ~/cheats'

# Git
alias gs='git status'
alias gd='git diff'
alias gdc='git diff --cached'
alias gdo='git diff origin'      # zsh version wins over bash's `git diff main`
alias gls='git ls-files'

# Maven
alias mcv='mvn clean verify'

alias h='history'

# Mac-only
if [ "$PLATFORM" = "mac" ]; then
  alias python='python3'
  alias upd='brew update && brew upgrade'
  # swift-format every .swift file under cwd in place
  alias sf='swift-format format --in-place $(find . -name \*.swift)'
fi

# Linux-only (if you've got apt; tweak for other distros)
if [ "$PLATFORM" = "linux" ] && command -v apt >/dev/null 2>&1; then
  alias upd='sudo apt update && sudo apt upgrade'
fi

# ----------------------------------------------------------------------------
# Functions
# ----------------------------------------------------------------------------
parse_git_branch() {
  git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# ----------------------------------------------------------------------------
# Local overrides (per-machine, NOT in this repo)
# ----------------------------------------------------------------------------
[ -f "$HOME/.shellrc.local" ] && . "$HOME/.shellrc.local"
