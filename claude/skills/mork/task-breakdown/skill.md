---
name: task-breakdown
description: Break down an analyzed project into concrete DRONE tasks. Reads code-analysis.md LEADER Notes, creates structured task JSON and task instruction files for each task.
---

# Task Breakdown (LEADER skill)

Convert the completed LEADER Notes in `code-analysis.md` into structured tasks stored in state.json, plus a task instructions file per task for the DRONE.

## Prerequisites

- `analyze-code <project-id> <service>` has been run
- The `code-analysis.md` LEADER Notes sections are filled in (use code-analysis skill first)

## Step 1: Read the completed analysis

```bash
cat ~/mork/state/projects/<project-id>/code-analysis.md
```

Focus on:
- "Files to Modify" — tells you what each task touches
- "Recommended Approach" — the sequencing strategy  
- "Rough Task Breakdown" — starting point for tasks

## Step 2: Define tasks

For each task, determine:

| Field | Value |
|-------|-------|
| `id` | `task-1`, `task-2`, … (sequential) |
| `description` | One short sentence describing the PR |
| `branch` | `sth/<project-slug>/<task-slug>` |
| `dependencies` | IDs of tasks that must be in review/merged first |

**Branch naming:** `sth/<project-name-hyphenated>/<task-name-hyphenated>`  
Example: `sth/auth-rate-limit/add-dependency`

**Dependency rule:** Task B depends on Task A if B imports or builds on what A creates.

## Step 3: Add tasks to state

For each task, run:

```bash
~/mork/lib/state-manager.sh add-task <project-id> '{
  "id": "task-1",
  "description": "Add golang.org/x/time/rate dependency to go.mod",
  "branch": "sth/auth-rate-limit/add-dependency",
  "pr_number": null,
  "status": "pending",
  "dependencies": [],
  "drone_session_id": null,
  "started_at": null,
  "completed_at": null,
  "handoff_path": null
}'
```

## Step 4: Write task instruction files

For each task, create `~/mork/state/projects/<project-id>/tasks/<task-id>.md`.

Use the drone-task skill template. Each file should contain:
- Project and task context
- Exact code locations (from the analysis)
- Specific what-to-do instructions (not how-to-use-git instructions)
- Success criteria and handoff doc requirement

Example for a dependency task:

```markdown
# TASK: task-1 — Add rate limiter dependency

## Context
Project: Add rate limiting to auth service
Task 1 of 3. Subsequent tasks depend on this.

## Objective
Add `golang.org/x/time/rate` to go.mod and go.sum.

## Code Locations
- `~/go-code/go.mod` — add the require entry
- `~/go-code/go.sum` — will be updated automatically by `go mod tidy`

## Instructions
1. cd ~/go-code
2. Add the dependency: `go get golang.org/x/time/rate`
3. Run `go mod tidy` to clean up go.sum
4. Verify: `go build ./...` should succeed

## Deliverables
- Branch: sth/auth-rate-limit/add-dependency
- PR title: "auth: add golang.org/x/time/rate dependency"
- PR body: explain this is the first task of the rate limiting stack

## Success Criteria
- [ ] `go build ./...` passes
- [ ] Lint passes
- [ ] PR created via `arh publish`
- [ ] Handoff written to ~/go-code/handoff-task-1.md

## Handoff Required
Write `~/go-code/handoff-task-1.md`:
- Status: SUCCESS or BLOCKED
- Branch name and commit SHA
- PR number
- Any issues
```

## Step 5: Verify the plan

```bash
~/mork/lib/plan-project <project-id>
```

Check that:
- All tasks are listed with correct dependencies
- Task instruction files exist for each pending task
- Dependency chain makes sense

## Step 6: Ready to execute

```bash
~/mork/lib/execute-project <project-id>
```
