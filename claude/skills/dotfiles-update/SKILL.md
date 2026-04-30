---
name: dotfiles-update
description: Commit and push changes in ~/.dotfiles to GitHub, handling all the gotchas — edit-source-not-symlink check, rcup -f for new symlink targets, the metadata trailer block, and the `git push origin main` workaround for the Uber devpod /etc/gitconfig bug. Use when the user says "update dotfiles", "sync dotfiles", "push dotfiles", "commit dotfiles", "save my dotfiles changes", "ship the dotfile changes", or after editing anything under ~/.dotfiles/ and wanting to land it.
---

# Update dotfiles

End-to-end workflow for landing changes in `~/.dotfiles` to the GitHub remote, with all the project-specific guardrails baked in.

## Hard rules

- **Never `git push` bare** — always `git push origin main`. Uber devpods have a duplicated `[branch "main"]` block in `/etc/gitconfig` that triggers "multiple upstream branches, refusing to push" on bare push.
- **Never credit Claude** in commit messages.
- **Source path, not symlink** — if files were edited under `~/.claude/` directly (real files, not symlinks), they're NOT in the repo. Surface this to the user before continuing. The fix is to move them into `~/.dotfiles/claude/` and `rcup -f`.
- **Always show the proposed commit message and wait for approval** before committing.
- **Always confirm before pushing** — committing locally is reversible; pushing to GitHub is public.

## Step 1: Check state (parallel)

```
cd ~/.dotfiles && git status --short
cd ~/.dotfiles && git diff --stat
cd ~/.dotfiles && git diff --cached --stat
cd ~/.dotfiles && git log -5 --oneline
hostname
git -C ~/.dotfiles rev-parse --show-toplevel
```

## Step 2: Detect orphaned edits in ~/.claude

If there are recent edits to `~/.claude/` that are NOT symlinks (i.e., the user wrote a new file directly in the symlinked location instead of in `~/.dotfiles/claude/`), those are orphaned — git won't see them.

Quick check:

```bash
find ~/.claude -maxdepth 4 -type f -newer ~/.dotfiles/.git/HEAD \
  ! -path "*/sessions/*" ! -path "*/projects/*" ! -path "*/todos/*" \
  ! -path "*/tasks/*" ! -path "*/plans/*" ! -path "*/cache/*" \
  ! -path "*/file-history/*" ! -path "*/shell-snapshots/*" \
  ! -path "*/paste-cache/*" ! -path "*/downloads/*" ! -path "*/backups/*" \
  ! -path "*/session-env/*" ! -path "*/ide/*" ! -path "*/statsig/*" \
  ! -path "*/plugins/*" ! -name "history.jsonl" ! -name ".credentials.json"
```

For each result that is a real file (not a symlink): tell the user it needs to move to `~/.dotfiles/claude/<...>` first. Wait for them to confirm or relocate before proceeding.

## Step 3: Materialize new symlinks with rcup

If `git status` shows new files or directories under `claude/` (skills, agents, commands, etc.), run `rcup -f` BEFORE committing so the symlinks under `~/.claude/` exist and Claude Code picks them up in new sessions:

```bash
export PATH="$HOME/.local/bin:$PATH"   # in case ~/.local/bin isn't on PATH yet
rcup -f
```

Skip if only existing files were modified (no new ones).

## Step 4: Stage files explicitly

NEVER `git add -A` or `git add .`. Stage by name based on what's in `git status --short`:

```bash
cd ~/.dotfiles && git add <specific-files-or-dirs>
```

If untracked files appear that weren't part of the user's intent, ask before adding.

## Step 5: Compose the commit message

### Subject

- Imperative, ≤ 70 chars, no period
- Match recent commit style (`git log -5 --oneline`)
- Common patterns this repo uses:
  - `Add <thing> (<short description>)`
  - `<file>: <what changed>` (e.g. `CLAUDE.md: …`, `install.sh: …`)
  - `Share <X> via <mechanism>`

### Body

- Blank line after subject
- Explain WHY when not obvious from the subject
- Bullet list for multi-part changes
- Keep it short — most dotfile changes are self-explanatory

### Metadata trailer

Always append the same block format used by `commit-with-context`:

```
---
Devpod:    <hostname>
Worktree:  main (/home/user/.dotfiles)
Branch:    main
```

(The dotfiles repo is rarely worktree'd, so `main (/home/user/.dotfiles)` is the usual value. Detect properly via `git rev-parse --git-common-dir` vs `--git-dir` if you want to be robust.)

## Step 6: Show & confirm

Display the full commit message in a fenced code block. Wait for explicit approval ("ok", "go", "do it", "looks good"). Common edits:
- Tighten subject
- Drop a body paragraph
- Skip metadata block (rare)

## Step 7: Commit

Use heredoc so formatting + the `---` separator survive:

```bash
cd ~/.dotfiles && git commit -m "$(cat <<'EOF'
<subject>

<body>

---
Devpod:    <hostname>
Worktree:  main (/home/user/.dotfiles)
Branch:    main
EOF
)"
```

If pre-commit hook fails: fix the underlying issue and create a NEW commit. Do NOT use `--amend`.

## Step 8: Confirm push

Show the commit (`git log -1`) and ask the user if they want to push now. If yes:

```bash
cd ~/.dotfiles && git push origin main
```

**Always `origin main`, never bare `git push`** (see Hard rules).

If push fails with "multiple upstream branches": run the local-config cleanup, then retry:

```bash
cd ~/.dotfiles
git config --local --unset-all branch.main.remote
git config --local --unset-all branch.main.merge
git push origin main
```

## Step 9: Verify

After push, run `git log origin/main..HEAD` — should be empty (everything is on the remote). If not, surface the unsent commits.

## Examples

### Adding a new skill

```
Add buildprune-helper skill (one-shot binary-bloat triage)

Captures the `buildprune` invocation and the follow-up steps for
inlining identified imports. Saves re-deriving the workflow.

---
Devpod:    sth-go.devpod-nld
Worktree:  main (/home/user/.dotfiles)
Branch:    main
```

### Tweaking CLAUDE.md

```
CLAUDE.md: add reminder to use `arh test` not `bazel test //...`

The bare bazel command builds the entire monorepo and Claude
sometimes reaches for it; arh test scopes correctly.

---
Devpod:    sth-go.devpod-nld
Worktree:  main (/home/user/.dotfiles)
Branch:    main
```

## Common pitfalls

- **Bare `git push`**: triggers the Uber `/etc/gitconfig` upstream-duplication bug. Always `git push origin main`.
- **Editing `~/.claude/<file>` directly when it's not yet a symlink**: the file is real and orphaned from the repo. Move to `~/.dotfiles/claude/<file>` and `rcup -f`.
- **Forgetting `rcup -f` after adding a new file**: the symlink under `~/.claude/` won't exist yet, so Claude Code won't pick up the new skill/agent/command in new sessions until next bootstrap.
- **`git add -A` sweeping in `.swp` files**: dotfiles `.gitignore` covers most, but stage explicitly to be safe.
- **Crediting Claude**: forbidden by CLAUDE.local.md.
- **Pushing to a different branch**: this repo's only branch is `main`. If you find yourself on something else, you're in the wrong repo.
