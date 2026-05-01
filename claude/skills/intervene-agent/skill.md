---
name: intervene-agent
description: Send new instructions to a running Claude agent via Morpheus API. Uses sendTerminalInput to inject prompts into the session.
---

# Intervene Agent

Send new instructions or corrections to a running agent. This uses Morpheus to send input directly into the agent's terminal.

## Prerequisites

Agent must be tracked in `~/.claude-agent-tracker/state.json` (launched via launch-agent skill).

## Step 1: Identify agent

User provides agent ID, e.g. `intervene-agent auth-refactor`.

Read `~/.claude-agent-tracker/state.json` and find the agent entry. If not found, error with "Agent <id> not tracked. Use check-agents to see active agents."

## Step 2: Look up session in Morpheus

Use the morpheus_session_id from state.json to get current session info:

```bash
node ~/.dotfiles/claude/lib/morpheus-client.js get-sessions | jq '.[] | select(.id=="<session-id>")'
```

Show user:
- Current status
- Last activity
- Cost so far

## Step 3: Get intervention instructions

Ask user: "What new instructions should I send to the agent?"

User might say:
- "Tell it to skip the migration and focus on the API"
- "Ask it to fix test failures first"
- "Change approach: use library X"
- "It's stuck, tell it to move on"

## Step 4: Send input to session

Format the intervention as a clear prompt and send via Morpheus:

```bash
echo '<user-message>' | node -e '
const { MorpheusClient } = require(process.env.HOME + "/.dotfiles/claude/lib/morpheus-client.js");
const client = new MorpheusClient();

(async () => {
  await client.connect();
  const input = require("fs").readFileSync(0, "utf-8");
  await client.sendTerminalInput("<session-id>", input + "\n");
  client.close();
})();
'
```

The agent will see this as new user input in its terminal.

## Step 5: Confirm delivery

Report to user:
```
✓ Instructions sent to agent "<agent-id>"
  Session: <session-id>
  
The agent will receive your message and respond.
Use check-agents to monitor progress.
```

## Error handling

- If session not found in Morpheus: "Session not active. Agent may have stopped."
- If Morpheus not responding: "Cannot reach Morpheus. Is it running?"
- If send fails: Show error from Morpheus API