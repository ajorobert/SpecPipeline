# Project Resolution
Framework-owned block, referenced by path from the per-project orchestrators (`sk.plan`,
`sk.implement`, `sk.test`) and from `sk.uat` / `sk.security-audit`.

## Source of truth
`unit-brief.md` → Impacted Projects table (written by `sk.story_sub_architect-probe`). Every row gives
`{Project}` (the exact name, never abbreviated), `{ProjectType}` (`Backend | Frontend | Mobile`),
`{CodeRoot}` and Role. The same names are used for `02-design/projects/{Project}.md`,
`03-plan/{Project}/`, `04-implementation/{Project}/` and `05-test/{Project}/`.

## `--projects {key}` selector
1. Exact match on the project Name (for example `--projects {Project}`).
2. Otherwise, a well-known alias against the row's Type / Role:
   - `api` | `backend`  → the row with Type = Backend
   - `web` | `customer` → the Frontend row whose Role mentions customer/portal
   - `admin`            → the Frontend row whose Role mentions admin
   - `mobile`           → the row with Type = Mobile
3. If `--role` is also given, it must agree with the row's Type (backend↔Backend,
   frontend↔Frontend, mobile↔Mobile). On conflict: STOP and report the mismatch.
4. If the selector matches zero rows or more than one: STOP and list the candidate projects.
5. Log: `Resolved --projects {key} → {Project} ({Type}, {CodeRoot})`.

The effective role for a resolved row is `backend` for Backend, `frontend` for Frontend and
`mobile` for Mobile.

## Per-project memory
The router `.specify/memory/projects/index.md` has one row per project: Project (link) · Type ·
Code Root · Role. `unit-brief.md` → Impacted Projects copies those values for the unit.

- **Tech stack:** `.specify/memory/projects/{Project}/tech-stack.md` — a dated snapshot. Each version
  line cites its manifest and the date it was verified (`verified 2026-09-21 against package.json`).
  It declares the test framework, **Test Layout** (where runnable tests live under `{CodeRoot}`),
  **Forbidden Skip Idioms** (the syntax that marks a test skipped or focused), **Platform**,
  **E2E Tooling**, optional **Coverage Thresholds**, and — for a project that owns a schema —
  **Migrations** (tool, location, rollback policy). Any field may be `none`; a skill that needs a
  `none` capability logs `SKIP — {field}: none` for that step and never invents a tool.
  A snapshot older than 90 days is refreshed from the manifests by sk.plan before use.
- **Coding rules:** the `.claude/rules/{stack}/` folders mapped to the project by `rules.stacks` in
  `.specify/profile.yaml` (default: Backend → `backend`, Frontend → `web`, Mobile → `mobile`).

Skills use these fields and never assume a language-specific layout.
