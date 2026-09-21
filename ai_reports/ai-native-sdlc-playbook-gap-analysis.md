# SpecKit-SSD-SDLC vs. Anthropic's *AI-Native SDLC Playbook* — Gap Analysis

**Date:** 2026-08-23
**Source:** *The AI-Native SDLC playbook*, Louis Claxton, Anthropic Applied AI — `claude.com/blog/the-ai-native-sdlc-playbook`
**Scope:** The 13 plays across the playbook's six stages, mapped against this repo's `sk.*` skills, context skills, `.claude/hooks/`, `.claude/settings.json`, `.specify/memory/`, and the `specs/intents/` artifact tree.
**Lens:** Not "does the repo mention the concept" but "does the repo *enforce* it, and is the enforcement wired to something real."

---

## 1. Verdict

**SpecKit is a deep, opinionated implementation of the playbook's left half and almost nothing of its right half.**

The playbook's organising claim is that *code is no longer the bottleneck — the human-speed steps to the left and right of build are*. SpecKit has spent all of its design budget on the **left** (Plan, Design, Build-planning) and treats **Deploy and Maintain as a single `gh pr create` at the end of `sk.ship`**. The right-hand bottleneck the article is actually about — review capacity, CI, evals, production feedback — is where SpecKit is thinnest.

Three findings dominate:

1. **The artifact chain is SpecKit's strongest asset and it is ahead of the playbook.** The playbook proposes `intent.md → spec.md → plan.md → diff → PR → incident record`. SpecKit already runs a seven-phase, per-project artifact tree with declared readers/writers per phase. This is the playbook's central mechanism, implemented more rigorously than the article describes.
2. **SpecKit has no CI, no evals, no PR-side review, and no maintain stage.** There is no `.github/`, no `REVIEW.md`, no eval suite, no control bands, no trigger layer. Five of the playbook's thirteen plays have *zero* representation. The loop does not close.
3. **The one deterministic gate SpecKit does have is broken.** `check-skill-preconditions.sh` — genuinely the best "hooks as approval gates" implementation in the repo — globs a story path that no skill writes (§5.1). It fails closed, so it blocks rather than leaks, but `sk.ship` and `sk.rollback` cannot currently pass their own preconditions.

Net: SpecKit is roughly **60% of the playbook by play count, but under 40% by where the article says the value now is.**

---

## 2. Play-by-play coverage

Legend — ✅ covered or exceeded · 🟡 partial · ❌ absent

| # | Stage | Play | Repo equivalent | |
|---|---|---|---|:--:|
| 1 | Plan | Capture as `intent.md` | `sk.story` → `sk.specify`; `templates/artifacts/intent-template.md`; `specs/intents/{intent}/intent.md` | 🟡 |
| 2 | Design | Requirements and design in one session | `sk.design` (architecture → datamodel → contracts), `sk.impact`, `sk.adr`, `02-design/` | ✅ |
| 3 | Build | Plan mode as the default start | `sk.plan` → `03-plan/{Project}/plan.md`, `tasks.md`, `checklist.md`, `estimation.md` | 🟡 |
| 4 | Build | The `CLAUDE.md` | Root `CLAUDE.md` + `.specify/memory/**` + `templates/root/CLAUDE.md` | ✅ |
| 5 | Build | Skills as institutional knowledge | 25+ context skills with marker tables, `inject_files`, deferral rules | ✅✅ |
| 6 | Build | Hooks as build-time guardrails | `validate-path.sh`, `intercept-delete.sh`, `check-system-prompt-files.sh` | 🟡 |
| 7 | Build | Parallel sessions and subagents | 8 role agents in `.claude/agents/`; per-project fan-out in plan/implement/test | 🟡 |
| 8 | Test | Give Claude a feedback loop | `sk.test`, `sk.uat`, `sk.verify` | 🟡 |
| 9 | Test | Continuous evals in CI | — | ❌ |
| 10 | Deploy | AI in the PR review loop | `sk.review` (pre-PR self-review only) | 🟡 |
| 11 | Deploy | Hooks as approval gates | `check-skill-preconditions.sh`; `governance/checkpoint-rules.md` | 🟡 |
| 12 | Deploy | CI/CD integration and deployment | `sk.ship` shells out to `gh pr create` | ❌ |
| 13 | Maintain | Maintenance and closing the loop | `sk.rollback`, `sk.hotfix` (both human-initiated) | ❌ |

**Coverage by stage:** Plan 🟡 · Design ✅ · Build ✅🟡 · Test 🟡❌ · Deploy 🟡❌ · Maintain ❌

---

## 3. Where SpecKit is ahead of the playbook

These are not gaps to close — they are assets to defend when adopting the rest.

**3.1 The artifact chain is stricter than the article's.**
The playbook is loose about where artifacts live ("the simplest home is an `intent/` folder"). SpecKit specifies a seven-phase tree with per-project fan-out at plan/implement/test, and each `sk.*` skill declares what it reads and writes in frontmatter. The article's "every stage commits an artifact the next stage can read" is SpecKit's actual filesystem layout.

**3.2 Skills go well beyond the article's "one policy, one skill" starting point.**
The playbook's worked example is a single `secure-api-review/SKILL.md`. SpecKit runs 25+ context skills with explicit composition rules — owned-marker tables, "when NOT to use" sections, and deferral between skills (`react-component-patterns` hands a11y to `accessibility-standards` rather than restating it). SpecKit also solves a problem the article does not raise: **conditional loading**, via `inject_files` and tag-driven pack selection in `sk.review` / `sk.test`, which is the real answer to the article's "keep it under a page" context-budget concern.

**3.3 Risk-tiered human checkpoints are a genuine extension.**
`governance/checkpoint-rules.md` classifies work as `autopilot | confirm | validate` and sets the number of human stop points accordingly. The article gestures at this ("anything the organization classes as higher risk goes to a tech lead") but never operationalises it. SpecKit's classification criteria — contract changes, new bounded contexts, auth/payments adjacency, multi-frontend impact — are concrete and reusable. **This is the single most valuable thing in the repo that the playbook lacks.** See §5.2 for why it does not currently bite.

**3.4 Legacy source-of-truth is already handled at the "linkage" tier.**
The playbook's sidebar asks teams to name one system as source of truth per artifact. SpecKit's `sk.story --jira` mode plus `jira.md` / `jira-subtask.md` artifacts already implement the article's minimum bar — record ID in the artifact, artifact linked from the record.

**3.5 There is already a telemetry hook to build on.**
`log-cache-metrics.sh` writes per-turn JSONL to `.claude/cache-metrics.jsonl`. It measures the wrong thing for this purpose (prompt-cache efficiency, not flow), but the plumbing — a `Stop` hook appending structured rows — is exactly what §4.6 needs.

---

## 4. Gaps, by severity

### 4.1 🔴 Critical — the loop does not close (Play 13)

The playbook's whole architecture is a loop: a breached control band, a ticket, or a channel message invokes Claude with **no person in the invocation path**, and the diagnosis re-enters as `intent.md`.

SpecKit ends at `sk.ship`. Every entry point requires a human to run a slash command. `sk.rollback` and `sk.hotfix` are *reactive fast-paths a human triggers*, not autonomous responses. There is no detection script, no `bands.yaml`, no trigger layer, no headless invocation, and no confidence gate between stages.

Concretely absent: response tiers (1σ log / 2σ diagnose read-only / 3σ propose via PR or pre-approved runbook), a deterministic detection script under version control, and the path from a production signal back to `specs/intents/`.

The article is explicit that this play depends on the others — `intent.md`, PR review, hooks as action boundary, and a rehearsed rollback path. SpecKit has three of those four (rollback exists via `sk.rollback`), so this is closer than it looks. It is blocked on Play 12, not on the loop itself.

### 4.2 🔴 Critical — no CI at all (Plays 9, 12)

There is no `.github/` directory. This forecloses four separate playbook mechanisms simultaneously:

- **Continuous evals** (Play 9) — the article's answer to "what regression-tests the agent's configuration." SpecKit's 25+ skills, 8 agents, 9 hooks and `CLAUDE.md` steer every session and are currently **changed without any regression signal.** For a repo whose entire product *is* agent configuration, this is the sharpest gap in the analysis. The article's spec is precise: 20–50 real tasks with expected outcomes, run on any change to `CLAUDE.md`, `.claude/**`, plus a nightly cron, gated on pass rate.
- **Non-interactive Claude in the pipeline** (Play 12) — no `claude -p` triage, changelog, or flaky-test summarisation.
- **Deployment via MCP with per-environment autonomy tiers** — SpecKit has no concept of environment at all.
- **Branch protection as the agent's hard boundary** — the article's governing principle is *"the agent may act up to the production gate and cannot pass it,"* enforced by branch protection plus a production-deploy hook. SpecKit has neither; nothing structurally prevents an agent-driven push past a gate.

### 4.3 🟠 High — review is pre-PR only, and one-directional (Play 10)

`sk.review` is a good spec-aware self-review: it loads the right capability packs by tag, checks against `architecture.md`, `api-spec.json`, ADRs and coding standards. But it runs **in the author's session, before the PR exists.**

The playbook's play is bidirectional and PR-resident:
- No `REVIEW.md` at repo root defining passes (bugs / security / compliance-to-`spec.md`-and-`plan.md`), the Important-vs-Nit threshold, and exclusions.
- No `@claude` fix loop — reviewer tags a comment, Claude pushes the fix, the thread records both.
- No severity tally published as a machine-readable check run.
- No feedback path from review findings back into `CLAUDE.md` — the article's "when a review flags a mistake for the second time, the correction goes into `CLAUDE.md`." SpecKit has `sk.phr` for capturing decisions, but nothing routes *review findings* into durable agent context.

Notably, SpecKit's `design-code-review` skill already derives checks from `backend-architecture` markers and NetArchTest invariants — that content **is** the body of a `REVIEW.md`. The gap is placement and trigger, not substance.

### 4.4 🟠 High — no measurement whatsoever

Every one of the article's 13 plays ships a leading and a lagging indicator, most read from data teams already have (git timestamps, PR metadata, CI results, DORA). SpecKit defines **zero** leading or lagging indicators. No `sk.*` skill emits a metric; `quality-gates.md` is entirely binary PASS/FAIL.

This matters more for SpecKit than for a typical adopter: a 7-phase, 20-skill pipeline is a large process tax, and there is currently **no evidence the tax is bought back**. The article's cheapest wins are directly available from the artifact tree — time from `intent.md` commit to `spec.md` commit, `spec.md` commits dated after the first `plan.md` commit (requirements rework), share of changes merging on the first implementation pass.

### 4.5 🟡 Medium — the feedback loop is artifact-level, not in-session (Play 8)

The playbook's rule is *always give Claude a way to verify its own work* — a single command that exits non-zero, run repeatedly **through** the task, before a person sees anything.

SpecKit verifies at **phase boundaries**: `sk.implement` produces `validation.md`, `sk.test` produces test artifacts, `sk.verify` runs six gates. Those are the article's *stage-gate QA* — the thing the loop is supposed to replace, not implement.

Specifically missing:
- No canonical one-command build/test/lint target listed with healthy example output in `CLAUDE.md` (the article's "Verifying your work" block).
- No **hook blocking edits to test files during a fix task.** The article is emphatic: an agent fixing code must not be able to weaken the check on that code. SpecKit's hooks block deletes and path traversal, not test-file weakening.
- No write-the-failing-test-first protocol for bug fixes.
- No visual/screenshot loop for UI work — `sk.uat` names Playwright/Maestro but as a *phase*, not an in-session iteration loop.

### 4.6 🟡 Medium — build-time hooks cover safety, not policy (Play 6)

The four active hooks are all *containment*: no deletes, no path traversal, no writes outside project root, plus a system-prompt file check. The article's build-phase hook examples are *policy enforcement*: block edits to protected/generated paths, run formatter and linter after each edit so drift never accumulates, keep credentials out of the diff.

The article's framing is the key one SpecKit is missing: **"a skill is an advisory control; a hook is the deterministic layer behind it."** SpecKit has 25 advisory skills encoding real policy and almost no deterministic backing. `backend-architecture`'s NetArchTest invariants are the clearest candidate — they are already written as invariants and are currently enforced by nothing at edit time.

### 4.7 🟡 Medium — parallelism is unaddressed (Play 7)

SpecKit has subagents (8 role agents, and per-project fan-out inside `sk.plan` / `sk.implement` / `sk.test`), which is half the play. It has nothing on **parallel sessions**: the word `worktree` does not appear anywhere in the repo. There is no guidance on splitting a plan into file-disjoint tasks, no `claude --worktree` convention, no advice on the practical ceiling (the article: 2–3 sessions, add only while review keeps up).

This is a real omission given SpecKit's structure — `03-plan/{Project}/` already fans work out per project, which is precisely the natural worktree boundary. The framework produces parallelisable plans and then says nothing about running them in parallel.

Also missing: the article's `auto` mode discussion. SpecKit's `defaultMode: acceptEdits` in `settings.json` is close, but nothing in the framework tells an engineer *when* auto-accept is appropriate (tight `spec.md`, small blast radius, code the tests already cover) — which is the article's actual guidance.

### 4.8 🟡 Medium — `plan.md` is an artifact, not plan mode (Play 3)

`sk.plan` produces an excellent `plan.md` (files, order, risks, estimation, checklist) — arguably richer than the article's example. But the article's play is specifically about **Claude Code plan mode as the session's starting posture**, where Claude reads the codebase without changing anything and the engineer interrogates the plan before any edit is possible. Plan mode enforces the gate itself; SpecKit's `plan.md` is a document produced by a skill.

Also absent: the article's plan/implementation synchronisation rule — *"when implementation departs from the plan, update `plan.md` in the same commit; consider a hook to enforce it."* SpecKit's `progress.md` tracks delivery but nothing detects or enforces plan drift.

### 4.9 🟢 Low — intent capture assumes an engineer (Play 1)

The article's Play 1 is deliberately non-engineer-facing: the originator brainstorms in claude.ai or Cowork, a VCS connector commits on their behalf, and a technical team member's only job is standing up the intent home. Its prerequisite is explicitly *"None."*

SpecKit's `sk.story` requires a cloned repo, `bash setup.sh`, `sk.session start --role po`, and `sk.session focus`. That is a competent-CLI-user onramp for what the article designs as the zero-friction entry point. The likely consequence is the exact failure the article opens with: *ideas wait for someone to write them up.*

`sk.story --jira` partly compensates by letting intent arrive from a tool non-engineers already use — worth building on rather than replacing.

---

## 5. Wiring defects found while mapping

These are not playbook gaps; they are bugs surfaced by tracing the enforcement path.

### 5.1 🔴 The precondition hook cannot find any story file

`check-skill-preconditions.sh:58` globs:

```
specs/intents/*/units/*/stories/story-${ACTIVE_STORY_ID}.md
```

`sk.story/prompt.md` writes stories to:

```
specs/intents/{intent}/units/{unit}/{NN}-story/story.md
```

The glob matches nothing. The hook then hits its `no active story found — cannot evaluate` branch and exits 2, so **`sk.ship` (3 story preconditions) and `sk.rollback` (1) are blocked unconditionally.** It fails closed, which is the right failure direction, but the repo's only deterministic gate is inoperative.

There are in fact **four** competing story-path conventions live in the repo simultaneously: the hook's `stories/story-{ID}.md`, `sk.story`'s `{NN}-story/story.md`, the `stories/{story-id}/` form used by `sk.plan`/`sk.rollback` prompts, and the `01-story/` form documented in `README.md`. Pick one and make the hook, the prompts, and the README agree.

### 5.2 🟠 `checkpoint_mode` is enforced by nothing

`governance/checkpoint-rules.md` is the repo's best original contribution (§3.3) — and `checkpoint_mode` appears in **no hook and no settings entry**. It is prose that skills are asked to honour. In the article's own terms this makes risk-tiered approval an *advisory control with no deterministic layer behind it*, which is precisely the pattern the Skills play warns against. Given `check-skill-preconditions.sh` already exists and already reads session state, wiring `checkpoint_mode` into it is a small change with large governance payoff.

### 5.3 🟠 Governance files reference a state file and a skill that do not exist

`governance/checkpoint-rules.md` and `governance/quality-gates.md` both write to and read from **`state.yaml`**; the other 51 files in `.claude/` use **`session.yaml`**. `quality-gates.md:9` checks `.specify/intents/` while intents live in `specs/intents/`. Both files route through `sk.specify`, which is no longer a top-level skill (it is a sub-skill of `sk.story`). The governance layer has drifted from the framework it governs.

### 5.4 🟡 `.claude/settings.json` has accumulated one-off permission grants

The `allow` list contains ~40 entries, including fully-quoted historical `archive-file.sh` invocations with embedded rationale strings from past refactors, and an absolute Windows path in `additionalDirectories`. Contrast the article's managed-settings worked example, which is a small, deliberate, reviewable control surface. This file is currently a changelog, not a policy. Note also that `allowManagedPermissionRulesOnly`, `sandbox`, `allowManagedHooksOnly`, `disableSideloadFlags`, `allowManagedMcpServersOnly` and `requiredMinimumVersion` are all unset — SpecKit uses one line (`disableBypassPermissionsMode`) of the article's regulated-enterprise profile.

---

## 6. Recommended adoption order

Following the article's own dependency logic — start where nothing points in.

**Tier 0 — fix what exists (days).** Nothing new is worth adding while the one real gate is dead.
1. Unify the story path across hook / prompts / README (§5.1).
2. Reconcile `state.yaml` → `session.yaml` and `.specify/intents/` → `specs/intents/` in `governance/` (§5.3).
3. Wire `checkpoint_mode` into `check-skill-preconditions.sh` so risk tiers actually block (§5.2).
4. Prune `settings.json` to a reviewable policy (§5.4).

**Tier 1 — the two highest-leverage new plays (weeks).**
5. **Evals in CI** (Play 9). Highest value per unit of effort *for this repo specifically*, because the repo's product is agent configuration and that configuration currently has no regression signal. Seed from `ai_reports/` findings and past skill refactors; gate on changes to `CLAUDE.md` and `.claude/**`.
6. **`REVIEW.md` + PR-side review** (Play 10). The content already exists in `design-code-review` and `sk.review`; the work is relocating it to the PR and adding the `@claude` fix loop. This is where the article says the bottleneck actually is.

**Tier 2 — depends on Tier 1 (weeks).**
7. **In-session feedback loop** (Play 8) — one-command verification in `CLAUDE.md`, plus the test-file-edit-blocking hook. Cheap, and it is a stated prerequisite for both evals and parallel sessions.
8. **Policy hooks behind existing skills** (Play 6) — start with `backend-architecture`'s NetArchTest invariants at edit time.
9. **Measurement** (§4.4) — repurpose the `log-cache-metrics.sh` pattern for flow metrics. Start with the two indicators readable straight from git: intent→spec elapsed time, and `spec.md` commits after first `plan.md` commit.

**Tier 3 — requires CI (months).**
10. **CI/CD integration** (Play 12), including branch protection as the agent's hard boundary and per-environment autonomy tiers.
11. **Closing the loop** (Play 13) — `bands.yaml`, deterministic detection, response tiers, and the path from a production signal back to `specs/intents/`.

**Deliberately deferred:** parallel sessions/worktrees (§4.7) and non-engineer intent capture (§4.9). Both are real gaps, but both amplify throughput into a review stage that cannot yet absorb it. The article's own advice applies — add sessions only while review is keeping up.

---

## 7. One-line summary

SpecKit implements the playbook's artifact chain more rigorously than the article specifies, and implements the playbook's *thesis* — that the bottleneck has moved right of build — barely at all.
