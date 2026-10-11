# {Project} — commands and layout
What the pipeline runs for this project. Versions live in the manifests; a change of component choice is
an ADR. Any field may be `none` — a command that needs it logs `SKIP — {field}: none` and never invents a tool.

## Platform
{server | browser | native iOS/Android | …}

## Commands
- Build: `{command | none}`
- Test: `{command | none}`
- Lint: `{command | none}`
- Typecheck: `{command | none}`

## Test Layout
<!-- Where runnable tests live under the code root, per kind. -->
- unit: `{path pattern}`
- integration: `{path pattern}`
- contract: `{provider path pattern}` | `{consumer path pattern}`
- component: `{path pattern}`
- e2e: `{path pattern | none}`

## Test Runner
{the framework the Test command runs | none}

## Forbidden Skip Idioms
<!-- Syntax that skips or focuses a test. A suite using one without a documented reason fails. -->
- `{…}`

## E2E Tooling
{tool | none}

## Coverage Thresholds
{e.g. line 80% for domain code | none}

## Migrations
<!-- Only for a project that owns a schema. -->
- Tool: {…}
- Location: `{path pattern}`
- Rollback: {forward-only | down migrations | …}
- Tests: {required | none}
