---
name: view-agent-output
description: View the terminal output of a running or completed agent session. Captures tmux pane output via SSH or opens the session in Morpheus.
---

# View Agent Output

View what an agent has done by reading its terminal output or opening it in Morpheus.

## Prerequisites

- Agent tracked in ~/.claude-agent-tracker/state.json
- Morpheus app running
- SSH access to devpod

## Step 1: Get agent info

User provides agent ID, e.g. `view-agent-output test-readme-edit-v2`

Read `~/.claude-agent-tracker/state.json` to get:
- `morpheus_session_id`
- `hostname`  

Get tmux session name from Morpheus:
```bash
cat ~/.claude/morpheus/sessions.json | jq -r '.[] | select(.id=="<session-id>") | .tmuxSessionName'
```

## Step 2: Choose viewing method

Ask user or default to option 1:
```
How do you want to view the output?
1. Show last 100 lines in terminal
2. Open in Morpheus app
3. Attach via SSH (interactive)
```

## Step 3a: Show in terminal (option 1)

Capture last 100 lines from tmux:

```bash
TMUX_SESSION=$(cat ~/.claude/morpheus/sessions.json | jq -r '.[] | select(.id=="<session-id>") | .tmuxSessionName')
ssh -o ControlPath=/tmp/morpheus-ssh-sth@<hostname>:22 <hostname> \
  "tmux capture-pane -t $TMUX_SESSION -p -S -100"
```

Display output.

## Step 3b: Open in Morpheus (option 2)

Focus the session in Morpheus app:

```bash
open "morpheus://focus-session?id=<session-id>"
```

This brings Morpheus to foreground and shows the full session.

## Step 3c: Attach via SSH (option 3)

Give user the command to attach interactively:

```bash
ssh <hostname> -t 'tmux attach -t <tmux-session>'
```

## Step 4: Parse for key information

Look for in output:
- Error messages
- Git commands (branches, commits)
- "handoff.md" mentions
- Success/failure indicators

Summarize:

```
Agent: test-readme-edit-v2
Status: idle

Last activity:
  Created branch: sth/continuous-deployment/test-readme
  Committed: abc1234
  Output shows: task completed
```

## Error handling

- If tmux session not found: "Session ended. Open in Morpheus to view history."
- If SSH fails: "Cannot connect to <hostname>."
- If session ID not in tracker: "Unknown agent. Use check-agents to list."
