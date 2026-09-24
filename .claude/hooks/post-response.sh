#!/usr/bin/env bash
# Stop hook — fires after every Claude response.
# 1. Clears the per-turn active-skill marker.
# 2. Applies the SK_RESULT verdict of a conditional skill (marker .specify/state/last-skill) through the
#    one transition in lib-story.sh — see governance/status-model.md.
# 3. Tracker mirror: while outbox entries are pending, blocks the stop once and tells the model to push
#    them through its tracker connector — see governance/tracker-mirror.md.
# Never exits non-zero; blocking uses the JSON decision on stdout.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"

INPUT=$(cat)
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "${HOOK_DIR}/../.." && pwd)}"

# The active-skill marker lives for one turn only. Clear it first, whatever else happens,
# so a crashed or aborted skill cannot leave validate-path.sh evaluating a stale role.
sk_clear_active_skill "$PROJECT_ROOT"

command -v jq >/dev/null 2>&1 || exit 0

STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

apply_verdict() {
  local marker skill pass_status fail_status="" transcript last_line last_text verdict story new
  marker="$(sk_state_dir "$PROJECT_ROOT")/last-skill"
  [[ -f "$marker" ]] || return 0
  skill=$(tr -d '[:space:]' < "$marker")
  find "$marker" -delete 2>/dev/null || true

  case "$skill" in
    sk.implement)      pass_status="testing"         ;;
    sk.test)           pass_status="review"          ;;
    sk.review)         pass_status="verify"          ; fail_status="review-rejected" ;;
    sk.security-audit) pass_status="security-review" ;;
    sk.verify)         pass_status="done"            ;;
    sk.ship)           pass_status="shipped"         ;;
    *)                 return 0                      ;;
  esac

  transcript=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
  [[ -n "$transcript" && -f "$transcript" ]] || return 0
  last_line=$(tac "$transcript" | grep -m1 '"type":"assistant"' 2>/dev/null || true)
  [[ -n "$last_line" ]] || return 0
  last_text=$(echo "$last_line" | jq -r '
    .message.content |
    if type == "string" then .
    elif type == "array" then (map(select(.type == "text") | .text) | join(""))
    else "" end' 2>/dev/null || true)

  if echo "$last_text" | grep -qE "^SK_RESULT:[[:space:]]*PASS"; then verdict="PASS"
  elif echo "$last_text" | grep -qE "^SK_RESULT:[[:space:]]*FAIL"; then verdict="FAIL"
  else
    echo "post-response.sh: ${skill} ended without an SK_RESULT line — story status unchanged" >&2
    return 0
  fi

  story=$(sk_find_story_file "$PROJECT_ROOT")
  if [[ -z "$story" ]]; then
    echo "post-response.sh: WARNING — no 01-story/story.md found for the active unit/story" >&2
    return 0
  fi

  # Persist the verdict regardless of outcome so downstream preconditions (sk.ship) see it.
  case "$skill" in
    sk.test)   sk_upsert_field "$story" "test-status"   "$(echo "$verdict" | tr '[:upper:]' '[:lower:]')" ;;
    sk.verify) sk_upsert_field "$story" "verify-status" "$verdict" ;;
  esac

  if [[ "$verdict" == "PASS" ]]; then new="$pass_status"
  else
    [[ -z "$fail_status" ]] && return 0
    new="$fail_status"
  fi
  sk_transition "$PROJECT_ROOT" "$story" "$new" "$skill" \
    || echo "post-response.sh: WARNING — failed to update status in ${story}" >&2
}

[[ "$STOP_HOOK_ACTIVE" == "true" ]] || apply_verdict

# Tracker mirror. Block the stop at most once per turn (stop_hook_active guards the loop); entries the
# model could not push are marked failed and surface again on the next transition or sk.session status.
if sk_tracker_enabled "$PROJECT_ROOT" && [[ "$STOP_HOOK_ACTIVE" != "true" ]]; then
  pending=$(sk_tracker_count "$PROJECT_ROOT" pending)
  if [[ "$pending" -gt 0 ]]; then
    list=$(sk_tracker_pending "$PROJECT_ROOT" | grep '(pending' | sed 's/^/  /')
    reason="Tracker mirror: ${pending} story transition(s) are not yet reflected in $(sk_profile_get "$PROJECT_ROOT" tracker.kind jira).
${list}
Follow .claude/skills/governance/tracker-mirror.md: for each entry, transition the issue through the tracker connector, then run
  bash .claude/hooks/story-status.sh mirror-ack <id>
or, if it cannot be done now,
  bash .claude/hooks/story-status.sh mirror-fail <id> \"<reason>\""
    jq -n --arg r "$reason" '{decision: "block", reason: $r}'
    exit 0
  fi
fi

exit 0
