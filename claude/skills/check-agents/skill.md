---
name: check-agents
description: Check status of all running Claude agents. Reads ~/.claude-agent-tracker/state.json and queries Morpheus API for current session status.
---

# Check Agents

Poll all running Claude agents to see their current status via Morpheus API.

## Step 1: Sync status from Morpheus

Run the tracker sync script to update local state with latest Morpheus status:

```bash
~/.dotfiles/claude/lib/track-agent-status.sh
```

Then read `~/.claude-agent-tracker/state.json` to get list of tracked agents.

If no agents exist, report "No agents currently tracked" and exit.

## Step 2: Format status report

For each agent in state.json, display:

```
Agent Status Report
===================

test-readme-edit-v2
  Task: Edit continuous-deployment README - add test section
  Status: idle
  DevPod: sth-go.devpod-nld
  Service: continuous-deployment
  Launched: 2026-05-01 10:52:00
  Session ID: a9239f9a-8332-4cdc-9b73-5b804e0d24b0

---
1 agent tracked
```

## Step 3: Highlight issues

If any agent:
- Status is "idle" → may have completed or stopped
- Status is "needs-attention" → requires user input
- Status is "disconnected" → session ended
- Status is "unreachable" → devpod is down
- Status is "working" → actively processing

## Step 4: Error handling

- If track-agent-status.sh fails: "Cannot sync status. Is Morpheus running?"
- If state.json missing: "No agents tracked. Use launch-agent to start one."
- If state.json malformed: Report error, suggest manual fix
