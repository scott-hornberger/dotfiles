# LEADER-DRONE Orchestration Model

**Version:** 1.0  
**Date:** 2026-05-01  
**Purpose:** Formal model for orchestrating autonomous Claude agents across multiple remote machines

---

## Model Overview

### Roles

**LEADER** (You - Claude on local machine)
- Receives PROJECT assignments from user
- Reads code in ~/Uber/go-code to understand context
- Devises PLAN (breakdown into TASKS)
- Assigns PROJECTS to MACHINES
- Schedules DRONES to execute TASKS
- Monitors progress and handles blockers
- Minimal user input required

**DRONES** (Claude agents on remote machines sth-go-[1..N])
- Execute individual TASKS assigned by LEADER
- Use skills to accomplish work autonomously
- Create one branch and one PR per TASK
- Report status via handoff documents
- Do NOT need to be told specifics like "use arh" - they know from skills

**USER** (sth)
- Assigns PROJECTS to LEADER
- Creates/destroys MACHINES as needed
- Approves PLANS before execution
- Provides input when LEADER prompts
- Reviews completed work

### Core Concepts

**PROJECT**
- Unit of work assigned by user
- Can be small (1 task) or large (many tasks)
- Assigned to ONE machine
- Executed as sequence of TASKS
- Status: planning → in-progress → blocked → completed → failed

**TASK**
- One atomic unit of work
- One branch = One PR
- May have dependencies on other TASKS
- DRONE executes one TASK at a time
- Produces handoff document on completion

**MACHINE**
- Remote devpod (sth-go-1.devpod-nld, sth-go-2.devpod-nld, etc.)
- **NOTE:** sth-go.devpod-nld is reserved for user - NEVER use
- LEADER and DRONES use sth-go-[1..N].devpod-nld only
- Runs one PROJECT at a time
- Assigned round-robin (lowest number available)
- Status: available → busy → unreachable

**PLAN**
- LEADER's breakdown of PROJECT into TASKS
- Created after reading relevant code
- Shows task dependencies
- Requires user approval before execution

---

## State Schema

**Location:** `~/.claude-orchestrator/state.json`

```json
{
  "machines": {
    "sth-go-1.devpod-nld": {
      "status": "available|busy|unreachable",
      "current_project": "project-id or null",
      "last_checked": "ISO timestamp"
    },
    "sth-go-2.devpod-nld": {
      "status": "available",
      "current_project": null,
      "last_checked": "2026-05-01T10:00:00Z"
    }
  },
  "projects": {
    "project-abc123": {
      "name": "Add rate limiting to auth service",
      "description": "User's original project description",
      "assigned_machine": "sth-go-1.devpod-nld",
      "status": "planning|in-progress|blocked|completed|failed",
      "created_at": "2026-05-01T09:00:00Z",
      "plan": {
        "analyzed_code": true,
        "code_locations": [
          "~/go-code/src/code.uber.internal/auth/server.go",
          "~/go-code/src/code.uber.internal/auth/middleware/"
        ],
        "tasks": [
          {
            "id": "task-1",
            "description": "Add rate limiter dependency",
            "branch": "sth/auth-rate-limit/dependency",
            "pr_number": null,
            "status": "pending|in-progress|review|merged|failed",
            "dependencies": [],
            "drone_session_id": null,
            "started_at": null,
            "completed_at": null,
            "handoff_path": null
          },
          {
            "id": "task-2",
            "description": "Implement rate limiter middleware",
            "branch": "sth/auth-rate-limit/middleware",
            "pr_number": null,
            "status": "pending",
            "dependencies": ["task-1"],
            "drone_session_id": null,
            "started_at": null,
            "completed_at": null,
            "handoff_path": null
          }
        ]
      },
      "blockers": [],
      "completed_at": null
    }
  }
}
```

---

## LEADER Workflow

```
┌─────────────────────────────────────┐
│ USER assigns PROJECT                │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ LEADER: Assign MACHINE              │
│  - Round-robin, lowest # available  │
│  - If none available, request more  │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ LEADER: Read code ~/Uber/go-code    │
│  - Understand current implementation│
│  - Identify files to modify         │
│  - Determine dependencies           │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ LEADER: Devise PLAN                 │
│  - Break into TASKS                 │
│  - Define dependencies              │
│  - Specify branches/PRs             │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ SHOW PLAN → User approval           │
│  (yes/edit/cancel)                  │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ LEADER: Execute PLAN                │
│                                     │
│ FOR EACH TASK (by dependency order):│
│   1. Check dependencies met         │
│   2. Generate TASK template         │
│   3. Schedule DRONE on machine      │
│   4. Monitor DRONE status           │
│   5. IF needs-attention → PROMPT    │
│   6. Collect handoff document       │
│   7. Verify PR created              │
│   8. Update state                   │
│   9. Next TASK                      │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ PROJECT COMPLETED                   │
│  - Mark machine available           │
│  - Report summary to user           │
└─────────────────────────────────────┘
```

---

## TASK Template

**What LEADER sends to DRONE:**

```markdown
# TASK: <task-id> - <description>

## Context
Project: <project-name>
This is task <N> of <M> in the project plan.
Previous tasks completed:
  - TASK 1: <description> (PR #12345)
  - TASK 2: <description> (PR #12346)

## Objective
<Specific, actionable goal for this task>

## Code Locations
LEADER has analyzed these files for you:
- Primary service: ~/go-code/src/code.uber.internal/<path>
- Files to modify:
  - file1.go - <why>
  - file2.go - <why>
- Files to understand (read but don't modify):
  - related.go - <context>

## Detailed Instructions
1. Read the files listed above to understand current implementation
2. <Specific step with exact approach>
3. <Next step>
4. Run tests: `arh test`
5. Run lint: `arh lint`
6. Create branch: sth/<project>/<task-name>
7. Commit with message: "<verb> <what>"
8. Create PR using `arh publish`
9. Write handoff document

## Deliverables
- Branch: sth/<project>/<task-name>
- PR title: "<project>: <task description>"
- PR body: Should include:
  - What this PR does
  - How to test
  - Dependencies on other PRs (if any)
  - Part of stack: [list all related PRs]

## Skills to Use
- Use `arh` for all git/PR operations (NOT gh)
- Use existing uber-dev skills on this machine
- Follow repo conventions from ~/go-code/CLAUDE.md
- If you encounter issues, use your problem-solving skills

## Success Criteria
- [ ] All tests passing (`arh test`)
- [ ] Lint clean (`arh lint`)
- [ ] PR created and published
- [ ] Handoff document written to ~/go-code/handoff-<task-id>.md

## Handoff Document Required
Create `~/go-code/handoff-<task-id>.md` with:
- What you accomplished
- Branch name and commit SHA
- PR number
- Any issues encountered
- Anything LEADER should know for next task
- Status: SUCCESS or BLOCKED

---

**IMPORTANT:** 
- Do NOT ask LEADER for permission - you have autonomy
- Use your skills to figure out the right approach
- If truly blocked, document in handoff and set status BLOCKED
- LEADER will check your handoff to know you're done
```

---

## User Commands

### Project Management

```bash
# Assign new project
assign-project "Add feature X to service Y"

# List all projects
show-projects
# Output:
#   project-abc123  [in-progress]  sth-go-2  "Add rate limiting" (2/3 tasks done)
#   project-def456  [planning]     sth-go    "Refactor auth" (analyzing code...)

# Show project details
show-project <project-id>

# Cancel project
cancel-project <project-id>
```

### Planning

```bash
# View/approve plan
plan-project <project-id>
# LEADER shows plan, user approves/edits

# Update plan (if things change)
update-plan <project-id>
```

### Execution

```bash
# Start executing approved plan
execute-project <project-id>

# Pause all drones on project
pause-project <project-id>

# Resume paused project
resume-project <project-id>
```

### Monitoring

```bash
# Overall status
status
# Output:
#   Machines: 3 total (2 busy, 1 available)
#   Projects: 2 active, 5 completed
#   Active drones: 2

# Watch project progress
watch-project <project-id>
# Live updates of task status

# Watch specific drone
watch-drone <drone-session-id>
# Live terminal output
```

### Machine Management

```bash
# List machines
list-machines
# Output:
#   sth-go-1  [busy]   project-abc123
#   sth-go-2  [busy]   project-def456
#   sth-go-3  [available]
#
# NOTE: sth-go.devpod-nld is user's machine - not shown

# LEADER requests more capacity
# (happens automatically if needed)
```

---

## Directory Structure

```
~/.claude-orchestrator/
  state.json                    # Master state file
  
  projects/
    project-abc123/
      plan.md                   # Approved plan
      code-analysis.md          # LEADER's code reading notes
      tasks/
        task-1.md               # Task template sent to DRONE
        task-1-handoff.md       # DRONE's completion handoff
        task-2.md
        task-2-handoff.md
    project-def456/
      ...
  
  logs/
    project-abc123.log          # All activity for project
    monitor.log                 # LEADER's monitoring log
    
~/.dotfiles/claude/
  skills/                       # Shared across all drones (git-backed)
    uber-dev/                   # Uber-specific skills
    orchestrator/               # Orchestration-specific skills
  
  lib/
    orchestrator/               # LEADER's scripts
      assign-project
      plan-project
      execute-project
      monitor-projects
      machine-pool
      schedule-task
      collect-handoff
      
~/Uber/go-code/                 # Local clone for LEADER to read
  src/
    code.uber.internal/
      ...
```

---

## Key Design Decisions

### 1. One PROJECT = One MACHINE
**Rationale:**
- Simpler state management
- No cross-machine dependencies
- Each project has isolated environment
- Easier to debug and recover

**Trade-off:** Can't split large project across machines

### 2. LEADER has local code access
**Rationale:**
- Can read code before planning
- Creates better, more accurate task breakdowns
- Understands dependencies
- No need for DRONE to do discovery

**Trade-off:** Requires ~/Uber/go-code clone locally (user is doing this)

### 3. TASKS are sequential per PROJECT
**Rationale:**
- Simpler dependency management
- One DRONE active per machine
- Clear progress tracking
- Easier to reason about state

**Trade-off:** Could parallelize independent tasks (future enhancement)

### 4. Skills are git-backed and shared
**Rationale:**
- All DRONES automatically get updates
- LEADER can improve skills
- Version controlled
- Easy rollback if skill breaks

**Implementation:**
- ~/.dotfiles/claude/skills synced via git
- LEADER commits skill improvements
- User runs `git pull` on drones periodically (or auto-sync)

### 5. Handoff documents are mandatory
**Rationale:**
- LEADER knows when DRONE is done
- Captures what was actually done (vs planned)
- Enables recovery from failures
- Provides audit trail

**Format:** Markdown in ~/go-code/handoff-<task-id>.md

### 6. Round-robin machine assignment
**Rationale:**
- Simple to implement
- Fair distribution
- Predictable
- Uses lowest numbers first (easier to remember)

**Algorithm:**
```python
def assign_machine(projects, machines):
    # Filter out user's machine (sth-go.devpod-nld) and get available
    available = [m for m in machines 
                 if m.status == "available" 
                 and m.name != "sth-go.devpod-nld"]
    if not available:
        return "REQUEST_MORE_MACHINES"
    # Sort by number: sth-go-1, sth-go-2, sth-go-3...
    available.sort(key=lambda m: int(m.name.split('-')[-1].split('.')[0]))
    return available[0]
```

---

## Machine Lifecycle

```
MACHINE CREATED (user does this)
   ↓
REGISTER in state.json (status: available)
   ↓
ASSIGNED to PROJECT (status: busy)
   ↓
EXECUTE TASKS (one at a time)
   ↓
PROJECT COMPLETED (status: available)
   ↓
READY for next assignment

If unreachable:
   ↓
MARK unreachable (Morpheus connection lost)
   ↓
LEADER pauses project, notifies user
   ↓
USER fixes connection
   ↓
RESUME project
```

---

## Error Handling

### DRONE stuck or blocked
```
LEADER monitors via agent-talk --status
  ↓
IF status = "needs-attention"
  → Prompt user for input
  → Send input to DRONE via agent-talk

IF status = "idle" for >30min
  → Check handoff document
  → If no handoff, assume stuck
  → Prompt user: retry/debug/skip task

IF handoff says "BLOCKED"
  → Mark task blocked
  → Notify user
  → Continue to next independent task (if any)
```

### MACHINE becomes unreachable
```
SSH connection lost
  ↓
MARK machine unreachable in state
  ↓
PAUSE project assigned to that machine
  ↓
NOTIFY user
  ↓
USER fixes (reconnect Morpheus, restart devpod)
  ↓
RESUME project
  ↓
DRONE may need to restart current task
```

### TASK fails (tests/lint)
```
DRONE reports FAILED in handoff
  ↓
LEADER reads handoff for details
  ↓
PROMPT user:
  1. Retry with same instructions
  2. Debug (show me the code/output)
  3. Skip task
  4. Cancel project
```

### Skill deficiency detected
```
LEADER sees DRONE using wrong tool (e.g., gh instead of arh)
  ↓
INTERVENE: Tell DRONE correct approach
  ↓
AFTER task completes:
  → Create/improve skill to prevent future occurrence
  → Commit to ~/.dotfiles/claude/skills
  → Note in project log for review
```

---

## Monitoring Strategy

### LEADER monitors all active DRONES

**Polling interval:** Every 30 seconds

**What to check:**
1. Morpheus session status (idle/working/needs-attention)
2. Time since last activity
3. Handoff document existence
4. Git branch/PR status

**Actions:**
```
IF status = "needs-attention"
  → Alert user, show what DRONE needs

IF status = "idle" AND handoff exists
  → Mark task completed
  → Read handoff
  → Verify PR created
  → Schedule next task

IF status = "working" for >45min on same thing
  → Check recent output (agent-talk --status)
  → If stuck in loop, alert user

IF status = "idle" AND no handoff AND >30min
  → Assume stuck or crashed
  → Alert user for intervention
```

---

## Success Metrics

**Per TASK:**
- Time to completion
- Number of interventions needed
- Test pass rate
- Lint errors

**Per PROJECT:**
- Total time from assignment to completion
- Number of tasks
- Number of blockers
- User interventions required
- Success rate

**Per MACHINE:**
- Uptime
- Tasks completed
- Average task time
- Failure rate

---

## Example: Full Project Flow

```
USER: assign-project "Add rate limiting to auth service"

LEADER:
  ✓ Project created: project-abc123
  ✓ Assigned machine: sth-go-1.devpod-nld (lowest available)
  ✓ Status: planning
  ⏳ Reading code at ~/Uber/go-code/src/.../auth/...
  
  [2 minutes of code analysis]
  
  ✓ Code analysis complete
  
  PLAN for "Add rate limiting to auth service":
  
  TASK 1: Add rate limiter dependency
    Files: go.mod, go.sum
    Branch: sth/auth-rate-limit/dependency
    Time estimate: 15 min
    Dependencies: None
    
  TASK 2: Implement rate limiter middleware  
    Files: middleware/rate_limit.go, middleware/rate_limit_test.go
    Branch: sth/auth-rate-limit/middleware
    Time estimate: 30 min
    Dependencies: TASK 1 (needs library)
    
  TASK 3: Integrate into auth service
    Files: server.go, config/config.go
    Branch: sth/auth-rate-limit/integration
    Time estimate: 20 min
    Dependencies: TASK 2 (needs middleware)
    
  Total estimated time: ~65 minutes
  
  Approve plan? (yes/edit/cancel)

USER: yes

LEADER:
  ✓ Plan approved
  ✓ Starting execution on sth-go-1.devpod-nld
  ✓ Launching DRONE for TASK 1...
  
  [Creates detailed task template with all info from code analysis]
  [Launches Morpheus session via deep link]
  
  ⏳ Monitoring drone-abc...
  
  [13 minutes later]
  
  ✓ TASK 1 completed
    Branch: sth/auth-rate-limit/dependency
    PR: #12345
    Status: SUCCESS
    
  ✓ Launching DRONE for TASK 2...
  ⏳ Monitoring drone-def...
  
  [28 minutes later]
  
  ⚠ DRONE status: needs-attention
  
  DRONE says: "Test failures in rate_limit_test.go - mock setup issue"
  
  Options:
  1. Send instructions to DRONE
  2. Show me the test failures
  3. Skip this task
  
  Choose (1-3):

USER: 2

LEADER:
  [Shows test output via agent-talk --status]
  
  I see the issue - mock clock not initialized.
  Should I tell DRONE to fix it? (yes/no)

USER: yes

LEADER:
  ✓ Sent: "Initialize mock clock in test setup - see examples in other_test.go"
  ⏳ Monitoring...
  
  [5 minutes later]
  
  ✓ TASK 2 completed
    Branch: sth/auth-rate-limit/middleware
    PR: #12346
    Status: SUCCESS
    
  ✓ Launching DRONE for TASK 3...
  ⏳ Monitoring drone-ghi...
  
  [18 minutes later]
  
  ✓ TASK 3 completed
    Branch: sth/auth-rate-limit/integration
    PR: #12347
    Status: SUCCESS
    
  ✓✓✓ PROJECT COMPLETED ✓✓✓
  
  Summary:
  - Project: Add rate limiting to auth service
  - Machine: sth-go-1.devpod-nld (now available)
  - Tasks: 3/3 completed
  - PRs created: #12345, #12346, #12347
  - Total time: 64 minutes
  - User interventions: 1 (test failure guidance)
  
  Stack of PRs ready for review:
  1. https://github.com/uber-code/go-code/pull/12345
  2. https://github.com/uber-code/go-code/pull/12346
  3. https://github.com/uber-code/go-code/pull/12347
```

---

## Future Enhancements

### Phase 2 Features
1. **Parallel tasks** - Run independent tasks simultaneously on same machine
2. **Multi-machine projects** - Spread large projects across machines
3. **Smart scheduling** - ML-based task time estimation
4. **Auto-retry** - Automatically retry failed tasks with different approaches
5. **Skill learning** - LEADER analyzes interventions, creates skills automatically

### Phase 3 Features
6. **Project templates** - Common patterns (refactor, new feature, bug fix)
7. **Cross-project dependencies** - Projects that depend on others
8. **Resource limits** - Cost caps, time limits per project
9. **Quality gates** - Auto-review before merging
10. **Metrics dashboard** - Web UI for monitoring

---

## Open Questions

1. **When DRONE asks LEADER questions?**
   - Current: DRONE should be autonomous, only block if truly stuck
   - Alternative: Allow DRONE to ask LEADER via special marker in output?

2. **How to handle mid-task plan changes?**
   - Current: User must cancel and reassign
   - Alternative: LEADER can replan on the fly?

3. **What if TASK takes much longer than estimated?**
   - Current: Just monitor, alert if >2x estimate
   - Alternative: Auto-pause and ask user to check?

4. **Should LEADER create the task template before or after DRONE launch?**
   - Current: Before (template ready when DRONE starts)
   - Alternative: Stream instructions as DRONE works?

5. **How to handle stack reordering?**
   - If TASK 2 needs to be done before TASK 1
   - Current: User edits plan
   - Alternative: LEADER auto-detects and reorders?

---

**End of Model Document**
