#!/usr/bin/env bash
# context.sh — the loading manifest for one sk.* command session. Run by every command's preflight.
#
#   bash .claude/hooks/context.sh <command> [--projects <key>]
#
# Prints, deterministically:
#   - the active unit, story and checkpoint_mode; the project in scope (with --projects)
#   - TEMPLATES_DIR / SCRIPTS_DIR
#   - the unit files this command reads, each marked present or missing (a missing output = a step to run)
#   - the capability packs to load, scored per governance/pack-resolution.md
#   - review / verify only: the rule files whose `paths:` match the branch diff (a session that starts from
#     `git diff` has not opened the files, so Claude Code has not loaded their rules)
# It reads nothing it prints and decides nothing: the command reads the listed files and does the work.
# Exit 1 only when there is no active unit for a unit-level command.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "${HOOK_DIR}/../.." && pwd)}"
cd "$ROOT" || exit 1

CMD="${1:-}"; shift || true
CMD="${CMD#sk.}"
KEY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --projects) KEY="${2:-}"; shift 2 || shift ;;
    --projects=*) KEY="${1#--projects=}"; shift ;;
    *) shift ;;
  esac
done
[[ -n "$CMD" ]] || { echo "usage: context.sh <command> [--projects <key>]" >&2; exit 1; }

case "$CMD" in
  design|plan|implement|test|uat) PHASE="$CMD" ;;
  review|verify|security-audit)   PHASE="review" ;;
  *)                              PHASE="" ;;
esac

# ── Framework paths ───────────────────────────────────────────────────────────
MANIFEST=".claude/.speckit-manifest"
TEMPLATES_DIR="templates"; SCRIPTS_DIR="scripts"
if [[ -f "$MANIFEST" ]]; then
  TEMPLATES_DIR=$(sed -n 's/^templates_dir:[[:space:]]*//p' "$MANIFEST" | head -1)
  SCRIPTS_DIR=$(sed -n 's/^scripts_dir:[[:space:]]*//p' "$MANIFEST" | head -1)
fi

# ── Unit ──────────────────────────────────────────────────────────────────────
STORY_FILE=$(sk_find_story_file "$ROOT")
UNIT=""
[[ -n "$STORY_FILE" ]] && UNIT=$(sk_rel_path "$ROOT" "$(dirname "$(dirname "$STORY_FILE")")")
if [[ -z "$UNIT" ]]; then
  UNIT_ID=$(sk_session_value "$ROOT" active_unit_id)
  for d in specs/intents/*/units/"${UNIT_ID:-__none__}"; do [[ -d "$d" ]] && UNIT="$d"; done
fi
case "$CMD" in
  story|session|init|adr|ff|hotfix) ;;
  *) [[ -n "$UNIT" ]] || { echo "No active unit. Run: /sk.session focus --unit <id>" >&2; exit 1; } ;;
esac

MODE=""; TAGS=""
if [[ -n "$STORY_FILE" ]]; then
  MODE=$(sk_fm_field "$STORY_FILE" checkpoint_mode)
  TAGS=$(sk_fm_field "$STORY_FILE" tags | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d' | tr '[:upper:]' '[:lower:]')
fi

# Projects in scope: the unit's Impacted Projects (the router when the unit has none), narrowed by --projects.
IMPACTED=$(sk_projects_table "$UNIT/unit-brief.md" 2>/dev/null)
[[ -n "$IMPACTED" ]] || IMPACTED=$(sk_projects "$ROOT")
SCOPE="$IMPACTED"
if [[ -n "$KEY" ]]; then
  SCOPE=$(printf '%s\n' "$IMPACTED" | awk -F'\t' -v k="$KEY" '$1 == k')
  if [[ -z "$SCOPE" ]]; then
    case "$KEY" in api|backend) T=Backend ;; web|frontend) T=Frontend ;; mobile) T=Mobile ;; *) T="" ;; esac
    [[ -n "$T" ]] && SCOPE=$(printf '%s\n' "$IMPACTED" | awk -F'\t' -v t="$T" '$2 == t')
  fi
  if [[ "$(printf '%s\n' "$SCOPE" | sed '/^$/d' | wc -l | tr -d ' ')" != "1" ]]; then
    echo "--projects ${KEY} does not select exactly one impacted project. Candidates:" >&2
    printf '%s\n' "$IMPACTED" | awk -F'\t' '{ print "  " $1 " (" $2 ", " $3 ")" }' >&2
    exit 1
  fi
fi

# ── Header ────────────────────────────────────────────────────────────────────
echo "# context: sk.${CMD}${KEY:+ --projects $KEY}"
echo "unit: ${UNIT:-none}"
[[ -n "$STORY_FILE" ]] && echo "story: $(sk_rel_path "$ROOT" "$STORY_FILE") (status: $(sk_fm_field "$STORY_FILE" status.current || true), checkpoint_mode: ${MODE:-unset})"
echo "templates_dir: ${TEMPLATES_DIR}"
echo "scripts_dir: ${SCRIPTS_DIR}"
if [[ -n "$SCOPE" ]]; then
  echo "projects in scope:"
  printf '%s\n' "$SCOPE" | awk -F'\t' 'NF { print "  " $1 " | " $2 " | " $3 }'
fi

# ── Files ─────────────────────────────────────────────────────────────────────
# f <path> [label] — list a file with its state; approved/draft read from `status:` front-matter.
f() {
  local p="$1" st=""
  if [[ -f "$p" ]]; then
    st=$(sk_fm_field "$p" status); [[ "$st" == *:* || -z "$st" ]] && st="present"
    printf '  [%s] %s\n' "$st" "$p"
  elif [[ -d "$p" ]]; then printf '  [present] %s/\n' "$p"
  else printf '  [missing] %s\n' "$p"; fi
}
per_project() {  # per_project <template with {P}>
  local tpl="$1" name
  while IFS=$'\t' read -r name _ _; do [[ -n "$name" ]] && f "${tpl//\{P\}/$name}"; done <<< "$SCOPE"
}
per_type() {     # per_type <Backend|UI> <template with {P}>
  local want="$1" tpl="$2" name type
  while IFS=$'\t' read -r name type _; do
    [[ -z "$name" ]] && continue
    if [[ "$want" == UI && "$type" != Backend ]] || [[ "$want" == "$type" ]]; then f "${tpl//\{P\}/$name}"; fi
  done <<< "$SCOPE"
}

S="$UNIT/01-story"; D="$UNIT/02-design"
echo ""
echo "read (in order; [missing] files are skipped — or, for this command's outputs, are the steps still to run):"
f specs/adr/adr-index.md
case "$CMD" in
  story)
    f .specify/memory/projects/index.md; f specs/domain/bounded-contexts.md
    [[ -n "$UNIT" ]] && { f "$UNIT/unit-brief.md"; f "$S/story.md"; f "$S/requirement.md"; f "$S/acceptance-criteria.md"; } ;;
  design)
    f specs/domain/bounded-contexts.md; f "$UNIT/unit-brief.md"
    f "$S/story.md"; f "$S/requirement.md"; f "$S/acceptance-criteria.md"; f "$UNIT/knowledge-base.md"
    echo "outputs:"
    f "$D/architecture.md"; f "$D/impact-analysis.md"; f "$D/database-design.md"; f "$D/contract-changes.md"
    per_type Backend "$D/projects/{P}.md"
    per_type UI "$D/projects/{P}.md"
    printf '%s\n' "$SCOPE" | awk -F'\t' '$2 == "Frontend" || $2 == "Mobile" { found = 1 } END { exit !found }' && f "$D/ui-model.md" ;;
  plan)
    f "$UNIT/unit-brief.md"; f "$S/acceptance-criteria.md"; f "$UNIT/knowledge-base.md"
    f "$D/architecture.md"; f "$D/impact-analysis.md"; f "$D/database-design.md"; f "$D/contract-changes.md"; f "$D/ui-model.md"
    per_project "$D/projects/{P}.md"; per_project ".specify/memory/projects/{P}/tech-stack.md"
    echo "outputs:"
    per_project "$UNIT/03-plan/{P}/plan.md"; per_project "$UNIT/03-plan/{P}/tasks.md" ;;
  implement)
    f "$S/acceptance-criteria.md"; f "$UNIT/knowledge-base.md"
    f "$D/architecture.md"; f "$D/contract-changes.md"
    per_type Backend "$D/database-design.md"; per_type UI "$D/ui-model.md"
    per_project "$D/projects/{P}.md"; per_project ".specify/memory/projects/{P}/tech-stack.md"
    per_project "$UNIT/03-plan/{P}/plan.md"; per_project "$UNIT/03-plan/{P}/tasks.md"
    per_project "$UNIT/04-implementation/{P}/review.md"
    echo "outputs:"
    per_project "$UNIT/04-implementation/{P}/progress.md"; per_project "$UNIT/04-implementation/{P}/delivery.md" ;;
  test)
    f "$S/acceptance-criteria.md"; f "$UNIT/knowledge-base.md"; f "$D/contract-changes.md"
    per_project "$D/projects/{P}.md"; per_project ".specify/memory/projects/{P}/tech-stack.md"
    per_project "$UNIT/03-plan/{P}/plan.md"; per_project "$UNIT/04-implementation/{P}/delivery.md"
    echo "outputs:"
    per_project "$UNIT/05-test/{P}/test-report.md" ;;
  review)
    f "$S/story.md"; f "$S/acceptance-criteria.md"; f "$D/architecture.md"; f "$D/contract-changes.md"
    per_project "$D/projects/{P}.md"; per_project "$UNIT/03-plan/{P}/plan.md"; per_project "$UNIT/04-implementation/{P}/delivery.md"
    echo "outputs:"
    per_project "$UNIT/04-implementation/{P}/review.md" ;;
  uat)
    f "$S/acceptance-criteria.md"; f "$UNIT/knowledge-base.md"; f "$D/contract-changes.md"; f "$D/ui-model.md"
    per_type UI ".specify/memory/projects/{P}/tech-stack.md"
    echo "outputs:"
    f "$UNIT/06-uat/uat-report.md" ;;
  security-audit)
    f "$S/acceptance-criteria.md"; f "$UNIT/knowledge-base.md"; f "$D/architecture.md"; f "$D/contract-changes.md"
    per_project ".specify/memory/projects/{P}/tech-stack.md"
    echo "outputs:"
    f "$UNIT/07-security-audit/security-report.md" ;;
  verify)
    echo "  (evidence: bash .claude/hooks/verify-evidence.sh)" ;;
  ship)
    f "$UNIT/knowledge-base.md"; f "$D/architecture.md"; f "$D/contract-changes.md"; f "$UNIT/investigation-report.md"
    per_project "$UNIT/04-implementation/{P}/review.md"
    echo "outputs:"
    f "$UNIT/promotion.md" ;;
  investigate)
    f "$S/story.md"; f "$S/acceptance-criteria.md"; f "$D/contract-changes.md"; f "$UNIT/knowledge-base.md"
    per_project "$UNIT/03-plan/{P}/plan.md"
    echo "outputs:"
    f "$UNIT/investigation-report.md" ;;
esac

# ── Capability packs (governance/pack-resolution.md) ─────────────────────────
REGISTRY=".claude/skills/README.md"
if [[ -n "$PHASE" && -n "$SCOPE" ]]; then
  echo ""
  if ! grep -q '^## Registry' "$REGISTRY" 2>/dev/null; then
    echo "packs (phase=${PHASE}): no registry — none loaded"
  else
    MAX=$(sk_profile_get "$ROOT" skills.max_packs 8)
    N=$(printf '%s\n' "$SCOPE" | sed '/^$/d' | wc -l | tr -d ' ')
    # Working text for context signals: the story and, from plan on, the project's plan.
    TEXT=$(cat "$S/story.md" "$S/requirement.md" 2>/dev/null)
    [[ -n "$KEY" ]] && TEXT="${TEXT}"$'\n'"$(cat "$UNIT/03-plan/$(printf '%s' "$SCOPE" | cut -f1)/plan.md" 2>/dev/null)"
    echo "packs (phase=${PHASE}, max_packs=${MAX}):"
    SK_SCOPE=$(printf '%s\n' "$SCOPE" | awk -F'\t' 'NF { print $1 "\t" $2 }') \
    SK_TEXT=$(printf '%s' "$TEXT" | tr '[:upper:]' '[:lower:]') \
    awk -F'|' -v phase="$PHASE" -v max="$MAX" -v n="$N" -v tags="$(printf '%s' "$TAGS" | tr '\n' ',')" '
      function trim(s) { gsub(/^[ \t`]+|[ \t`]+$/, "", s); return s }
      function has(list, item,   a, k, i) { k = split(list, a, /[ \t]*,[ \t]*/); for (i = 1; i <= k; i++) if (tolower(trim(a[i])) == tolower(item)) return 1; return 0 }
      function negated(clause, pos,   pre) {
        pre = substr(clause, 1, pos - 1)
        return (pre ~ /(^|[^a-z])(no|not|without|never|excluding)([^a-z]|$)/ || pre ~ /non-|n.t[^a-z]|out of scope/)
      }
      function ctxcount(sig,   c, i, re, p) {
        c = 0; re = "(^|[^a-z0-9])" sig "([^a-z0-9]|$)"
        for (i = 1; i <= nclause; i++) if (match(clause[i], re)) { p = RSTART; if (!negated(clause[i], p)) c++ }
        return c
      }
      BEGIN {
        np = split(ENVIRON["SK_SCOPE"], rows, "\n")
        for (p = 1; p <= np; p++) { split(rows[p], a, "\t"); pname[p] = a[1]; ptype[p] = a[2] }
        nclause = split(ENVIRON["SK_TEXT"], clause, /[.;:\n]/)
        ntag = split(tags, tag, ","); share = int(max / (n > 0 ? n : 1)); rem = max - share * n
      }
      /^## Registry/ { inreg = 1; next }
      inreg && /^## / { inreg = 0 }
      inreg && /^\|[ \t]*`/ {
        r++; skill[r] = trim($2); status[r] = trim($3); always[r] = trim($5); signals[r] = tolower(trim($6))
        phases[r] = trim($7); applies[r] = trim($8); weight[r] = trim($9) + 0; if (weight[r] == 0) weight[r] = 1
      }
      END {
        for (p = 1; p <= np; p++) {
          cap = share + (p <= rem ? 1 : 0); used = 0
          printf "  %s (%s, share %d):\n", pname[p], ptype[p], cap
          for (i = 1; i <= r; i++) {
            if (status[i] != "active") continue
            if (applies[i] != "any" && applies[i] != "—" && applies[i] != "" && !has(applies[i], ptype[p])) { continue }
            if (phases[i] != "—" && phases[i] != "" && !has(phases[i], phase)) continue
            hit = ""
            if (always[i] != "—" && always[i] != "") {
              k = split(always[i], al, /[ \t]*,[ \t]*/)
              for (j = 1; j <= k; j++) {
                s = trim(al[j])
                if (s == phase || s == ptype[p] || s == pname[p] || s == ptype[p] "@" phase || s == pname[p] "@" phase) hit = s
              }
            }
            if (hit != "") {
              if (skill[i] in loaded) continue
              loaded[skill[i]] = 1; used++
              printf "    load  .claude/skills/%s/SKILL.md  (Always: %s%s)\n", skill[i], hit, (used > cap ? ", over budget" : "")
              continue
            }
            if (signals[i] == "—" || signals[i] == "") continue
            t = 0; c = 0; tl = ""; cl = ""
            k = split(signals[i], sg, /[ \t]*,[ \t]*/)
            for (j = 1; j <= k; j++) {
              s = trim(sg[j]); if (s == "") continue
              for (m = 1; m <= ntag; m++) if (tag[m] == s) { t++; tl = tl (tl ? "," : "") s }
              cc = ctxcount(s); if (cc > 0) { c++; cl = cl (cl ? "," : "") s }
            }
            score = weight[i] * (3 * t + c)
            if (score > 0) { cand[p, ++nc[p]] = i; sc[p, nc[p]] = score; why[p, nc[p]] = sprintf("score %d = %d x (3x%d tag [%s] + %d context [%s])", score, weight[i], t, tl, c, cl) }
          }
          for (u = 1; u <= nc[p]; u++) for (b = u + 1; b <= nc[p]; b++) if (sc[p, b] > sc[p, u]) {
            x = cand[p, u]; cand[p, u] = cand[p, b]; cand[p, b] = x
            x = sc[p, u]; sc[p, u] = sc[p, b]; sc[p, b] = x
            x = why[p, u]; why[p, u] = why[p, b]; why[p, b] = x
          }
          for (u = 1; u <= nc[p]; u++) {
            i = cand[p, u]
            if (skill[i] in loaded) continue
            if (used < cap) { loaded[skill[i]] = 1; used++; printf "    load  .claude/skills/%s/SKILL.md  (%s)\n", skill[i], why[p, u] }
            else printf "    skip  %s  (%s, below share)\n", skill[i], why[p, u]
          }
          if (used == 0) print "    none"
        }
      }
    ' "$REGISTRY"
  fi
fi

# ── Rules matching the diff (review / verify) ────────────────────────────────
# A `paths:` glob as an anchored regex: `**/` any directories (or none), `**` anything, `*` and `?` within
# one path segment, `{a,b}` alternatives.
glob_re() {
  printf '%s' "$1" | awk '{
    s = $0; out = ""; brace = 0
    for (i = 1; i <= length(s); i++) {
      ch = substr(s, i, 1)
      if (substr(s, i, 3) == "**/") { out = out "(.*/)?"; i += 2; continue }
      if (substr(s, i, 2) == "**")  { out = out ".*"; i += 1; continue }
      if (ch == "*") out = out "[^/]*"
      else if (ch == "?") out = out "[^/]"
      else if (ch == "{") { out = out "("; brace = 1 }
      else if (ch == "}" && brace) { out = out ")"; brace = 0 }
      else if (ch == "," && brace) out = out "|"
      else if (index(".+()|^$[]\\", ch)) out = out "\\" ch
      else out = out ch
    }
    print "^" out "$"
  }'
}
if [[ "$CMD" == review || "$CMD" == verify ]]; then
  BASE=$(sk_profile_get "$ROOT" vcs.base_branch dev)
  CHANGED=$(git diff --name-only "${BASE}...HEAD" 2>/dev/null; git diff --name-only 2>/dev/null)
  if [[ -n "$SCOPE" ]]; then
    ROOTS=$(printf '%s\n' "$SCOPE" | cut -f3 | sed '/^$/d')
    CHANGED=$(printf '%s\n' "$CHANGED" | sort -u | while IFS= read -r c; do
      while IFS= read -r r; do [[ "$c" == "$r"/* ]] && { echo "$c"; break; }; done <<< "$ROOTS"; done)
  fi
  echo ""
  echo "rules matching the diff (${BASE}...HEAD, $(printf '%s\n' "$CHANGED" | sed '/^$/d' | wc -l | tr -d ' ') files):"
  found=0
  while IFS= read -r rule; do
    [[ -f "$rule" ]] || continue
    globs=$(awk '/^---[[:space:]]*$/ { fm++; if (fm == 2) exit; next } fm == 1 && /^[[:space:]]*-[[:space:]]/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); gsub(/^["\047]|["\047]$/, ""); print }' "$rule")
    [[ -n "$globs" ]] || continue
    hit=""
    while IFS= read -r g; do
      re=$(glob_re "$g")
      while IFS= read -r c; do
        [[ -n "$c" && "$c" =~ $re ]] && { hit="$c"; break 2; }
      done <<< "$CHANGED"
    done <<< "$globs"
    [[ -n "$hit" ]] && { echo "  $rule  (e.g. $hit)"; found=1; }
  done < <(find .claude/rules -name '*.md' 2>/dev/null | sort)
  [[ "$found" == 1 ]] || echo "  none"
fi
exit 0
