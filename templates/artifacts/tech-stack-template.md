# {Project} — tech stack
A dated snapshot, not a policy. Changing a choice needs an ADR; refreshing a version does not.
Any field may be `none`.

## Versions
| Component | Version | Verified |
|---|---|---|
| {runtime / framework / library} | {x.y.z} | {date} against `{manifest path}` |

## Platform
{server | browser | native iOS/Android | …}

## Test Layout
<!-- Where runnable tests live under the code root, per kind. -->
- unit: `{path pattern}`
- integration: `{path pattern}`
- contract: `{provider path pattern}` | `{consumer path pattern}`
- component: `{path pattern}`
- e2e: `{path pattern | none}`

## Test Runner
{command, e.g. `dotnet test` | `pnpm test` | none}

## Forbidden Skip Idioms
<!-- Syntax that skips or focuses a test in this stack. A suite using one without a documented reason fails. -->
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
- Test location: `{path pattern | none}`
