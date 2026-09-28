#!/usr/bin/env bash
# verify-evidence.sh — the mechanical items of governance/quality-gates.md for the active unit.
#
#   bash .claude/hooks/verify-evidence.sh [--no-run]
#
# One line per item: `PASS|FAIL|SKIP  <gate>  <item> — <detail>`, then a summary. It checks files,
# front-matter verdicts, task status and the two commands (the ADR guard and contracts.verify; --no-run
# skips both). sk.verify reads this output and judges only the items marked (judgment) in quality-gates.md.
# Exit 0 always; the verdict is the model's.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "${HOOK_DIR}/../.." && pwd)}"
cd "$ROOT" || exit 0
RUN=1; [[ "${1:-}" == "--no-run" ]] && RUN=0

P=0; F=0; K=0
out() { printf '%-4s  %-14s %s\n' "$1" "$2" "$3"; case "$1" in PASS) P=$((P + 1)) ;; FAIL) F=$((F + 1)) ;; *) K=$((K + 1)) ;; esac; }
exists() { if [[ -f "$3" ]]; then out PASS "$1" "$2 — $3"; else out FAIL "$1" "$2 — missing $3"; fi; }
fm() { sk_fm_field "$1" "$2" 2>/dev/null | tr '[:upper:]' '[:lower:]'; }

STORY=$(sk_find_story_file "$ROOT")
[[ -n "$STORY" ]] || { echo "No active story. Run: /sk.session focus --unit <id>"; exit 0; }
UNIT=$(sk_rel_path "$ROOT" "$(dirname "$(dirname "$STORY")")")
INTENT_DIR=$(dirname "$(dirname "$UNIT")")
MODE=$(fm "$STORY" checkpoint_mode)
PROJECTS=$(sk_projects_table "$UNIT/unit-brief.md")
UI=$(printf '%s\n' "$PROJECTS" | awk -F'\t' '$2 == "Frontend" || $2 == "Mobile"' | sed '/^$/d')
echo "# evidence: ${UNIT} (checkpoint_mode: ${MODE:-unset})"

# Spec
exists Spec "intent" "$INTENT_DIR/intent.md"
exists Spec "acceptance criteria" "$UNIT/01-story/acceptance-criteria.md"
if [[ -n "$PROJECTS" ]]; then out PASS Spec "impacted projects — $(printf '%s\n' "$PROJECTS" | cut -f1 | paste -sd, -)"
else out FAIL Spec "impacted projects — unit-brief.md has no Impacted Projects rows"; fi
case "$MODE" in autopilot|confirm|validate) out PASS Spec "checkpoint_mode — $MODE" ;; *) out FAIL Spec "checkpoint_mode — '${MODE:-unset}' is not autopilot|confirm|validate" ;; esac

# Architecture
exists Architecture "architecture" "$UNIT/02-design/architecture.md"
exists Architecture "impact analysis" "$UNIT/02-design/impact-analysis.md"
if [[ "$(sk_profile_get "$ROOT" knowledge.adr.guard true)" == "false" ]]; then out SKIP Architecture "ADR guard — knowledge.adr.guard: false"
elif [[ "$RUN" == 0 ]]; then out SKIP Architecture "ADR guard — --no-run"
else
  SCRIPTS=$(sed -n 's/^scripts_dir:[[:space:]]*//p' .claude/.speckit-manifest 2>/dev/null | head -1); SCRIPTS="${SCRIPTS:-scripts}"
  if msg=$(bash "$SCRIPTS/check-adr-index.sh" 2>&1); then out PASS Architecture "ADR guard — check-adr-index.sh exit 0"
  else out FAIL Architecture "ADR guard — $(printf '%s' "$msg" | tail -1)"; fi
fi

# Plan, Implementation, Test (per project)
while IFS=$'\t' read -r NAME TYPE _; do
  [[ -z "$NAME" ]] && continue
  PLAN="$UNIT/03-plan/$NAME/plan.md"; IMPL="$UNIT/04-implementation/$NAME"
  if [[ ! -f "$PLAN" ]]; then out FAIL Plan "$NAME plan — missing $PLAN"
  elif [[ "$MODE" == confirm || "$MODE" == validate ]]; then
    [[ "$(fm "$PLAN" status)" == approved ]] && out PASS Plan "$NAME plan — approved" || out FAIL Plan "$NAME plan — status '$(fm "$PLAN" status)', needs approved ($MODE)"
  else out PASS Plan "$NAME plan — present (autopilot)"; fi

  if [[ -f "$IMPL/progress.md" ]]; then
    open=$(grep -E '^\|[[:space:]]*T[0-9]+' "$IMPL/progress.md" | grep -ciE '\|[[:space:]]*(pending|scaffolded|blocked)[[:space:]]*\|' || true)
    [[ "$open" == 0 ]] && out PASS Implementation "$NAME tasks — all done" || out FAIL Implementation "$NAME tasks — $open not done"
  else out FAIL Implementation "$NAME tasks — missing $IMPL/progress.md"; fi
  if [[ -f "$IMPL/delivery.md" ]]; then
    v=$(fm "$IMPL/delivery.md" validation)
    [[ "$v" == pass ]] && out PASS Implementation "$NAME validation — PASS" || out FAIL Implementation "$NAME validation — ${v:-unset}"
  else out FAIL Implementation "$NAME validation — missing $IMPL/delivery.md"; fi
  if [[ -f "$IMPL/review.md" ]]; then
    v=$(fm "$IMPL/review.md" verdict)
    [[ "$v" == approved ]] && out PASS Implementation "$NAME review — APPROVED" || out FAIL Implementation "$NAME review — ${v:-unset}"
  else out FAIL Implementation "$NAME review — missing $IMPL/review.md"; fi

  TR="$UNIT/05-test/$NAME/test-report.md"
  if [[ -f "$TR" ]]; then
    v=$(fm "$TR" result)
    [[ "$v" == pass ]] && out PASS Test "$NAME suite — PASS" || out FAIL Test "$NAME suite — ${v:-unset}"
  else out FAIL Test "$NAME suite — missing $TR"; fi
done <<< "$PROJECTS"

[[ "$(fm "$STORY" test-status)" == pass ]] && out PASS Test "test-status — pass" || out FAIL Test "test-status — '$(fm "$STORY" test-status)'"
VERIFY=$(sk_profile_get "$ROOT" contracts.verify)
if [[ -z "$VERIFY" || "$VERIFY" == none ]]; then out SKIP Test "contracts.verify — unset (provider contract tests are the evidence)"
elif [[ "$RUN" == 0 ]]; then out SKIP Test "contracts.verify — --no-run"
elif msg=$(bash -c "$VERIFY" 2>&1); then out PASS Test "contracts.verify — exit 0"
else out FAIL Test "contracts.verify — non-zero: $(printf '%s' "$msg" | tail -1)"; fi
if [[ -n "$UI" ]]; then
  [[ "$(fm "$STORY" uat-status)" == pass ]] && out PASS Test "uat-status — pass" || out FAIL Test "uat-status — '$(fm "$STORY" uat-status)'"
else out SKIP Test "uat-status — no Frontend/Mobile project"; fi

# Security
exists Security "security report" "$UNIT/07-security-audit/security-report.md"
case "$(fm "$STORY" security-status)" in
  clear|conditional) out PASS Security "security-status — $(fm "$STORY" security-status)" ;;
  *) out FAIL Security "security-status — '$(fm "$STORY" security-status)'" ;;
esac

# Ship
if [[ -f "$UNIT/promotion.md" ]]; then out PASS Ship "promotion — $UNIT/promotion.md"
else out SKIP Ship "promotion — not yet run; sk.ship runs it"; fi
if sk_tracker_enabled "$ROOT"; then
  n=$(( $(sk_tracker_count "$ROOT" pending) + $(sk_tracker_count "$ROOT" failed) ))
  [[ "$n" == 0 ]] && out PASS Ship "tracker mirror — nothing pending" || out FAIL Ship "tracker mirror — $n pending or failed"
else out SKIP Ship "tracker mirror — tracker.kind: none"; fi

echo ""
echo "evidence: ${P} pass, ${F} fail, ${K} skip"
exit 0
