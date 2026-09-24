#!/usr/bin/env bash
# Stop hook — logs prompt-cache metrics per assistant turn.
# Appends one JSONL row to .specify/state/cache-metrics.jsonl for the most recent
# assistant turn in the transcript. Captures every turn (sk.* or direct chat).
# Exit 0 always — bookkeeping only, must never block Claude.

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  # jq is required for this hook. Silently skip if missing.
  exit 0
fi

# Guard: if Claude is responding to hook output, do not recurse
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "${HOOK_DIR}/../.." && pwd)}"
METRICS_LOG="$(sk_state_dir "$PROJECT_ROOT")/cache-metrics.jsonl"

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]] && exit 0

# Find the most recent assistant turn that carries a usage block.
LAST_LINE=$(tac "$TRANSCRIPT_PATH" | grep -m1 '"cache_read_input_tokens"' 2>/dev/null || true)
[[ -z "$LAST_LINE" ]] && exit 0

# Walk backward through the transcript and pick the most recent Skill tool_use
# name. Empty string if the turn wasn't triggered by a /skill invocation.
SKILL_NAME=$(tac "$TRANSCRIPT_PATH" \
  | grep -m1 '"name":"Skill"' 2>/dev/null \
  | jq -r '
      (.message.content // [])
      | map(select(.type == "tool_use" and .name == "Skill"))
      | (.[0].input.skill // "")
    ' 2>/dev/null || true)

ACTIVE_STORY_ID=$(sk_session_value "$PROJECT_ROOT" active_story_id)
ROLE=$(sk_session_value "$PROJECT_ROOT" role)

# Emit one JSONL row. Use jq -c to produce compact, valid JSON.
echo "$LAST_LINE" | jq -c \
  --arg skill "$SKILL_NAME" \
  --arg story "$ACTIVE_STORY_ID" \
  --arg role "$ROLE" \
  '{
    timestamp:       .timestamp,
    sessionId:       .sessionId,
    model:           .message.model,
    skill_name:      $skill,
    active_story_id: $story,
    role:            $role,
    cache_read:      (.message.usage.cache_read_input_tokens // 0),
    cache_creation:  (.message.usage.cache_creation_input_tokens // 0),
    input_tokens:    (.message.usage.input_tokens // 0),
    output_tokens:   (.message.usage.output_tokens // 0),
    gitBranch:       (.gitBranch // ""),
    cwd:             (.cwd // "")
  }' >> "$METRICS_LOG" 2>/dev/null || true

exit 0
