## Coding (go-code)
- Add comments to exported vars, consts, functions, etc
- Before coding task is finished, run "final checks": `arh test; arh lint` and fix all issues.
- When doing "final checks", ask if I want to ensure 100% unit test coverage coverage
- Use mcp and tools; do not guess.
- Plan thoroughly before every tool call.
- Ignore any assumptions; reason from facts only.

## Editing my Claude config (~/.claude)
The contents of `~/.claude/` are partially managed by my dotfiles repo via rcm
(see `~/.rcrc`, `DIRS="claude"`). Specifically, these subtrees are symlinks
into `~/.dotfiles/claude/`:

- `~/.claude/CLAUDE.md`       (this file)
- `~/.claude/agents/*.md`
- `~/.claude/skills/**`
- `~/.claude/commands/**`
- `~/.claude/keybindings.json`
- (any other file/dir mirrored under `~/.dotfiles/claude/`)

**ALWAYS edit the source path, not the symlink.** When asked to add or modify
a skill, agent, command, or anything that lives under one of the paths above,
write to `~/.dotfiles/claude/<...>` — never to `~/.claude/<...>` directly.
After editing, remind me to `cd ~/.dotfiles && git add … && git commit && git push`
so it syncs across machines.

If a target file doesn't exist yet under `~/.dotfiles/claude/` (e.g. first
skill, first command), create it there and run `rcup -f` to materialize the
symlink into `~/.claude/`.

DO NOT touch ephemeral runtime state under `~/.claude/` — `sessions/`,
`projects/`, `todos/`, `tasks/`, `plans/`, `history.jsonl`, `file-history/`,
`shell-snapshots/`, `cache/`, `paste-cache/`, `downloads/`, `backups/`,
`session-env/`, `ide/`, `statsig/`, `plugins/`, or `.credentials.json`.
Those are machine-local and not in the dotfiles repo.

## Testing
- When asked to "add test cases to the existing test", add entries inside the existing table-driven test — do not create a new test function.
- Always test from an exported component unless specified otherwise.
- Use t.Context() for context
- Common testing packages:  
  - "github.com/stretchr/testify/assert"
  - "github.com/stretchr/testify/require"
  - "go.uber.org/mock/gomock"
- Mocked entity pattern:
  - Real entity import: `servicepb "gogoproto/path/to/service"`
  - Mocked entity import" `servicemock "mock/gogoproto/path/to/service/servicemock"
- Use mockgen to mock Interfaces
  - mockgen path/to/thing Service
