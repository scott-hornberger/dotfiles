---
name: find-service
description: Find a service directory in go-code on a devpod. Searches for service name, locates README, returns exact path and metadata for agent task creation.
---

# Find Service

Locate a service directory in go-code on a devpod, verify it exists, find its README, and return structured information for creating agent tasks.

## Prerequisites

- Morpheus app running with SSH connections to devpods
- Target devpod must be accessible
- Service exists in ~/go-code on the devpod

## Step 1: Identify target devpod

User provides or defaults to:
- **DevPod hostname** (e.g., `sth-go.devpod-nld`, `sth-go-2.devpod-nld`)
- Default to first available from `/tmp/morpheus-ssh-*` sockets

## Step 2: Get service name from user

Ask: **"What service are you looking for?"**

User might say:
- "continuous-deployment"
- "coconut"
- "starship"
- etc.

## Step 3: Find service directories

Search for directories matching the service name:

```bash
ssh -o ControlPath=/tmp/morpheus-ssh-sth@<hostname>:22 <hostname> \
  "find ~/go-code/src -type d -name '*<service-name>*' ! -path '*/.git/*' ! -path '*/.claude/*' 2>/dev/null | head -20"
```

Filter out:
- `.git` directories
- `.claude` worktrees
- `vendor` directories
- `node_modules` directories

## Step 4: Present options to user

If multiple matches found, show user:

```
Found multiple matches for "<service-name>":

1. ~/go-code/src/code.uber.internal/infra/coconut/continuous-deployment
2. ~/go-code/src/code.uber.internal/infra/coconut/operators/continuous-deployment
3. ~/go-code/src/code.uber.internal/config/starship/uml/continuous-deployment

Which one? (enter number or full path)
```

If only one match, auto-select it.

If no matches, report error and suggest checking service name.

## Step 5: Verify directory and find README

For selected directory:

```bash
ssh -o ControlPath=/tmp/morpheus-ssh-sth@<hostname>:22 <hostname> \
  "ls -la <service-path>/README* 2>/dev/null"
```

Capture:
- README.md location
- Last modified date
- File size

## Step 6: Get directory structure

Optional context for the agent:

```bash
ssh -o ControlPath=/tmp/morpheus-ssh-sth@<hostname>:22 <hostname> \
  "cd <service-path> && ls -la | head -20"
```

## Step 7: Return structured result

Format output as JSON-like structure for easy consumption:

```
Service Found: <service-name>
================

DevPod: <hostname>
Full Path: <full-path>
README: <readme-path> (last modified: <date>)

Project Root: ~/go-code
Relative Path: src/code.uber.internal/...

Contents:
  - README.md
  - main.go
  - pkg/
  - ...

Use this info to create agent tasks with exact paths.
```

## Step 8: Store in context

Optionally write to temp file for easy reference:

```bash
cat > /tmp/service-info-<service-name>.txt <<EOF
service_name: <service-name>
devpod: <hostname>
full_path: <full-path>
readme_path: <readme-path>
project_root: ~/go-code
EOF
```

## Error handling

- If Morpheus SSH socket not found: "No active Morpheus connection to <hostname>. Is Morpheus running?"
- If service not found: "No directories matching '<service-name>' in ~/go-code/src"
- If multiple matches and user doesn't pick: "Please select a directory from the list"
- If README not found: "Found service at <path> but no README file"

## Example usage

```
User: find continuous-deployment on sth-go
Assistant: [Searches via SSH]

Found service: continuous-deployment

DevPod: sth-go.devpod-nld
Full Path: /home/user/go-code/src/code.uber.internal/infra/coconut/continuous-deployment
README: /home/user/go-code/src/code.uber.internal/infra/coconut/continuous-deployment/README.md (4.8KB, modified Jul 7 2025)

Project Root: ~/go-code
Relative Path: src/code.uber.internal/infra/coconut/continuous-deployment

Ready to create agent tasks with this exact path.
```

## Integration with launch-agent

After finding service, use results to populate launch-agent task:

```
Task: Edit <service-name> README

File: <readme-path>
Working directory: <project-root>
```
