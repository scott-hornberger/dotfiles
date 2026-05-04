---
name: pr-review-fix
description: DRONE skill for fixing reviewer comments on an existing PR. Launched by MANAGER when a PR has CHANGES_REQUESTED or unresolved reviewer comments. Reads comments, applies fixes, pushes, writes handoff.
---

# PR Review Fix

You are a DRONE assigned to fix reviewer comments on an existing PR. Apply the requested changes, push, and write a handoff.

## Arguments

You will be invoked with:
- `pr=<number>` — the PR number to fix
- `branch=<branch>` — the branch the PR is on
- `handoff=<path>` — where to write your handoff (e.g. `~/go-code/handoff-fix-<task-id>.md`)

## Execution

### 1. Fetch PR state

```bash
gh pr view <number> --json title,body,headRefName,comments,reviews \
  --jq '{title, branch: .headRefName, comments: [.comments[] | {author: .author.login, body}], reviews: [.reviews[] | {author: .author.login, state, body}]}'
```

Also fetch inline review comments:
```bash
gh api repos/:owner/:repo/pulls/<number>/comments \
  --jq '[.[] | {path, line, body, author: .user.login, resolved: .position}]'
```

### 2. Identify what needs fixing

Collect all unresolved reviewer comments:
- Inline comments on specific lines
- General review comments requesting changes
- Any thread where the author has not replied "done" or "fixed"

Skip:
- Bot comments (cursor[bot], bugbot, etc.) unless they flag a real bug
- Comments the author already replied to with "done" or "fixed"
- Nitpicks the author explicitly disagreed with

### 3. Check out the branch

```bash
cd ~/go-code
git fetch origin
git checkout <branch>
git pull origin <branch>
```

### 4. Apply fixes

For each unresolved comment:
- Read the file at the referenced line
- Understand what the reviewer is asking
- Apply the minimal change that addresses the feedback
- If the fix is ambiguous, apply the most conservative interpretation

After all fixes:
```bash
arh test
arh lint
```

Fix any new failures introduced by your changes.

### 5. Commit and push

```bash
git add <specific files>
git commit -m "address review comments"
git push origin <branch>
```

Do not amend — push a new commit so reviewers can see what changed.

### 6. Write handoff

Write to the path provided in the `handoff=` argument:

```
Status: SUCCESS
PR: <number>
Branch: <branch>
Commit SHA: <sha>
Notes: <list of comments addressed, or any that were skipped and why>
```

If you could not fix something:
```
Status: BLOCKED
PR: <number>
Branch: <branch>
Notes: <exactly what you could not fix and why — the MANAGER will escalate>
```

## Key rules

- Fix only what reviewers asked for — do not refactor unrelated code
- One commit per review round — keep the history readable
- If a reviewer comment contradicts the task spec, note it in the handoff and apply the reviewer's request (they have context you may not)
- Always run `arh test` and `arh lint` before pushing
