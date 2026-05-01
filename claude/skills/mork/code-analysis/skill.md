---
name: code-analysis
description: Analyze go-code for an orchestration project. Run after analyze-code gathers raw file data; fill in LEADER Notes sections with insights, then use task-breakdown to create the task plan.
---

# Code Analysis (LEADER skill)

Deeply analyze the code at `~/mork/state/projects/<project-id>/code-analysis.md` and complete the LEADER Notes section so the task-breakdown skill can produce a high-quality plan.

## When to use

After running `analyze-code <project-id> <service>` — the raw analysis file exists but the "LEADER Notes" sections are empty. You need to fill them in by reading the actual source files.

## Step 1: Read the analysis file

```bash
cat ~/mork/state/projects/<project-id>/code-analysis.md
```

Note the service path and key files listed.

## Step 2: Read the source files

Read the key Go files listed in the analysis. Focus on:
- The main entry point (usually `main.go` or `server.go`)
- Config structs (what tunables exist?)
- Existing middleware or interceptors
- Test patterns (how are tests written here?)

Use the Read tool on `~/Uber/go-code/<rel-path>/<file>.go` for each relevant file.

## Step 3: Identify what needs to change

For the project's goal, determine:
- Which files need to be created (new)
- Which files need to be modified (existing)
- Which files are read-only context
- What dependencies or imports need updating (go.mod, etc.)

## Step 4: Identify task boundaries

A task boundary is anywhere you'd want a separate PR:
- Dependency changes (`go.mod` updates) → separate task
- New package or interface definition → separate task
- Implementation that builds on the new interface → separate task
- Integration or wiring into the existing service → separate task
- Config additions → can often be folded into implementation task

Rule of thumb: if a reviewer would want to see it independently, it's a separate task.

## Step 5: Write LEADER Notes into the analysis file

Edit `~/mork/state/projects/<project-id>/code-analysis.md` and fill in:

```markdown
### Current Implementation Summary
[What the service does; how requests flow; key abstractions]

### Files to Modify
- `src/.../server.go` — add middleware registration (line ~45, `registerInterceptors`)
- `src/.../config.go` — add RateLimit config struct field
- `go.mod` / `go.sum` — add rate limiting library

### Dependencies to Note
- Uses `go-uber-org/fx` for dependency injection
- Tests use `testify` and `gomock`
- Existing middleware pattern: implement `grpc.UnaryServerInterceptor`

### Recommended Approach
[High-level strategy — e.g., "add library in task 1, implement interceptor in task 2, wire into server in task 3"]

### Rough Task Breakdown
- Task 1: Add library dependency (go.mod)
- Task 2: Implement rate limiter interceptor + tests
- Task 3: Register interceptor in server, add config
```

## Step 6: Confirm with task-breakdown

Once LEADER Notes are filled in, invoke the task-breakdown skill to convert the rough breakdown into structured tasks with correct JSON and branch names.
