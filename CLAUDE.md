# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Cross-platform shell config, git config, Claude Code config, and personal scripts for macOS and Linux. `install.sh` symlinks managed files into `$HOME` (and `~/.claude/`).

## Architecture

The shell config is deliberately split into three layers:

1. **`shell/shared.sh`** is the single source of truth for everything common to bash and zsh: PATH, env, aliases, functions. Must stay POSIX-compatible (no `[[ ]]`, no arrays, no zsh/bash-only constructs) because both shells source it.
2. **`zshrc` / `bashrc`** are thin stubs. Each sources `shared.sh` first, then adds shell-specific bits only (Oh My Zsh + Starship for zsh; prompt fallback for bash).
3. **`~/.shellrc.local`, `~/.zshrc.local`, `~/.bashrc.local`, `~/.gitconfig.local`** are per-machine overrides, NOT in the repo. `shared.sh` and the stubs source these last so a local file can override anything. `gitconfig` includes `~/.gitconfig.local` (created by `install.sh` on first run, populated with the user's git identity).

Platform branching is done through the `$PLATFORM` variable set at the top of `shared.sh` (values: `mac`, `linux`, `unknown`). Use it instead of re-detecting `uname` elsewhere.

On Mac, `shared.sh` prepends GNU coreutils/sed/findutils/gawk gnubin paths so plain `sed`, `find`, `awk` behave the Linux way. Don't write scripts that rely on BSD-specific flags.

## `install.sh`

The `LINKS` array is the source of truth for what gets symlinked. To add a new managed dotfile, append a `"<repo-relative-source> <absolute-target>"` entry to that array. Idempotent: existing correct symlinks are left alone; existing non-symlink targets get moved to `~/.dotfiles-backup-<UTC-timestamp>/` before the new symlink is created.

## `bin/` scripts

`install.sh` symlinks `bin` to `~/bin`, which `shared.sh` puts on PATH. Scripts must have the executable bit set in the index (`git update-index --chmod=+x <file>`).

- Use `#!/usr/bin/env bash`.
- The existing scripts deliberately use `set -u` only, not `set -euo pipefail`, so individual `rm` failures don't abort the cleanup run. Match that pattern for similar tools.
- Use absolute paths (`$HOME/...`), not relative ones.
- `mac-cleanup.sh` is destructive but scoped to caches and regenerable artifacts only. Don't broaden its scope to anything containing user data.
- `mac-orphan-finder.sh` is read-only by contract. It builds a report at `~/mac-orphan-report.txt` and never deletes. Preserve that invariant.

## `claude/`

Everything Claude-related lives here. `install.sh` symlinks:
- `claude/CLAUDE.md` to `~/.claude/CLAUDE.md` (global Claude Code instructions)
- `claude/skills/` to `~/.claude/skills/` (whole directory)
- `claude/hooks/` to `~/.claude/hooks/` (whole directory)

Each subdirectory of `claude/skills/` is a standalone Claude Code skill with its own `SKILL.md`. The frontmatter `description` is load-bearing: it's what determines when Claude Code auto-loads the skill. New skills require frontmatter with at minimum `name` and `description`.

`claude/hooks/` holds Claude Code hook scripts wired up by `claude/settings.json` (which references them as `~/.claude/hooks/...`). The shell hooks are POSIX `sh` (`#!/bin/sh`, no `[[ ]]` or zsh/bash builtins) so they run anywhere. They are invoked directly as commands, so they must keep the executable bit in the git index (`git update-index --chmod=+x <file>`).

## Conventions when editing

- Keep `shared.sh` POSIX. If you need bash/zsh-specific syntax, it goes in the per-shell stub or a `*.local` override.
- New aliases/env vars go in `shared.sh` if they're cross-platform, gated under `if [ "$PLATFORM" = "mac" ]` (or `linux`) blocks if not.
- Don't hardcode versioned paths. The Maven block is the pattern: glob for `apache-maven-*` and pick the first match.
- The tracked `gitconfig` has no `[user]` block. Identity lives in `~/.gitconfig.local` only.
