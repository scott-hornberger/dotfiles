# Implementation Handoff: LEADER-DRONE Orchestration System

**Date:** 2026-05-01  
**To:** Next Agent (implementation DRONE)  
**From:** Claude (current LEADER design session)  
**Task:** Build the LEADER-DRONE orchestration system per ORCHESTRATOR_MODEL.md

---

## Objective

Implement the complete LEADER-DRONE orchestration system that enables a local Claude (LEADER) to manage autonomous Claude agents (DRONES) across multiple remote machines (sth-go-[1..N].devpod-nld) to execute multi-task PROJECTS.

---

## Prerequisites

**Before starting:**
1. Read `~/.dotfiles/claude/ORCHESTRATOR_MODEL.md` completely
2. User will update Claude CLI (you'll have latest features)
3. User has ~/Uber/go-code cloned locally (LEADER needs this to read code)
4. Morpheus app is running with connections to devpods
5. Machine sth-go.devpod-nld is reserved for USER - NEVER use

---

## What Exists Already

### Current Infrastructure (built today)
```
~/.dotfiles/claude/skills/
  find-service/           # Find services in go-code remotely (may need to be replaced, as we can do it locally after clone)
  launch-agent/           # Launch agents (needs updating for new model)
  check-agents/           # Check agent status (needs updating)
  intervene-agent/        # Send messages to agents
  stop-agent/             # Stop agents
  view-agent-output/      # View agent output

~/.dotfiles/claude/lib/
  morpheus-client.js      # WebSocket client (for standalone server)
  track-agent-status.sh   # Sync status from Morpheus
  agent-talk              # CLI for talking to agents

~/.claude-agent-tracker/
  state.json              # Current agent tracking (needs migration)

~/.claude/morpheus/
  sessions.json           # Morpheus session data

~/.dotfiles/claude/
  ORCHESTRATOR_MODEL.md   # Full specification
  HANDOFF.md              # Context from today's work
  CLAUDE.md               # Existing repo conventions
```

### Other
Morpheus code base at ~/Uber/non-production/morpheus

### What Needs to Change

**Migrate from:** Agent-centric tracking (track individual agents)  
**Migrate to:** Project-centric orchestration (track projects containing tasks)

---

## Implementation Plan

### Phase 1: Core Infrastructure (Priority 1)

#### 1.1 State Management
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/state-manager.sh`

**Responsibilities:**
- Initialize `~/.claude-orchestrator/state.json`
- CRUD operations for machines, projects, tasks
- State validation and repair

**State schema:** See ORCHESTRATOR_MODEL.md section "State Schema"

**Key functions:**
```bash
# Machine management
register-machine <hostname>              # Add machine to pool
unregister-machine <hostname>           # Remove machine
get-available-machines                  # List available machines
assign-machine-to-project <project-id>  # Round-robin assignment

# Project management
create-project <name> <description>     # Create new project
update-project-status <id> <status>     # Update status
get-project <id>                        # Get project details
list-projects <filter>                  # List projects by status

# Task management
add-task <project-id> <task-data>       # Add task to project
update-task-status <project-id> <task-id> <status>
get-next-task <project-id>              # Get next unblocked task
```

#### 1.2 Machine Pool Management
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/machine-pool`

**Responsibilities:**
- Discover available machines from Morpheus
- Health check machines (SSH connectivity)
- Assignment algorithm (round-robin, lowest number)
- **CRITICAL:** Filter out sth-go.devpod-nld (user's machine)

**Algorithm from model:**
```python
def assign_machine(projects, machines):
    available = [m for m in machines 
                 if m.status == "available" 
                 and m.name != "sth-go.devpod-nld"]
    if not available:
        return "REQUEST_MORE_MACHINES"
    available.sort(key=lambda m: int(m.name.split('-')[-1].split('.')[0]))
    return available[0]
```

#### 1.3 Project Assignment
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/assign-project`

**User interface:**
```bash
assign-project "Add rate limiting to auth service"
```

**Flow:**
1. Create project in state with status "planning"
2. Assign machine (via machine-pool)
3. If no machines available, output "REQUEST MORE MACHINES"
4. Return project ID for next steps

---

### Phase 2: Planning (Priority 1)

#### 2.1 Code Analysis
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/analyze-code`
- `~/.dotfiles/claude/skills/orchestrator/code-analysis`

**Requirements:**
- Access ~/Uber/go-code (local clone)
- Find relevant files for project
- Understand current implementation
- Identify dependencies
- Output structured analysis

**Output format:**
```markdown
# Code Analysis: <project-name>

## Files Located
- Primary: src/code.uber.internal/auth/server.go
- Related: src/code.uber.internal/auth/middleware/

## Current Implementation
<Summary of what exists>

## Dependencies
- Package X used for Y
- Service Z needs to be updated

## Recommended Approach
<High-level strategy>
```

**Save to:** `~/.claude-orchestrator/projects/<project-id>/code-analysis.md`

#### 2.2 Plan Generation
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/plan-project`
- `~/.dotfiles/claude/skills/orchestrator/task-breakdown`

**User interface:**
```bash
plan-project <project-id>
```

**Flow:**
1. Read code-analysis.md
2. Break down into discrete TASKS
3. Identify dependencies between tasks
4. Estimate time per task
5. Generate plan.md
6. Update state.json with tasks array
7. Show plan to user for approval

**Plan format:** See ORCHESTRATOR_MODEL.md "LEADER Workflow" section

**User approval flow:**
```
Show plan → User: yes/edit/cancel
  yes → proceed to execution
  edit → user modifies, resubmit
  cancel → mark project cancelled
```

---

### Phase 3: Execution (Priority 1)

#### 3.1 Task Scheduling
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/schedule-task`

**Responsibilities:**
- Check task dependencies met
- Generate task template from plan
- Launch DRONE via Morpheus deep link
- Record drone session ID in state

**Task template:** See ORCHESTRATOR_MODEL.md "TASK Template" section

**Deep link format:**
```bash
open "morpheus://create-session?project=/home/user/go-code&host=<hostname>&prompt=<url-encoded-task-template>&name=DRONE: <project>/<task-id>"
```

#### 3.2 Project Execution
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/execute-project`

**User interface:**
```bash
execute-project <project-id>
```

**Flow:**
```python
while has_tasks_remaining:
    next_task = get_next_task(project)  # Respects dependencies
    if next_task is None:
        break  # All remaining tasks blocked
    
    schedule_task(project, next_task)
    monitor_task(next_task)
    
    if task_completed:
        collect_handoff(next_task)
        verify_pr_created(next_task)
        continue
    elif task_blocked:
        mark_blocked(next_task)
        continue
    elif task_needs_attention:
        prompt_user(next_task)
        wait_for_input()
```

#### 3.3 Monitoring
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/monitor-projects`
- `~/.dotfiles/claude/lib/orchestrator/check-drone-status`

**Polling strategy:**
- Check every 30 seconds
- Use existing `agent-talk --status` under the hood
- Read `~/.claude/morpheus/sessions.json` for status
- Check for handoff document existence

**Status detection:**
```bash
# Via Morpheus sessions.json
status = "idle|working|needs-attention|disconnected"

# Check handoff
if [ -f ~/go-code/handoff-<task-id>.md ]; then
  # Task completed, read handoff
fi

# Check stuck
if status == "working" && time_elapsed > 45min; then
  alert_user "Task may be stuck"
fi
```

#### 3.4 Handoff Collection
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/collect-handoff`

**Responsibilities:**
- SSH to machine
- Read `~/go-code/handoff-<task-id>.md`
- Parse for: branch, PR number, status, issues
- Copy to `~/.claude-orchestrator/projects/<project>/tasks/task-<id>-handoff.md`
- Update task in state.json

**Expected handoff format (DRONE creates this):**
```markdown
# Handoff: <task-id>

**Status:** SUCCESS|BLOCKED

## Accomplished
- Created branch: sth/project/task-name
- Modified files: file1.go, file2.go
- Committed: SHA abc123

## Deliverables
- Branch: sth/project/task-name
- PR: #12345
- Tests: passing
- Lint: clean

## Issues
<any problems encountered>

## For Next Task
<context for LEADER>
```

---

### Phase 4: User Interface (Priority 2)

#### 4.1 Status Commands
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/status`
- `~/.dotfiles/claude/lib/orchestrator/show-projects`
- `~/.dotfiles/claude/lib/orchestrator/show-project`

**Commands:**
```bash
status
# Output:
#   Machines: 3 total (2 busy, 1 available)
#   Projects: 2 active, 5 completed
#   Active drones: 2

show-projects
# Output:
#   project-abc  [in-progress]  sth-go-1  "Add rate limiting" (2/3 tasks done)
#   project-def  [planning]     sth-go-2  "Refactor auth" (analyzing...)

show-project <project-id>
# Show detailed project status, all tasks, PRs
```

#### 4.2 Control Commands
**Files to create:**
- `~/.dotfiles/claude/lib/orchestrator/pause-project`
- `~/.dotfiles/claude/lib/orchestrator/resume-project`
- `~/.dotfiles/claude/lib/orchestrator/cancel-project`

**Pause:** Mark project paused, don't schedule new tasks  
**Resume:** Continue from where left off  
**Cancel:** Mark cancelled, stop all drones, free machine

---

## Migration Strategy

### From Current System to New System

**Current state:**
```json
{
  "agents": {
    "test-readme-edit-v2": { ... }
  }
}
```

**New state:**
```json
{
  "machines": { ... },
  "projects": { ... }
}
```

**Migration script:**
- Rename `~/.claude-agent-tracker/` to `~/.claude-agent-tracker.old/`
- Create new `~/.claude-orchestrator/`
- Keep old system for reference but don't use

---

## Testing Strategy

### Test 1: Simple Single-Task Project
```bash
assign-project "Add test section to README of continuous-deployment service"
# Should create 1-task project
plan-project <id>
# Should show simple plan
execute-project <id>
# Should complete successfully
```

### Test 2: Multi-Task Project with Dependencies
```bash
assign-project "Add rate limiting to auth service"
# Should create 3-task project (dependency, middleware, integration)
plan-project <id>
# Should show tasks with dependencies
execute-project <id>
# Should execute tasks in order, wait for dependencies
```

### Test 3: Blocked Task Handling
```
# Create project that will encounter test failures
# Verify LEADER prompts user
# Verify can send instructions to DRONE
# Verify task completes after intervention
```

### Test 4: Machine Pool Management
```bash
# Start with 0 machines registered
assign-project "Task 1"
# Should request machines
register-machine sth-go-1.devpod-nld
assign-project "Task 2"
# Should use sth-go-1
register-machine sth-go-2.devpod-nld
assign-project "Task 3"
# Should use sth-go-2 (round-robin)
```

---

## Success Criteria

**Phase 1 Complete:**
- [ ] State management works (CRUD for machines/projects/tasks)
- [ ] Machine pool correctly assigns, filters out sth-go.devpod-nld
- [ ] Can assign projects and track in state

**Phase 2 Complete:**
- [ ] Can read code from ~/Uber/go-code
- [ ] Generates sensible task breakdown
- [ ] User can approve/edit plans

**Phase 3 Complete:**
- [ ] Can launch DRONE with task template
- [ ] Monitors DRONE status
- [ ] Collects handoffs
- [ ] Executes tasks in dependency order
- [ ] Full project completes end-to-end

**Phase 4 Complete:**
- [ ] Clean CLI interface
- [ ] Status commands work
- [ ] Can pause/resume/cancel

**System Complete:**
- [ ] All tests pass
- [ ] Skills updated/created as needed
- [ ] Documentation complete
- [ ] Handoff written for next LEADER

---

## Critical Implementation Notes

### 1. Machine Filtering
**ALWAYS filter out sth-go.devpod-nld**
```bash
# Wrong
machines=($(ls /tmp/morpheus-ssh-*))

# Right
machines=($(ls /tmp/morpheus-ssh-* | grep -v "sth-go\.devpod-nld"))
```

### 2. DRONE Autonomy
**Do NOT micromanage DRONES in task templates**
```markdown
# Wrong
1. Run: cd ~/go-code
2. Run: git checkout main
3. Run: git pull
4. Run: git checkout -b sth/branch

# Right  
1. Create branch sth/project/task-name from latest main
2. Implement rate limiter in middleware/rate_limit.go
3. Use arh for all git operations
```

DRONES have skills - they know how to do things.

### 3. Error Recovery
**Every operation should be resumable**
- If LEADER crashes mid-project, should be able to resume
- State.json is source of truth
- Check state before every operation

### 4. SSH Socket Paths
**Use Morpheus control sockets:**
```bash
ssh -o ControlPath=/tmp/morpheus-ssh-sth@${hostname}:22 ${hostname} "command"
```

Not bare SSH (will prompt for auth).

### 5. Deep Link Prompt Encoding
**URL encode task templates:**
```bash
URL_ENCODED=$(node -e "console.log(encodeURIComponent(process.argv[1]))" "$TASK_TEMPLATE")
open "morpheus://create-session?prompt=${URL_ENCODED}..."
```

### 6. Handoff Document Location
**DRONE creates on remote:**
```
~/go-code/handoff-<task-id>.md
```

**LEADER copies to local:**
```
~/.claude-orchestrator/projects/<project>/tasks/<task-id>-handoff.md
```

---

## Files to Create (Complete List)

### State & Core
```
~/.dotfiles/claude/lib/orchestrator/
  state-manager.sh                # State CRUD operations
  machine-pool                    # Machine management
  assign-project                  # User assigns project
  
~/.claude-orchestrator/
  state.json                      # Master state
```

### Planning
```
~/.dotfiles/claude/lib/orchestrator/
  analyze-code                    # Read ~/Uber/go-code
  plan-project                    # Generate task breakdown
  
~/.dotfiles/claude/skills/orchestrator/
  code-analysis/skill.md          # Skill for code analysis
  task-breakdown/skill.md         # Skill for task planning
```

### Execution
```
~/.dotfiles/claude/lib/orchestrator/
  execute-project                 # Main execution loop
  schedule-task                   # Launch DRONE
  monitor-projects                # Poll DRONE status
  collect-handoff                 # Retrieve handoff docs
  check-drone-status              # Check individual DRONE
```

### User Interface
```
~/.dotfiles/claude/lib/orchestrator/
  status                          # Overall system status
  show-projects                   # List projects
  show-project                    # Show project details
  pause-project                   # Pause project
  resume-project                  # Resume project
  cancel-project                  # Cancel project
  list-machines                   # Show machine pool
```

### Skills (new/updated)
```
~/.dotfiles/claude/skills/orchestrator/
  code-analysis/skill.md
  task-breakdown/skill.md
  drone-task/skill.md             # Template for DRONE tasks
```

---

## Dependencies & Prerequisites

**Bash/tools needed:**
- jq (JSON processing)
- curl (if needed for API calls)
- ssh (with Morpheus control sockets)
- git (for reading ~/Uber/go-code)

**File access:**
- ~/Uber/go-code (must exist, LEADER reads)
- ~/.dotfiles/claude/ (LEADER writes skills)
- ~/.claude/morpheus/sessions.json (LEADER reads)
- /tmp/morpheus-ssh-* (SSH control sockets)

**Morpheus:**
- Desktop app running
- Connected to sth-go-[1..N].devpod-nld machines
- Deep link support working

---

## Example Usage (After Implementation)

```bash
# User assigns project
assign-project "Add rate limiting to auth service"
# Output: Created project-abc123, assigned to sth-go-1

# LEADER plans
plan-project project-abc123
# Output: Shows 3-task plan, asks approval

# User approves
# Input: yes

# LEADER executes
execute-project project-abc123
# Output: Launching DRONE for task 1...
#         [monitoring updates...]
#         Task 1 complete, PR #12345
#         Launching DRONE for task 2...
#         [etc...]

# User checks status
status
# Output: 1 project active, task 2/3 in progress

# Project completes
# Output: PROJECT COMPLETED
#         3 PRs: #12345, #12346, #12347
#         Machine sth-go-1 now available
```

---

## Questions to Resolve During Implementation

1. **Task template generation:** Fully automated or show to user first?
   - Recommendation: Automated, user can inspect via `show-project`

2. **Handoff polling:** How often to check for handoff documents?
   - Recommendation: Every 30s, same as status polling

3. **DRONE session naming:** Format for Morpheus session names?
   - Recommendation: `DRONE: <project-name>/<task-id>`

4. **Project ID format:** UUIDs or readable names?
   - Recommendation: Short UUIDs (8 chars) for easy typing

5. **Code analysis depth:** How much code should LEADER read?
   - Recommendation: Start simple, improve based on plan quality

---

## Handoff for Next Implementation

After implementing, create handoff with:
- What works
- What's incomplete
- Known issues
- How to test
- How to extend
- Skill improvements needed

---

**End of Implementation Handoff**

You have everything needed to build this system. Follow the phases in order, test incrementally, and improve skills as you discover DRONE deficiencies. Good luck!
