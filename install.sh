#!/usr/bin/env bash
#
# install.sh
# Symlinks managed dotfiles into $HOME. Idempotent.
#
# Behavior per managed file:
#   - If the target is already the right symlink: leave it alone.
#   - If anything else exists at the target: move it to
#     ~/.dotfiles-backup-<UTC-timestamp>/ (preserving its relative path),
#     then create the symlink.
#   - If the target's parent directory is missing: create it.
#
# Add a new managed dotfile by appending one entry to the LINKS array below.

set -euo pipefail

# Resolve the dotfiles repo root from this script's location, so install.sh
# works no matter where it's invoked from (e.g. via an absolute path).
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# UTC timestamp for the backup directory. Using UTC keeps it sortable and
# unambiguous across machines in different time zones.
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$HOME/.dotfiles-backup-$TIMESTAMP"

# Tracks whether anything was actually backed up during this run, so the
# "Backups saved to:" line only prints when a backup really happened (and
# not just because a same-second prior run created the same dir).
backed_up_count=0

# Each entry: "<source-relative-to-DOTFILES_DIR> <target-absolute>".
# $HOME expands at array definition time, which is what we want.
LINKS=(
  "bashrc           $HOME/.bashrc"
  "zshrc            $HOME/.zshrc"
  "gitconfig        $HOME/.gitconfig"
  "gitignore_global $HOME/.gitignore_global"
  "starship.toml    $HOME/.config/starship.toml"
  "claude/CLAUDE.md             $HOME/.claude/CLAUDE.md"
  "claude/settings.json         $HOME/.claude/settings.json"
  "claude/statusline-command.sh $HOME/.claude/statusline-command.sh"
  "claude/skills                $HOME/.claude/skills"
  "bin              $HOME/bin"
)

# Move an existing target into the backup directory, preserving its
# relative path under $HOME. Increments backed_up_count.
backup_target() {
  local target="$1"
  local rel="${target#"$HOME"/}"
  local backup_path="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$backup_path")"
  mv "$target" "$backup_path"
  backed_up_count=$((backed_up_count + 1))
  echo "  backed up: $target -> $backup_path"
}

# Create one symlink. Skips silently if the source is missing from the
# repo (lets us add LINKS entries before the source file lands without
# breaking install on older checkouts).
link_one() {
  local src="$1"
  local target="$2"
  local src_abs="$DOTFILES_DIR/$src"

  if [ ! -e "$src_abs" ]; then
    echo "  skip:      $src (source missing in repo)"
    return
  fi

  # Idempotent fast path: target is already the symlink we'd create.
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src_abs" ]; then
    echo "  ok:        $target"
    return
  fi

  # Anything else at the target (regular file, directory, or a symlink
  # pointing elsewhere) gets moved aside before we overwrite.
  if [ -e "$target" ] || [ -L "$target" ]; then
    backup_target "$target"
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$src_abs" "$target"
  echo "  linked:    $target -> $src_abs"
}

# On first install, prompt for git identity and write it to
# ~/.gitconfig.local (which the tracked gitconfig includes). Per-machine
# identity stays out of the repo.
#
# Skips the prompt if stdin isn't a tty (e.g. CI, this script being
# piped, or the smoke-test harness) so install.sh never blocks waiting
# for input that isn't coming.
prompt_gitconfig_local() {
  local gitconfig_local="$HOME/.gitconfig.local"

  if [ -e "$gitconfig_local" ]; then
    echo "  ok:        $gitconfig_local (already exists)"
    return
  fi

  if [ ! -t 0 ]; then
    echo "  skip:      $gitconfig_local (stdin not a tty; create manually)"
    return
  fi

  echo
  echo "Creating $gitconfig_local with your git identity."
  printf "  Git user.name:  "
  read -r git_name
  printf "  Git user.email: "
  read -r git_email

  if [ -z "$git_name" ] || [ -z "$git_email" ]; then
    echo "  skip:      empty name or email; not writing $gitconfig_local"
    return
  fi

  cat > "$gitconfig_local" <<EOF
[user]
	name = $git_name
	email = $git_email
EOF
  echo "  wrote:     $gitconfig_local"
}

# Optional tools the rest of the config benefits from but doesn't require.
# Each entry: "<probe-binary>:<brew-package>:<description>".
# Probe is what we test with `command -v`. It must NOT collide with any
# alias defined in shared.sh (e.g. coreutils probes `gcat`, not `gls`,
# because shared.sh aliases `gls` to `git ls-files`).
OPTIONAL_TOOLS=(
  "delta:git-delta:diff pager (matches gitconfig's colorblind palette)"
  "starship:starship:cross-shell prompt"
  "nvim:neovim:editor (set as EDITOR by shared.sh)"
)

# Mac-only: GNU userland so plain sed/find/awk/tar behave the Linux way.
# Linux ships these by default, so we only check on Mac.
MAC_GNU_TOOLS=(
  "gcat:coreutils:GNU coreutils"
  "gsed:gnu-sed:GNU sed"
  "gfind:findutils:GNU find"
  "gawk:gawk:GNU awk"
  "gtar:gnu-tar:GNU tar"
)

# Detects which optional tools are missing and either installs them
# (Mac, with brew, after a Y/n prompt) or prints manual install hints
# (Linux, or Mac without brew, or non-tty).
install_optional_tools() {
  local platform
  case "$(uname -s)" in
    Darwin) platform=mac ;;
    Linux)  platform=linux ;;
    *)      platform=unknown ;;
  esac

  local missing_pkgs=()
  local missing_descs=()
  local entry probe pkg desc

  for entry in "${OPTIONAL_TOOLS[@]}"; do
    IFS=: read -r probe pkg desc <<< "$entry"
    if ! command -v "$probe" >/dev/null 2>&1; then
      missing_pkgs+=("$pkg")
      missing_descs+=("$probe ($desc)")
    fi
  done

  if [ "$platform" = "mac" ]; then
    for entry in "${MAC_GNU_TOOLS[@]}"; do
      IFS=: read -r probe pkg desc <<< "$entry"
      if ! command -v "$probe" >/dev/null 2>&1; then
        missing_pkgs+=("$pkg")
        missing_descs+=("$probe ($desc)")
      fi
    done
  fi

  if [ ${#missing_pkgs[@]} -eq 0 ]; then
    echo "  ok:        all present"
    return
  fi

  echo "  missing:"
  local d
  for d in "${missing_descs[@]}"; do
    echo "             - $d"
  done

  case "$platform" in
    mac)
      if ! command -v brew >/dev/null 2>&1; then
        echo
        echo "  Homebrew not installed. Install from https://brew.sh, then re-run."
        return
      fi

      if [ ! -t 0 ]; then
        echo "  skip:      stdin not a tty; install manually with:"
        echo "             brew install ${missing_pkgs[*]}"
        return
      fi

      echo
      printf "  Install missing tools via brew? [Y/n] "
      read -r yn
      case "$yn" in
        n|N|no|No|NO) echo "  skipped"; return ;;
      esac

      brew install "${missing_pkgs[@]}"
      ;;
    linux)
      # Linux package manager varies and package names don't fully match
      # brew. Print hints for the three most common managers and let the
      # user pick. (git-delta is sometimes packaged as 'git-delta' or
      # 'delta'; neovim is usually 'neovim'; starship is usually 'starship'.)
      echo
      echo "  Auto-install on Linux is left manual (package names vary by distro):"
      echo "    apt:    sudo apt install ${missing_pkgs[*]}"
      echo "    dnf:    sudo dnf install ${missing_pkgs[*]}"
      echo "    pacman: sudo pacman -S ${missing_pkgs[*]}"
      ;;
    *)
      echo "  unknown platform; install these manually: ${missing_pkgs[*]}"
      ;;
  esac
}

# Detects whether zsh is the login shell and prints a switch hint if not.
# Doesn't run `chsh` directly: that has high blast radius (affects every
# future shell session) and needs a password prompt, so the user runs it.
suggest_zsh() {
  local current_shell="${SHELL:-unknown}"

  case "$current_shell" in
    */zsh)
      echo "  ok:        login shell is zsh ($current_shell)"
      return
      ;;
  esac

  if command -v zsh >/dev/null 2>&1; then
    echo "  current:   $current_shell"
    echo "  switch:    zsh is installed but not your login shell. To switch:"
    echo "               chsh -s \"\$(command -v zsh)\""
    echo "             then log out and back in."
    return
  fi

  echo "  current:   $current_shell (zsh not installed)"
  case "$(uname -s)" in
    Darwin)
      echo "  install:   brew install zsh"
      echo "  switch:    chsh -s \"\$(command -v zsh)\""
      ;;
    Linux)
      echo "  install (varies by distro):"
      echo "    apt:    sudo apt install zsh"
      echo "    dnf:    sudo dnf install zsh    # RHEL 8+, Fedora"
      echo "    pacman: sudo pacman -S zsh"
      echo "  switch:    chsh -s \"\$(command -v zsh)\""
      ;;
  esac
}

echo "Dotfiles: $DOTFILES_DIR"
echo "HOME:     $HOME"
echo
echo "Symlinks:"
for entry in "${LINKS[@]}"; do
  # `read` splits on whitespace, so multi-space alignment in LINKS works.
  read -r src target <<< "$entry"
  link_one "$src" "$target"
done

echo
echo "Per-machine git identity:"
prompt_gitconfig_local

echo
echo "Optional tools:"
install_optional_tools

echo
echo "Login shell:"
suggest_zsh

if [ "$backed_up_count" -gt 0 ]; then
  echo
  echo "Backups saved to: $BACKUP_DIR"
fi

echo
echo "Done."
