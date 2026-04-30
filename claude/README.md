# Claude Code personal config

Shared via dotfiles + rcm. Files here are symlinked individually into
`~/.claude/` by `rcup` (see `~/.dotfiles/rcrc` → `~/.rcrc` —
`DIRS="claude"` makes rcm recurse into this directory rather than
symlinking it whole, which would clobber Claude Code's runtime state in
`~/.claude/sessions`, `projects`, etc.).

## Fresh-machine setup

`install.sh` at the repo root handles everything:

1. Builds rcm 1.3.x from source into `~/.local` if `rcup` isn't already
   on PATH (Debian/Ubuntu/macOS without `apt install rcm` / `brew install
   rcm`). Needs perl + autoconf + automake + make.
2. Pre-seeds `~/.rcrc` → `~/.dotfiles/rcrc` so rcup sees `DIRS="claude"`
   on its very first run (chicken-and-egg: without this, rcup would
   try to symlink `~/.claude` whole and fail/clobber).
3. Runs `rcup -f` to materialize every symlink.

After that, `~/.local/bin` is on PATH (added by `zshrc`) so `rcup` and
friends Just Work in new shells.

## What lives here

- `CLAUDE.md`            — global personal instructions loaded into every Claude Code session
- `agents/*.md`          — personal subagent definitions
- `skills/<name>/*`      — personal skills (add when you create one)
- `commands/*.md`        — personal slash commands (add when you create one)
- `keybindings.json`     — keyboard shortcut overrides (add when you create one)

## What does NOT belong here

Anything Claude Code writes to or rotates per-machine, or that's a secret:

- `.credentials.json`, `settings.local.json`
- `sessions/`, `projects/`, `todos/`, `tasks/`, `plans/`
- `history.jsonl`, `file-history/`, `shell-snapshots/`, `paste-cache/`
- `cache/`, `downloads/`, `backups/`, `session-env/`, `ide/`, `statsig/`
- `plugins/` (mostly cache + cloned marketplaces)
- `settings.json` — usually fine to share, but if it ever diverges per
  machine, keep the divergent bits in `~/.claude/settings.local.json`
  (which the harness merges over `settings.json`)

## Adding a new shared file

1. Drop it in the appropriate spot under `~/.dotfiles/claude/`
   (mirroring its real path under `~/.claude/`).
2. `rcup -f` to symlink it into place.
3. Commit and push.

## Per-machine variants

If a file should differ across machines, use rcm tags:

    ~/.dotfiles/tag-work/claude/CLAUDE.md
    ~/.dotfiles/tag-personal/claude/CLAUDE.md

Apply with `rcup -t work` (or `-t personal`). Untagged files in
`~/.dotfiles/claude/` always apply on every host.
