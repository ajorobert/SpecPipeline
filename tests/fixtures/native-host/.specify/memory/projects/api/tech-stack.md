# api — tech stack

## Versions
| Component | Version | Verified |
|---|---|---|
| .NET | 9.0.1 | 2026-09-21 against `src/backend/global.json` |

## Platform
server

## Test Layout
- unit: `src/backend/tests/*.UnitTests/**`
- integration: `src/backend/tests/*.IntegrationTests/**`
- contract: `src/backend/tests/Shop.Architecture.Tests/**` | none

## Test Runner
`dotnet test`

## Forbidden Skip Idioms
- `[Fact(Skip = ...)]`

## E2E Tooling
none

## Migrations
- Tool: EF Core
- Location: `src/backend/modules/{Module}/Shop.{Module}.Infrastructure/Persistence/Migrations/`
- Rollback: down migrations
- Tests: none
