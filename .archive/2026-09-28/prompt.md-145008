# sk.verify
PASS/FAIL quality gate for the active story.
Role: architect | Level: story (unit)

**When to run:** After sk.test passes (`test-status: pass` in story frontmatter), before sk.ship.
This is the final gate — not a mid-implementation check. Run sk.plan --analyze-only if you need a
consistency check earlier in the cycle (before implementation starts).

## Pre-flight
Run the story pre-flight in `.claude/skills/governance/preflight.md` (active story, UNIT_DIR, Impacted
Projects, checkpoint_mode, knowledge, `.specify/profile.yaml`). Resolve `SCRIPTS_DIR` per
`.claude/skills/governance/framework-paths.md`.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `review`,
in-scope projects = every Impacted Projects row, working text = story + `02-design/architecture.md`.
The loaded packs' review checks feed the Implementation Gate.

## Input Artifacts
Paths per `.claude/skills/governance/phase-layout.md`; homes per `.claude/skills/governance/profile.md`:
- UNIT_DIR/01-story/ (story.md frontmatter, requirement.md, acceptance-criteria.md)
- UNIT_DIR/02-design/ (architecture.md, impact-analysis.md, database-design.md, contract-changes.md, projects/)
- The branch diff of the canonical `specs/openapi|asyncapi` files `contract-changes.md` lists
- UNIT_DIR/03-plan/{Project}/ (plan.md, tasks.md, checklist.md)
- UNIT_DIR/04-implementation/{Project}/ (implementation.md, progress.md, validation.md, review-{story-id}.md)
- UNIT_DIR/05-test/{Project}/, UNIT_DIR/06-uat/, UNIT_DIR/07-security-audit/
- UNIT_DIR/promotion.md (when sk.ship's promotion step has run)
- .specify/memory/constitution.md; specs/adr/adr-index.md → the ADRs it routes for this work
- specs/domain/bounded-contexts.md + the specs/domain/{module}.md files of the touched contexts
- For each impacted project: `.specify/memory/projects/{Project}/tech-stack.md` and its
  `.claude/rules/{stack}/` folders (`rules.stacks`)
- `.specify/profile.yaml` → `contracts.verify`, `contracts.compat_rules`, `knowledge.adr.guard`, `tracker.*`
- .claude/skills/governance/quality-gates.md
Rubric blocks from:
  .claude/skills/sk.story/SKILL.md (rubric: story-completeness)
  .claude/skills/sk.test/SKILL.md  (rubric: test-coverage)
  .claude/skills/sk.security-audit/SKILL.md (rubric: security-coverage)

## Steps
Evaluate `quality-gates.md` exactly — every item, in order, each PASS / FAIL / SKIP with a reason.
1. Spec Gate: always evaluate; also apply the `story-completeness` rubric from sk.story.
2. Architecture Gate: evaluate if 02-design/architecture.md exists. Includes the **ADR guard**:
   run `bash {SCRIPTS_DIR}/check-adr-index.sh` from the repo root and record its exit code and output.
   Non-zero → FAIL. SKIP only when `knowledge.adr.guard` is `false` (log `SKIP — knowledge.adr.guard: false`).
3. Plan Gate: evaluate if any 03-plan/{Project}/plan.md exists. Every changed operation must be in the
   canonical spec on this branch and in `contract-changes.md` with a compatibility class from
   `contracts.compat_rules` (default `additive | deprecating | breaking`).
4. Implementation Gate: evaluate if any 04-implementation/{Project}/progress.md exists. Judge the diff
   against the constitution, the routed ADRs and each project's `.claude/rules/{stack}/` (sk.review's
   report is the primary evidence; a BLOCKING finding fails), plus the review checks of the packs loaded
   in Step 0.
5. Test Gate: apply the `test-coverage` rubric from sk.test (and 06-uat/ for user-facing units).
   **Contract verification:** when `contracts.verify` is set, run it from the repo root and record the
   exit code — non-zero is FAIL (also cross-check `05-test/{BackendProject}/contract-test.md`). When
   unset, the provider contract tests in `05-test/{BackendProject}/contract-test.md` must exist and pass
   for every changed operation. A tech-stack field set to `none` (E2E Tooling, Coverage Thresholds, …)
   makes its item SKIP with `{field}: none`, not FAIL.
6. Security Gate: apply the `security-coverage` rubric from sk.security-audit.
7. Ship Gate: evaluate when UNIT_DIR/promotion.md exists (otherwise SKIP — `promotion not yet run; sk.ship
   runs it`). Re-run the ADR guard after promotion (same skip rule), and check the tracker mirror with
   `bash .claude/hooks/story-status.sh show` when `tracker.kind` is not `none`.
8. Output a structured report with PASS/FAIL/SKIP per gate item AND per rubric check.
9. Overall PASS → the Stop hook moves the story to `done` and sets `verify-status: PASS` from `SK_RESULT`.
   Overall FAIL → status unchanged, the Stop hook sets `verify-status: FAIL`; list the failures.
   Never edit story frontmatter with Edit/Write (`governance/status-model.md`).

## Output Artifacts
Verification report (displayed, not written to file)
01-story/story.md `status.current` → `done` if overall PASS (written by the Stop hook)
01-story/story.md `verify-status` → PASS or FAIL (written by the Stop hook)

## Quality Bar
- Every gate item explicitly PASS, FAIL, or SKIP with reason
- The ADR guard and `contracts.verify` (when set) were actually run, with exit codes shown
- FAIL items include specific finding not generic message
- Rule-level findings cite the constitution clause, ADR or rule file they break — never a framework default
- Recommendations actionable not vague

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — overall verdict is PASS
`SK_RESULT: FAIL` — one or more gates failed
