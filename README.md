# dotfiles

Cross-platform shell config, git config, Claude Code config, and personal scripts for macOS and Linux.

## Layout

```
~/dotfiles/
├── README.md
├── CLAUDE.md                 # repo-scoped instructions for Claude Code
├── install.sh                # symlinks managed files into $HOME
├── bashrc                    # symlinked to ~/.bashrc
├── zshrc                     # symlinked to ~/.zshrc
├── gitconfig                 # symlinked to ~/.gitconfig
├── gitignore_global          # symlinked to ~/.gitignore_global
├── shellrc.local.example     # template for ~/.shellrc.local
├── shell/
│   └── shared.sh             # POSIX config sourced by both bash and zsh
├── bin/                      # symlinked to ~/bin (on PATH via shared.sh)
│   ├── mac-cleanup.sh
│   └── mac-orphan-finder.sh
└── claude/
    ├── CLAUDE.md             # symlinked to ~/.claude/CLAUDE.md (global)
    └── skills/               # symlinked to ~/.claude/skills/
        ├── ai-detector/
        └── issues/
```

## Install

```sh
git clone git@github.com:steveboyer/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` is idempotent. Re-run it any time after pulling new managed files. Existing non-symlink targets get moved
to `~/.dotfiles-backup-<UTC-timestamp>/` before being replaced.

On first run, it prompts for git `user.name` and `user.email` and writes them to `~/.gitconfig.local` (which the tracked
`gitconfig` includes). Per-machine identity stays out of the repo.

## Design

- **`shell/shared.sh`** is the source of truth for everything common to bash and zsh: PATH, env, aliases, functions. It
  uses POSIX-only constructs so both shells are happy.
- **`zshrc`** and **`bashrc`** are thin stubs. Each sources `shared.sh` first, then adds the shell-specific bits (Oh My
  Zsh setup in zsh, prompt fallback in bash).
- **Platform branching** happens via the `$PLATFORM` variable set in `shared.sh` (values: `mac`, `linux`, `unknown`).
- **Per-machine overrides** live in `~/.shellrc.local`, `~/.zshrc.local`, `~/.bashrc.local`, and `~/.gitconfig.local`.
  These are NOT in the repo and are gitignored if accidentally placed inside the repo. See `shellrc.local.example` for a
  template.

## Recommended tools (install separately)

These aren't required, but the config assumes them:

```sh
# GNU userland (so sed/find/awk behave like on Linux)
brew install coreutils gnu-sed findutils gawk gnu-tar

# Diff pager used by gitconfig (otherwise git falls back to less)
brew install git-delta

# Prompt
brew install starship

# Editor
brew install neovim
```

`shared.sh` automatically prepends the GNU paths on Mac, so plain `sed`, `find`, etc. behave the way they do on Linux.
Both `bashrc` and `zshrc` fall back gracefully if `starship` isn't installed.

## Adding a new managed dotfile

Edit the `LINKS` array in `install.sh` and append `"<source-relative-to-repo> <absolute-target>"`. Re-run
`./install.sh`.

## Adding a new Claude Code skill

Create `claude/skills/<name>/SKILL.md` with YAML frontmatter:

```markdown
---
name: my-skill
description: One sentence describing when this skill should auto-load.
---

# My Skill

Skill body...
```

Re-run `./install.sh` (no-op if `~/.claude/skills` is already linked, which it will be after the first install).

## Per-machine local config

Anything specific to one machine (work AWS profile, special aliases, machine-specific PATH entries) goes in a `*.local`
file in your home directory:

```sh
# ~/.shellrc.local: sourced from shared.sh, applies to both shells
export AWS_PROFILE="work"
alias work-vpn='sudo openconnect vpn.example.com'

# ~/.zshrc.local: sourced from zshrc, zsh-only
zstyle ':completion:*' menu select

# ~/.bashrc.local: sourced from bashrc, bash-only
shopt -s autocd

# ~/.gitconfig.local: included by gitconfig
[user]
    name = Your Name
    email = you@example.com
```

Don't commit these to the repo.
