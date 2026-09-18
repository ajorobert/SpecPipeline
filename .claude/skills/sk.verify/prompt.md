# sk.verify
PASS/FAIL quality gate for the active story.
Role: architect | Level: story (unit)

**When to run:** After sk.test passes (test-status = pass in story frontmatter), before sk.ship.
This is the final gate — not a mid-implementation check. Run sk.plan --analyze-only if you need a
consistency check earlier in the cycle (before implementation starts).

## Pre-flight
Run the story pre-flight in `.claude/skills/governance/preflight.md` (active story, UNIT_DIR, Impacted
Projects, checkpoint_mode, knowledge bases).

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `review`,
in-scope projects = every Impacted Projects row, signals = story tags. The loaded packs' review checks
feed the Implementation Gate.

## Input Artifacts
Paths per `.claude/skills/governance/phase-layout.md`:
- UNIT_DIR/01-story/ (story.md frontmatter, requirement.md, acceptance-criteria.md)
- UNIT_DIR/02-design/ (architecture.md, impact-analysis.md, database-design.md, api-contract.md, contracts/, projects/)
- UNIT_DIR/03-plan/{Project}/ (plan.md, tasks.md, checklist.md)
- UNIT_DIR/04-implementation/{Project}/ (implementation.md, progress.md, validation.md, review-{story-id}.md)
- UNIT_DIR/05-test/{Project}/, UNIT_DIR/06-uat/, UNIT_DIR/07-security-audit/
- .specify/memory/architecture-decisions.md, .specify/memory/constitution.md (if present)
- .specify/memory/standards/ (all files)
- .claude/skills/governance/quality-gates.md
Rubric blocks from:
  .claude/skills/sk.story/SKILL.md (rubric: story-completeness)
  .claude/skills/sk.test/SKILL.md  (rubric: test-coverage)
  .claude/skills/sk.security-audit/SKILL.md (rubric: security-coverage)

## Steps
1. Read quality-gates.md — evaluate all applicable gates
2. Spec Gate: always evaluate; also apply `story-completeness` rubric from sk.story
3. Architecture Gate: evaluate if 02-design/architecture.md exists
4. Plan Gate: evaluate if any 03-plan/{Project}/plan.md exists
5. Implementation Gate: evaluate if any 04-implementation/{Project}/progress.md exists; include the review
   checks of the packs loaded in Step 0
6. Test Gate: apply `test-coverage` rubric from sk.test (and 06-uat/ for user-facing units)
7. Security Gate: apply `security-coverage` rubric from sk.security-audit
8. Output structured report with PASS/FAIL per gate AND per rubric check
9. Overall PASS → story status set to done and verify-status=PASS via Stop hook
   Overall FAIL → status unchanged, verify-status=FAIL, list failures

## Output Artifacts
Verification report (displayed, not written to file)
01-story/story.md `status.current` updated if overall PASS (written by the Stop hook)
01-story/story.md `verify-status` set to PASS or FAIL (written by the Stop hook)

## Quality Bar
- Every gate item explicitly PASS, FAIL, or SKIP with reason
- FAIL items include specific finding not generic message
- Recommendations actionable not vague

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — overall verdict is PASS
`SK_RESULT: FAIL` — one or more gates failed
