---
name: stop-agent
description: Stop a running Claude agent via Morpheus API. Closes the session, retrieves final state, removes from tracker.
---

# Stop Agent

Cleanly shut down a running Claude agent using Morpheus API.

## Prerequisites

Agent must be tracked in `~/.claude-agent-tracker/state.json` (launched via launch-agent skill).

## Step 1: Identify agent

User provides agent ID, e.g. `stop-agent auth-refactor`.

Read `~/.claude-agent-tracker/state.json` and find the agent entry. If not found, error with "Agent <id> not tracked. Use check-agents to see active agents."

## Step 2: Get session info from Morpheus

Query session details:

```bash
node ~/.dotfiles/claude/lib/morpheus-client.js get-sessions | jq '.[] | select(.id=="<session-id>")'
```

Show user:
- Final status
- Total cost
- Last activity

## Step 3: Ask for confirmation

```
Agent "<agent-id>" status:
  Status: <status>
  Cost: $X.XX
  Last active: X minutes ago
  
Stop this agent? (yes/no)
```

## Step 4: Close session via Morpheus

If user confirms:

```bash
node ~/.dotfiles/claude/lib/morpheus-client.js close-session '<session-id>'
```

Morpheus will:
- Terminate the tmux session
- Clean up the remote state
- Mark session as disconnected

## Step 5: Remove from local tracker

Remove agent from `~/.claude-agent-tracker/state.json`.

Optionally save history:

```json
{
  "stopped_at": "<timestamp>",
  "final_status": "<status>",
  "session_id": "<session-id>"
}
```

Write to `~/.claude-agent-tracker/history/<agent-id>.json`.

## Step 6: Report completion

```
✓ Agent "<agent-id>" stopped
  Final status: <status>
  Total cost: $X.XX
  Session closed in Morpheus
```

## Error handling

- If session not found: "Agent not in Morpheus. May have already stopped."
- If Morpheus not responding: "Cannot reach Morpheus. Is it running?"
- If user says no: "Stop cancelled."
- If close fails: Show error, offer force-remove from tracker
