---
name: launch-agent
description: Launch a Claude agent on a remote devpod via Morpheus API. Creates a Claude Code session with task instructions, monitors via Morpheus WebSocket, tracks state locally.
---

# Launch Agent

Launch a Claude agent on a remote devpod to work autonomously on a task. Uses Morpheus API to create and manage the session.

## Prerequisites

- Morpheus app running locally
- Morpheus engine server running (check with `curl http://localhost:3100/health`)
- Target devpod accessible (check with Morpheus devpod list)
- `claude` CLI installed on the remote devpod

## Step 1: Gather task information from user

Ask the user for:
1. **DevPod hostname** - e.g. `sth-go.devpod-nld`, `sth-go-2.devpod-nld` (auto-suggest from available devpods)
2. **Agent ID** - unique identifier for this agent (e.g. `auth-feature`, `payments-refactor`)
3. **Task description** - what should the agent do?
4. **Git repo path** - where is the code on the remote? (default: `~/go-code`)
5. **Base branch** - branch to start from (default: `main`)

## Step 2: Check Morpheus is running

```bash
curl -s http://localhost:3100/health
```

If this fails, tell user to start Morpheus app first.

## Step 3: Get available devpods

Use the morpheus-client helper to list devpods:

```bash
node ~/.dotfiles/claude/lib/morpheus-client.js get-devpods
```

Show user available devpods and confirm their choice exists.

## Step 4: Create task prompt

Build the initial prompt:

```
# Task: <agent-id>

<user's task description>

## Agent Instructions

You are running autonomously on devpod <hostname>. Follow these protocols:

1. **Handoff Document**: Before completing, create handoff.md with:
   - What you accomplished  
   - Current state
   - What's next
   - Blockers/questions
   - Branch names and SHAs

2. **Branching**: Create feature branches following: <username>/feature-name

3. **Commits**: Commit frequently with clear messages

4. **Push**: Push branches to origin when ready

Repository: <repo-path>
Base branch: <base-branch>

Start by: cd <repo-path> && git fetch && git checkout <base-branch> && git pull
```

## Step 5: Create Morpheus session

```bash
node ~/.dotfiles/claude/lib/morpheus-client.js create-session '{
  "project": "<repo-path>",
  "host": {"type": "remote", "hostname": "<hostname>"},
  "initialPrompt": "<task-prompt>",
  "name": "Agent: <agent-id>"
}'
```

Capture the session ID from response.

## Step 6: Update local tracker

Add to `~/.claude-agent-tracker/state.json`:

```json
{
  "agents": {
    "<agent-id>": {
      "morpheus_session_id": "<session-id>",
      "hostname": "<hostname>",
      "repo_path": "<repo-path>",
      "launched_at": "<timestamp>"
    }
  }
}
```

## Step 7: Report to user

```
✓ Agent "<agent-id>" launched on <hostname>
  Morpheus session: <session-id>
  Status: <status>
  
View in Morpheus app or use check-agents to monitor.
```

## Error handling

- If Morpheus not running: "Start Morpheus app first"
- If devpod not found: "DevPod not available. Available: <list>"
- If session creation fails: Show error from Morpheus
