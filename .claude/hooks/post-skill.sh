#!/usr/bin/env bash
# PostToolUse hook — fires when the Skill tool is invoked.
#
# Unconditional skills (no pass/fail): update story status immediately.
# Conditional skills (need pass/fail from response): write .last-skill so
# the Stop hook (post-response.sh) can finish the job after Claude responds.
#
# Exit 0 always — this hook is bookkeeping only and must never block Claude.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
  SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
else
  SKILL_NAME=$(echo "$INPUT" | sed -n 's/.*"skill"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

if [[ -z "$SKILL_NAME" ]] || [[ "$SKILL_NAME" != sk.* ]]; then
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "${HOOK_DIR}/../.." && pwd)}"
LAST_SKILL_FILE="${PROJECT_ROOT}/.claude/.last-skill"

# Conditional skills — defer to Stop hook; write .last-skill and exit
case "$SKILL_NAME" in
  sk.test|sk.review|sk.verify)
    echo "$SKILL_NAME" > "$LAST_SKILL_FILE" 2>/dev/null || true
    exit 0
    ;;
esac

# Unconditional skills — map to status and update the story now
case "$SKILL_NAME" in
  sk.specify)   NEW_STATUS="draft"   ;;
  sk.plan)      NEW_STATUS="ready"   ;;
  sk.implement) NEW_STATUS="testing" ;;
  sk.ship)      NEW_STATUS="shipped" ;;
  *)            exit 0               ;;
esac

STORY_FILE=$(sk_find_story_file "$PROJECT_ROOT")
if [[ -z "$STORY_FILE" ]]; then
  [[ -n "$(sk_session_value "$PROJECT_ROOT" active_unit_id)$(sk_session_value "$PROJECT_ROOT" active_story_id)" ]] && \
    echo "post-skill.sh: WARNING — no 01-story/story.md found for the active unit/story" >&2
  exit 0
fi

sk_set_status "$STORY_FILE" "$NEW_STATUS" 2>/dev/null || {
  echo "post-skill.sh: WARNING — failed to update status in: ${STORY_FILE}" >&2
  exit 0
}

sk_audit "$PROJECT_ROOT" "$SKILL_NAME" "$(sk_fm_field "$STORY_FILE" id)" "$NEW_STATUS"
exit 0
