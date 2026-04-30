---
name: pr-review-handoff
description: Analyze a user's GitHub PRs, surface unanswered reviewer comments for decisions, then produce a structured TODO handoff doc per branch (handles both stacked and independent PRs). Use when the user says "review my PRs", "build a handoff doc for my PRs", "extract TODOs from my PRs", "analyze my open PRs", "what's left on my PRs", or provides a list of PR numbers/links and wants the comment threads triaged into actionable TODOs. For stacked PRs, propagates cross-cutting fixes across all branches in the stack.
---

# PR Review → Handoff Doc

Analyze a user's PRs, extract actionable TODOs from comments, and produce a handoff doc that can be delegated to other agents for execution.

## Step 1: Find the PRs

Use the code-review MCP to find the user's PRs:

```
mcp code-mcp get_review_items
  author_emails: [user's email from `git config user.email`]
  created_after: reasonable lookback (e.g. 90 days)
  lifecycle_phases: ["in_review", "landed"]
```

Filter results by whatever criteria the user specifies (title prefix, repo, etc.).

## Step 2: Determine if PRs are stacked

Check each PR description for a `## Stack` section:

```
## Stack
1. #85938
1. #85939
1. @ #85940
```

The `@` marker indicates the current PR. The list is ordered root-first.

- **If a stack is present**: these PRs share a dependency chain. Process root-first. Changes in earlier branches propagate to later ones.
- **If no stack is present**: the PRs are independent. Process in any order. Each PR is its own isolated unit of work.

## Step 3: Fetch diff and comments for each PR

For each PR, fetch both in parallel:

```
mcp code-mcp get_github_pull_request_diff  (org, repo, number)
mcp code-mcp get_github_pull_request_comments  (org, repo, number)
```

## Step 4: Surface unanswered comments for user decision

Before building TODOs, go through each PR's comments and find any **human reviewer comments that the author has not yet responded to**. These are comments where:
- A human reviewer (not a bot) left feedback
- The author (user) has no reply on that comment thread — no "will do", no "done", no disagreement, nothing

Present these to the user **per PR, one PR at a time**, before moving on. Format:

```
PR #N (branch) — Unanswered reviewer comments:

1. [reviewer] on file.go:L42: "should we default to all environments?"
   → This is asking about default behavior. Options: (a) default to all envs, (b) keep requiring explicit envs, (c) defer to a follow-up

2. [reviewer] on file.go:L88: "is IsUpError() needed here?"
   → Clarification question about error handling. You could: (a) explain why the guard is needed, (b) remove it if FormatUpeWithTags handles non-Up errors safely
```

For each unanswered comment, provide brief guidance on what the options are so the user can make a quick decision. **Wait for the user to respond** before building TODOs for that PR. Their answers determine what goes into the TODO list.

Comments the user has already responded to on the PR (agreed, disagreed, or marked done) do not need to be surfaced — use those responses directly to build TODOs.

## Step 5: Build TODOs from resolved comments

Once the user has responded to all unanswered comments, build the TODO list for each PR. Categorize comments:

### Comment sources and how to handle them

| Source | Weight | How to handle |
|--------|--------|---------------|
| **Human reviewer** (the assignee) | Highest | Include if author agreed ("will do", "good point") or user just decided to act on it. Skip if author/user disagreed with valid reason. |
| **Author self-replies** | Context | "done" = already fixed, skip. "will do" = TODO. |
| **cursor[bot] / Bugbot** | Medium | Include if the issue is real (e.g. nil deref, wrong flag names). Skip stylistic noise. |
| **uber-ureview[bot] / uReview** | Medium | Include high-confidence concerns. Skip duplicates of human reviewer comments. |
| **Bot summary comments** | Skip | PR summaries, review round summaries — no TODOs here. |

### What makes a good TODO

- **Specific**: "Rename `formatService` to `formatEntity` in cmd.go" not "clean up naming"
- **Actionable**: includes the file, the change, and why
- **Traceable**: note the source (reviewer name)

### What to skip

- Comments the author replied "done" to (already fixed in a later commit)
- Comments the author disagreed with and gave a valid reason
- Pure questions with no action implied
- Duplicate comments from multiple bots about the same issue

## Step 6: Propagate cross-cutting fixes (stacked PRs only)

This only applies when PRs are stacked. After building per-PR TODOs:

1. **Identify patterns established in the root PR** — error handling, naming conventions, flag patterns, display formatting
2. **Check if later PRs copy those patterns** — they usually do (copy-paste from the first implementation)
3. **If a reviewer comment on ANY PR changes the pattern, propagate the fix to ALL branches that use it**

Example: If PR #3 gets a comment "remove RDM from error messages", but PR #1 is where that error format originated, add the fix to PR #1's TODO list AND PR #2 and #3.

4. **Check test assertions** — if you change error messages/formats, the tests that assert on those strings need updating on every branch.

## Step 7: Write the handoff doc

### For stacked PRs

```markdown
# [feature] — Review TODOs

## How to execute

Start from `main`. For each branch below (in order):
1. `git checkout <branch>`
2. `g up` (pull tracked remote branch)
3. Complete all TODOs for that branch
4. `g amend --no-edit`
5. Move to the next branch and repeat

## Branch: `branch-name` (PR #N — short label)

1. TODO item with specific file, change, and why
2. ...
```

### For independent PRs

```markdown
# [feature/scope] — Review TODOs

## Branch: `branch-name` (PR #N — short label)

### How to execute
1. `git checkout <branch>`
2. `g up`
3. Complete TODOs below
4. `g amend --no-edit`

### TODOs
1. TODO item with specific file, change, and why
2. ...
```

### Handoff doc rules

- One section per branch
- For stacks: ordered root-first
- Every TODO references the specific file(s) to change
- Flag names, function names, and string literals are quoted exactly
- Test assertion updates are explicit (old value -> new value)
- No vague items like "clean up code" — every item is a concrete edit
- Include execution instructions (checkout, pull, amend workflow)

## Step 8: Delegate to agents

Each branch's TODO section is a self-contained work unit that can be handed to an agent. Run agents sequentially — one branch at a time, in order. This avoids conflicts and lets each agent build on the previous one's work.

The agent prompt should include:
- The branch name to check out
- The full TODO list for that branch
- Instructions to read each file before editing
- Instructions to commit with `g amend --no-edit` when done

## Step 9: Review with the user

Present the handoff doc to the user before saving or delegating. They may:
- Remove items they disagree with
- Add items you missed
- Reorder priorities
- Adjust the execution workflow

Only save/execute after confirmation.

## Common pitfalls

- **Missing test updates**: Every behavioral change (error messages, flag names, output format) has a test somewhere that asserts on the old behavior. Find it.
- **Forgetting later-branch feedback applies to earlier branches** (stacks): A reviewer might only comment on PR #3 because that's where they noticed the issue, but the pattern was introduced in PR #1.
- **Treating bot comments as gospel**: Bots flag things the author already dismissed. Check author replies before including.
- **Not checking what "done" means**: Author saying "done" on a comment means they pushed a fix. Verify by checking if the latest diff still has the issue — sometimes "done" was on an older commit and got reverted.
