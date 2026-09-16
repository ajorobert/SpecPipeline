#!/usr/bin/env bash
# Stop hook — fires after every Claude response.
# Only acts when post-skill.sh left a .last-skill file (sk.test / sk.review / sk.verify).
# Reads the transcript to find SK_RESULT: PASS or SK_RESULT: FAIL emitted by the skill.
# Exit 0 always — this hook is bookkeeping only and must never block Claude.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  # Without jq the transcript cannot be parsed reliably — skip bookkeeping.
  exit 0
fi

# Guard: if Claude is responding to hook output, do not recurse
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "${HOOK_DIR}/../.." && pwd)}"
LAST_SKILL_FILE="${PROJECT_ROOT}/.claude/.last-skill"

# No .last-skill → no conditional skill was recently invoked → nothing to do
if [[ ! -f "$LAST_SKILL_FILE" ]]; then
  exit 0
fi

# Read skill name and immediately clear the marker (even if we fail below)
SKILL_NAME=$(xargs < "$LAST_SKILL_FILE" 2>/dev/null)
: > "$LAST_SKILL_FILE" 2>/dev/null
find "$LAST_SKILL_FILE" -delete 2>/dev/null || true

case "$SKILL_NAME" in
  sk.test)   NEW_STATUS="review" ;;
  sk.review) NEW_STATUS="verify" ;;
  sk.verify) NEW_STATUS="done"   ;;
  *)         exit 0              ;;
esac

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Most recent assistant entry in the JSONL transcript
LAST_ASSISTANT_LINE=$(tac "$TRANSCRIPT_PATH" | grep -m1 '"type":"assistant"' 2>/dev/null || true)
[[ -z "$LAST_ASSISTANT_LINE" ]] && exit 0

LAST_TEXT=$(echo "$LAST_ASSISTANT_LINE" | jq -r '
  .message.content |
  if type == "string" then .
  elif type == "array" then (map(select(.type == "text") | .text) | join(""))
  else ""
  end
' 2>/dev/null || true)

if echo "$LAST_TEXT" | grep -qE "^SK_RESULT:[[:space:]]*PASS"; then
  VERDICT="PASS"
elif echo "$LAST_TEXT" | grep -qE "^SK_RESULT:[[:space:]]*FAIL"; then
  VERDICT="FAIL"
else
  exit 0
fi

STORY_FILE=$(sk_find_story_file "$PROJECT_ROOT")
if [[ -z "$STORY_FILE" ]]; then
  echo "post-response.sh: WARNING — no 01-story/story.md found for the active unit/story" >&2
  exit 0
fi

# Persist the verdict regardless of outcome so downstream preconditions (sk.ship) see it.
case "$SKILL_NAME" in
  sk.test)   sk_upsert_field "$STORY_FILE" "test-status"   "$(echo "$VERDICT" | tr '[:upper:]' '[:lower:]')" ;;
  sk.verify) sk_upsert_field "$STORY_FILE" "verify-status" "$VERDICT" ;;
esac

# Story status only advances on PASS
[[ "$VERDICT" != "PASS" ]] && exit 0

sk_set_status "$STORY_FILE" "$NEW_STATUS" 2>/dev/null || {
  echo "post-response.sh: WARNING — failed to update status in: ${STORY_FILE}" >&2
  exit 0
}

sk_audit "$PROJECT_ROOT" "$SKILL_NAME" "$(sk_fm_field "$STORY_FILE" id)" "$NEW_STATUS"
exit 0
