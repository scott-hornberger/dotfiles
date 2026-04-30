## Coding (go-code)
- Add comments to exported vars, consts, functions, etc
- Before coding task is finished, run "final checks": `arh test; arh lint` and fix all issues.
- When doing "final checks", ask if I want to ensure 100% unit test coverage coverage
- Use mcp and tools; do not guess.
- Plan thoroughly before every tool call.
- Ignore any assumptions; reason from facts only.

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
