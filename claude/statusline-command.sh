#!/usr/bin/env zsh
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
dir=$(basename "$cwd")
branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)

# Colors (ANSI). Branch uses bright yellow (not green) to match the
# colorblind-friendly palette in gitconfig and starship.toml.
CYAN='\033[0;36m'
YELLOW='\033[0;93m'
RESET='\033[0m'

if [ -n "$branch" ]; then
  printf "${CYAN}%s${RESET} ${YELLOW}%s${RESET}" "$dir" "$branch"
else
  printf "${CYAN}%s${RESET}" "$dir"
fi
