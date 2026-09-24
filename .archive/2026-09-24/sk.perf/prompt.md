# sk.perf
Performance profiling and optimization cycle.
Role: backend | frontend | Level: unit or cross-unit

## Mode declaration
Declare at start: `[PERF MODE] Input: {load-test | profiler | both}. Role: {backend | frontend}.`

## Pre-flight
1. Read `.specify/state/session.yaml` role
   NULL → ask user: "backend or frontend performance work?"
2. Ask user to provide one of:
   (a) Load test results (the load-testing tool's output — paste or file path)
   (b) Profiler output (runtime profiler trace, browser performance panel or audit report — paste or file path)
   (c) Both
   NEITHER provided → STOP: this skill requires empirical input, not hypothesis
3. Ask: "What is the target metric and acceptance threshold?"
   Example: "p99 < 200ms under 500 concurrent users", "LCP < 2.5s on 3G"
   Record as: perf_target
4. Identify the target project: the active unit's Impacted Projects row matching the role, or the project in
   `.specify/memory/projects/index.md` whose Code Root contains the profiled code. Record `{Project}`.
   Resolve `PERF_DIR = specs/intents/{intent}/units/{unit}/04-implementation/{Project}/`
   (no active unit → `PERF_DIR = .specify/perf/`).

## Context loading
Homes and loading rules per `.claude/skills/governance/profile.md`:
1. `specs/adr/adr-index.md` → the ADRs it routes for the profiled area (for example caching, data
   access, observability) — decided constraints any optimization must respect
2. The project's rules: the `.claude/rules/{stack}/` folders mapped to `{Project}` by `rules.stacks` in
   `.specify/profile.yaml` (default Backend → `backend`, Frontend → `web`, Mobile → `mobile`) —
   conventions any perf-related code and instrumentation must follow. A missing folder logs
   `.claude/rules/{stack}/ not present — skipped`.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `perf`,
in-scope project = `{Project}`, signals = the profiler / load-test input. Budget for this skill: at most 4 packs.

## Step 1 — Diagnose
Analyse the profiler/load-test input:
- Identify the top-3 bottlenecks by impact (latency, throughput, or bundle weight)
- For each bottleneck:
  - Location: file:line or component name
  - Root cause: (N+1 query / missing index / no cache / render waterfall / large bundle / etc.)
  - Estimated impact: what % of latency/size this represents
  - Evidence: quote the specific metric from the input

Write findings to: PERF_DIR/perf-findings.md

## Step 2 — Prioritise
Rank bottlenecks by: (estimated impact) × (implementation risk⁻¹)
Present ranked list to user. Ask: "Which optimizations should I implement? (all / list numbers)"
Record selected optimizations.

## Step 3 — Generate tasks
For each selected optimization, write a task entry (`- [ ] P{NN} — {title}`):
- Task description
- Target file/component
- Acceptance criterion: measurable, tied to perf_target
- Test method: how the improvement will be verified (benchmark, re-run load test, re-run the audit)

Write tasks to: PERF_DIR/perf-tasks.md
(If no active unit: remind the user to capture the work as a story with sk.story)

## Step 4 — Implement
Execute tasks in priority order:
- Read existing code before editing
- Implement the optimization (query rewrite, index addition, cache layer, lazy load, code split, etc.)
- Add or update the benchmark/test for each change
- After each task: report metric delta if measurable inline (e.g. "query reduced from 12 to 1 round trip")
- After each task: tick it `- [x]` in perf-tasks.md

## Step 5 — Verify
Run the agreed test method for each completed optimization:
- Re-run benchmark or targeted load test segment
- Compare before/after against perf_target
- Report: target MET / target MISSED (by how much)
If target missed: report remaining gap and suggest next candidate optimization.

## Output Artifacts
PERF_DIR/perf-findings.md (diagnosis + ranked bottlenecks)
PERF_DIR/perf-tasks.md
{CodeRoot}/** (optimized files)
benchmark results summary (inline report)

## Quality Bar
- All findings backed by empirical input — no hypothesis-only entries
- Each optimization has a measurable acceptance criterion tied to perf_target
- Before/after comparison reported for each implemented optimization
- No behaviour changes — only performance characteristics altered
- No routed ADR or project rule violated by an optimization
