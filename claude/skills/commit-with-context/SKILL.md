---
name: commit-with-context
description: Create a git commit (or amend) whose message ends with a structured metadata block — devpod hostname, worktree path, current branch — so future-me can trace which machine and workspace produced any given commit. Use whenever the user asks to "commit", "make a commit", "commit this", "create a commit", "commit my changes", "amend the commit", or "amend with message". Never credits Claude. Always shows the proposed message and waits for approval before committing.
---

# Commit with context

Create a git commit (or amend the last one) with a structured trailer that records **where** the commit was made: devpod hostname, worktree path, and branch. Useful when work spans multiple devpods and worktrees and `git log` alone doesn't tell you where a change physically came from.

## Hard rules

- **Never credit Claude** in commit messages — no "Co-Authored-By: Claude", no "🤖 Generated with…", nothing. (Per CLAUDE.md / CLAUDE.local.md.)
- **Always show the proposed message and wait for approval** before running `git commit`. The user may edit subject, body, or metadata before you commit.
- **Never run `git push`** after committing unless the user explicitly asks. Pushing is a separate decision.
- **Do not stage files the user didn't intend to commit.** If `git status` shows untracked files, ask before adding them.

## Step 1: Gather context (parallel)

Run these in a single batch:

```
git status                          # what's changed / staged
git diff --cached                   # staged diff (or `git diff` if nothing staged)
git log -5 --oneline                # recent commit style for this repo
git log -1 --pretty=format:%s%n%n%b # ONLY if amending — current message
hostname                            # devpod identifier
git rev-parse --show-toplevel       # worktree path
git branch --show-current           # branch
git rev-parse --git-common-dir      # to detect if this is a linked worktree
git rev-parse --git-dir             # ditto
```

The current dir is a **linked worktree** if `git-common-dir` and `git-dir` differ. It's the **main worktree** (or a non-worktree clone) if they're the same.

## Step 2: Decide commit vs amend

| User said | Action |
|---|---|
| "commit", "commit this", "make a commit", "create a commit" | Fresh commit |
| "amend", "amend the commit", "amend with message", "fix the commit message" | `git commit --amend` |

If amending, start from the existing message (from `git log -1 …` above) and modify it — don't rewrite from scratch unless the user asks.

## Step 3: Write the message

### Subject line
- Imperative mood, present tense ("Add foo", not "Added foo" or "Adds foo")
- ≤ 70 characters
- No trailing period
- Match the repo's existing style (check `git log -5 --oneline`)

### Body
- Blank line after subject
- Explain **WHY**, not WHAT — the diff shows WHAT
- Wrap at ~72 characters
- Bullet points are fine for multi-part changes

### Metadata block (always last)

Format the block with `---` separator and aligned `Key:    Value` pairs:

```
---
Devpod:    <hostname>
Worktree:  <path-with-~-substitution>
Branch:    <branch>
```

Worktree value rules:
- If main worktree (or non-worktree clone): `Worktree:  main` followed by the absolute path in parens, e.g. `main (/home/user/go-code)`
- If linked worktree: full path with `~` substitution, e.g. `~/.claude/worktrees/feature-x`

Use a real tab or 4-space alignment so the values line up under each other.

## Step 4: Show the message and wait

Print the full proposed message inside a fenced code block. Ask the user to confirm, edit, or reject. Common edits:
- Tighten or rephrase the subject
- Add/remove a body paragraph
- Skip the metadata block (rare, but allowed — they can say "no metadata")

**Wait for explicit approval** ("ok", "looks good", "do it", "go") before running git.

## Step 5: Commit

Always pass the message via a heredoc to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
<subject>

<body>

---
Devpod:    <hostname>
Worktree:  <path>
Branch:    <branch>
EOF
)"
```

For amends:

```bash
git commit --amend -m "$(cat <<'EOF'
…
EOF
)"
```

## Step 6: Verify

After committing, run `git log -1 --pretty=format:%s%n%n%b` and show the output. If the commit failed (pre-commit hook, etc.), do NOT use `--amend` to retry — fix the underlying issue and create a new commit.

## Examples

### Fresh commit on a worktree

```
Add buildkite-ci-troubleshooter agent definition

Captures the conventions for our buildkite pipelines so future
sessions don't have to re-derive them from CI logs.

---
Devpod:    sth-go.devpod-nld
Worktree:  ~/.claude/worktrees/agents-cleanup
Branch:    sth/agents/buildkite-ci-troubleshooter
```

### Amend on the main checkout

```
Fix flag default for --target-environment

The default of "" was being interpreted as "all" by downstream
code; explicitly pass the canonical "all" sentinel instead.

---
Devpod:    sth-go.devpod-nld
Worktree:  main (/home/user/go-code)
Branch:    sth/0426/rdm-target-env-default
```

## Common pitfalls

- **Forgetting `--amend` when the user said "amend"**: read the request carefully, default to fresh commit only when ambiguous.
- **Leaking Claude attribution**: double-check the final message has no "Co-Authored-By: Claude" or similar.
- **Adding unstaged files via `git add -A`**: only stage what the user asked for. Prefer `git add <specific files>`.
- **Committing in a dirty state without confirming**: if `git status` shows untracked or unstaged changes that AREN'T part of the intended commit, surface them and ask before proceeding.
- **Amending a pushed commit silently**: if the branch has already been pushed, mention it — amending rewrites history and forces a force-push later.
