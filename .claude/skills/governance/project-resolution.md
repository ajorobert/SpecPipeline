# Project Resolution
Framework-owned block, referenced by path from the per-project orchestrators (`sk.plan`,
`sk.implement`, `sk.test`) and from `sk.uat` / `sk.security-audit`.

## Source of truth
`unit-brief.md` → Impacted Projects table (written by `sk.architect-probe`). Every row gives
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
Resolve each project's stack memory in this order (first existing file wins):
- Tech stack: `.specify/memory/projects/{Project}/tech-stack.md` → `.specify/memory/standards/tech-stack.md`
- Coding standards: `.specify/memory/projects/{Project}/coding-standards.md` → `.specify/memory/standards/coding-standards.md`

The tech stack declares the project's test framework, **Test Layout** (where runnable tests live
under `{CodeRoot}`) and **Forbidden Skip Idioms** (the syntax that marks a test skipped or focused).
Skills use those fields and never assume a language-specific layout.
