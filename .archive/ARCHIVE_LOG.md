# Archive Log

Files here were moved from the project by an AI agent and require human review
before permanent deletion. Do **not** delete entries from this log — mark them
approved and let a human run the cleanup.

## How to permanently delete a reviewed file

1. Open this file
2. Find the entry and check the review box: `[x] approved for permanent delete`
3. Run: `rm .archive/<date>/<filename>`
4. Remove the entry from this log

---

<!-- Archived files appear below, newest first -->





## 2026-04-17 — .claude/hooks/post-command.md
**Reason:** Superseded by post-skill.sh — logic is now wired as a real PostToolUse hook in settings.json
**Original path:** .claude/hooks/post-command.md
**Archived to:** .archive/2026-04-17/post-command.md
**Review:** [ ] approved for permanent delete

## 2026-04-19 — .claude/skills/sk.architecture/SKILL.md
**Reason:** moved to sk.design/sk.architecture/ — now internal sub-skill
**Original path:** .claude/skills/sk.architecture/SKILL.md
**Archived to:** .archive/2026-04-19/SKILL.md
**Review:** [ ] approved for permanent delete

## 2026-04-19 — .claude/skills/sk.architecture/prompt.md
**Reason:** moved to sk.design/sk.architecture/ — now internal sub-skill
**Original path:** .claude/skills/sk.architecture/prompt.md
**Archived to:** .archive/2026-04-19/prompt.md
**Review:** [ ] approved for permanent delete

## 2026-04-19 — .claude/skills/sk.datamodel/SKILL.md
**Reason:** moved to sk.design/sk.datamodel/ — now internal sub-skill
**Original path:** .claude/skills/sk.datamodel/SKILL.md
**Archived to:** .archive/2026-04-19/SKILL.md-121106
**Review:** [ ] approved for permanent delete

## 2026-04-19 — .claude/skills/sk.datamodel/prompt.md
**Reason:** moved to sk.design/sk.datamodel/ — now internal sub-skill
**Original path:** .claude/skills/sk.datamodel/prompt.md
**Archived to:** .archive/2026-04-19/prompt.md-121107
**Review:** [ ] approved for permanent delete

## 2026-04-19 — .claude/skills/sk.contracts/SKILL.md
**Reason:** moved to sk.design/sk.contracts/ — now internal sub-skill
**Original path:** .claude/skills/sk.contracts/SKILL.md
**Archived to:** .archive/2026-04-19/SKILL.md-121107
**Review:** [ ] approved for permanent delete

## 2026-04-19 — .claude/skills/sk.contracts/prompt.md
**Reason:** moved to sk.design/sk.contracts/ — now internal sub-skill
**Original path:** .claude/skills/sk.contracts/prompt.md
**Archived to:** .archive/2026-04-19/prompt.md-121108
**Review:** [ ] approved for permanent delete

## 2026-04-24 — .claude/skills/governance/sdlc-flow.md
**Reason:** Orphan: no SKILL.md injects it, no prompt.md reads it. Content is human-only doc duplicating CLAUDE.md + subagent_type frontmatter. Removed during P2a cleanup (2026-04-24).
**Original path:** .claude/skills/governance/sdlc-flow.md
**Archived to:** .archive/2026-04-24/sdlc-flow.md
**Review:** [ ] approved for permanent delete

## 2026-04-24 — .claude/skills/governance/roles.md
**Reason:** Orphan: no SKILL.md injects it, no prompt.md or agent definition reads it. Role ownership is encoded in subagent_type frontmatter at runtime. Removed during P2a cleanup (2026-04-24).
**Original path:** .claude/skills/governance/roles.md
**Archived to:** .archive/2026-04-24/roles.md
**Review:** [ ] approved for permanent delete

## 2026-04-24 — .claude/skills/governance/SKILL.md
**Reason:** Orphan: no sk.* skill injects it; content is just a folder index pointing to checkpoint-rules.md and quality-gates.md which skills inject directly. Kept only the skill-list discovery entry, which was misleading (governance isn't a standalone skill). Removed during P2a Bucket A cleanup (2026-04-24).
**Original path:** .claude/skills/governance/SKILL.md
**Archived to:** .archive/2026-04-24/SKILL.md
**Review:** [ ] approved for permanent delete

## 2026-04-29 — .claude/skills/observability-patterns/SKILL.md
**Reason:** Split into observability-{contracts,backend,frontend,infra} on 2026-04-29 — original was approaching 1000 lines, causing context bloat for backend-only and frontend-only agents. Replaced by four focused skills with observability-contracts holding the shared seams (resource attrs, runtime-config JSON shape, PII deny-list, Loki label allow-list, span naming, trace propagation rules).
**Original path:** .claude/skills/observability-patterns/SKILL.md
**Archived to:** .archive/2026-04-29/SKILL.md
**Review:** [ ] approved for permanent delete

## 2026-05-17 — .claude/skills/observability-patterns/
**Reason:** Empty folder remnant from 2026-04-29 split into observability-{contracts,backend,frontend,infra}. Phase 0 audit cleanup.
**Original path:** .claude/skills/observability-patterns/
**Archived to:** .archive/2026-05-17/observability-patterns
**Review:** [ ] approved for permanent delete

## 2026-05-18 — .claude/skills/messaging-patterns/
**Reason:** Replaced by wolverine-patterns in Phase 1 — MassTransit/MediatR/Hangfire-scheduled assumptions removed.
**Original path:** .claude/skills/messaging-patterns/
**Archived to:** .archive/2026-05-18/messaging-patterns
**Review:** [ ] approved for permanent delete

## 2026-05-18 — .claude/skills/redis-patterns/
**Reason:** Replaced by hybridcache-patterns in Phase 2 — StackExchange.Redis-as-primary-API and MassTransit references removed. Raw Redis kept as escape hatches inside the new skill.
**Original path:** .claude/skills/redis-patterns/
**Archived to:** .archive/2026-05-18/redis-patterns
**Review:** [ ] approved for permanent delete

## 2026-05-18 — .claude/skills/csharp-clean-arch/
**Reason:** Renamed and rewritten as backend-feature-patterns in Phase 3 — absorbs CQRS handler shape, ErrorOr contract, Mapster, FluentValidation, comment markers. PHASE-3-FIX marker for marker-interface block resolved by deletion (project-specific concern, moved to system-context.md).
**Original path:** .claude/skills/csharp-clean-arch/
**Archived to:** .archive/2026-05-18/csharp-clean-arch
**Review:** [ ] approved for permanent delete

## 2026-05-18 — .claude/skills/auth-patterns/
**Reason:** Renamed and rewritten as keycloak-patterns in Phase 4a — single dominant lib (Keycloak) follows lib-naming rule. PHASE-4-FIX MVC controller block resolved with FastEndpoints + ABAC handler example. PHASE-3-FIX MediatR examples (if any remained) resolved by Wolverine handler shape.
**Original path:** .claude/skills/auth-patterns/
**Archived to:** .archive/2026-05-18/auth-patterns
**Review:** [ ] approved for permanent delete

## 2026-05-18 — .claude/skills/postgresql-patterns/
**Reason:** Renamed and rewritten as persistence-patterns in Phase 4b — concept-named per multi-lib bundle rule (EF + Dapper co-equal). PostgreSQL-specific patterns (JSONB, PostGIS, RLS) retained. Stale redis-patterns cross-ref at :215 resolved by retargeting to hybridcache-patterns §4.
**Original path:** .claude/skills/postgresql-patterns/
**Archived to:** .archive/2026-05-18/postgresql-patterns
**Review:** [ ] approved for permanent delete

## 2026-05-18 — .claude/skills/file-storage-patterns/
**Reason:** Renamed and rewritten as file-pipeline-patterns in Phase 4d — concept-named per multi-lib bundle rule (SeaweedFS + ImageSharp + nClam co-equal). PHASE-4-FIX markers on VirusScanConsumer (Phase 0) and UploadsController (Phase 3.1) resolved by Wolverine saga + FastEndpoints presigned endpoint. Port interfaces (IFileStorageService, IImageProcessor, IVirusScanService) established per ports-and-adapters policy.
**Original path:** .claude/skills/file-storage-patterns/
**Archived to:** .archive/2026-05-18/file-storage-patterns
**Review:** [ ] approved for permanent delete

## 2026-05-18 — .claude/skills/workflow-patterns/
**Reason:** Renamed and rewritten as workflow-and-jobs-patterns in Phase 4e — concept-named per multi-lib bundle rule (Elsa v3 + Hangfire co-equal). Added Hangfire content (was missing as standalone skill). Three-way decision rule with Wolverine sagas formalized. Resolves placeholder cross-refs from file-pipeline-patterns §13 (orphan cleanup) and elasticsearch-patterns §9 (reindex runner).
**Original path:** .claude/skills/workflow-patterns/
**Archived to:** .archive/2026-05-18/workflow-patterns
**Review:** [ ] approved for permanent delete

## 2026-05-18 — .claude/skills/polly-resilience-patterns/
**Reason:** Reframed and renamed as integration-adapter-patterns in Phase 4f-fix — lib-named scope was too broad (would have fired on every feature using an adapter via its port). Concept-named bundle correctly scopes to adapter-authoring tasks only. Polly content preserved as one section of the broader authoring guidance.
**Original path:** .claude/skills/polly-resilience-patterns/
**Archived to:** .archive/2026-05-18/polly-resilience-patterns
**Review:** [ ] approved for permanent delete

## 2026-05-18 — .claude/skills/observability-contracts/
**Reason:** Folded inline into observability-backend §6 (PII deny-list, Loki label allow-list, trace correlation) and observability-frontend §6 (PII deny-list, trace correlation). Cross-skill duplication is intentional — both skills load independently and the PII rule must be present in both.
**Original path:** .claude/skills/observability-contracts/
**Archived to:** .archive/2026-05-18/observability-contracts
**Review:** [ ] approved for permanent delete

## 2026-05-18 — .claude/skills/observability-infra/
**Reason:** Replaced by .specify/memory/observability-stack.md. Wiring is one-time setup, not recurring feature work. Skills now contain rules only.
**Original path:** .claude/skills/observability-infra/
**Archived to:** .archive/2026-05-18/observability-infra
**Review:** [ ] approved for permanent delete

## 2026-06-25 — .claude/skills/wolverine-patterns/wolverine-patterns.md
**Reason:** Dissolved in seam refactor: events seam -> backend-architecture, sagas -> orchestration-patterns, Wolverine wiring -> infrastructure-wiring
**Original path:** .claude/skills/wolverine-patterns/wolverine-patterns.md
**Archived to:** .archive/2026-06-25/wolverine-patterns.md
**Review:** [ ] approved for permanent delete

## 2026-06-25 — .claude/skills/keycloak-patterns/keycloak-patterns.md
**Reason:** Dissolved in seam refactor: AuthN wiring -> infrastructure-wiring, IUserContext -> backend-architecture, RBAC/ABAC usage -> authorization-patterns
**Original path:** .claude/skills/keycloak-patterns/keycloak-patterns.md
**Archived to:** .archive/2026-06-25/keycloak-patterns.md
**Review:** [ ] approved for permanent delete

## 2026-06-25 — .claude/skills/bff-patterns/bff-patterns.md
**Reason:** Dissolved in seam refactor: merged into api-endpoint-patterns (BFF/aggregation endpoints section)
**Original path:** .claude/skills/bff-patterns/bff-patterns.md
**Archived to:** .archive/2026-06-25/bff-patterns.md
**Review:** [ ] approved for permanent delete

## 2026-06-25 — .claude/skills/SKILL_AUDIT.md
**Reason:** Superseded by the seam refactor (2026-06-25). The audit analyzed the pre-refactor skill set (csharp-clean-arch, auth-patterns, messaging-patterns, redis-patterns, postgresql-patterns, etc.) which has since been restructured into the seam/edge/plumbing inventory. Its findings (single-owner markers, design-code-review derive, BFF overlap) are now resolved in backend-architecture + the rewritten skills.
**Original path:** .claude/skills/SKILL_AUDIT.md
**Archived to:** .archive/2026-06-25/SKILL_AUDIT.md
**Review:** [ ] approved for permanent delete

## 2026-09-15 — .claude/skills/sk.implement/sk.tasks
**Reason:** Dead skill: story-level tasks.yaml generator superseded by sk.plan → sk.planproject 03-plan/{Project}/tasks.md (framework-project-skills-separation plan §1.6)
**Original path:** .claude/skills/sk.implement/sk.tasks
**Archived to:** .archive/2026-09-15/sk.tasks
**Review:** [ ] approved for permanent delete

## 2026-09-15 — .claude/skills/sk.plan/sk.planstory
**Reason:** Dead skill: story-level plan superseded by sk.plan → sk.planproject per-project plans (framework-project-skills-separation plan §1.6)
**Original path:** .claude/skills/sk.plan/sk.planstory
**Archived to:** .archive/2026-09-15/sk.planstory
**Review:** [ ] approved for permanent delete
