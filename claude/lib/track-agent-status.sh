#!/bin/bash

# track-agent-status.sh - Sync agent status from Morpheus sessions.json
# Updates ~/.claude-agent-tracker/state.json with current status from Morpheus

STATE_FILE="$HOME/.claude-agent-tracker/state.json"
MORPHEUS_SESSIONS="$HOME/.claude/morpheus/sessions.json"

if [[ ! -f "$MORPHEUS_SESSIONS" ]]; then
  echo "Error: Morpheus sessions file not found at $MORPHEUS_SESSIONS"
  exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: Agent tracker state not found at $STATE_FILE"
  exit 1
fi

# Read current state
STATE=$(cat "$STATE_FILE")

# For each tracked agent, update status from Morpheus
UPDATED_STATE=$(echo "$STATE" | jq --slurpfile sessions "$MORPHEUS_SESSIONS" '
  .agents |= with_entries(
    .value.last_checked = now | todate |
    .value.last_status = (
      $sessions[0][] | 
      select(.id == .value.morpheus_session_id) | 
      .status
    ) // .value.last_status
  )
')

# Write updated state
echo "$UPDATED_STATE" | jq . > "$STATE_FILE"

echo "✓ Updated agent status from Morpheus"
