#!/usr/bin/env bash
# PreToolUse(Read|Grep|Glob) — keeps humans-only paths and frozen units out of AI loading.
# Exit 2 = block; Exit 0 = allow.
#
# Guarded:
#   - every glob in .specify/profile.yaml → knowledge.never_autoload
#   - every shipped (frozen) unit under specs/intents/, except the active unit
# A guarded path is readable only when a human named it in the conversation: a user message contains
# the path, one of its parent directories, or the file name. See governance/profile.md.
# A repo-wide Grep/Glob with no path cannot be scoped here; the rule in governance/profile.md covers it.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"

command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "${HOOK_DIR}/../.." && pwd)}"

TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
if [[ -z "$TARGET" ]]; then
  # Glob without a path: judge its pattern's literal prefix (e.g. "docs/architecture/**/*.md").
  TARGET=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty' 2>/dev/null | sed 's/[*?[{].*$//')
  [[ "$(echo "$INPUT" | jq -r '.tool_name // empty')" == "Glob" ]] || TARGET=""
fi
[[ -z "$TARGET" ]] && exit 0

REL=$(sk_rel_path "$PROJECT_ROOT" "$TARGET")
sk_is_abs "$REL" && exit 0
REL="${REL%/}"
[[ -z "$REL" || "$REL" == "." ]] && exit 0

REASON=""
while IFS= read -r GLOB; do
  [[ -z "$GLOB" ]] && continue
  PAT="${GLOB//\*\*/*}"          # in [[ == ]], * already crosses '/'
  BASE="${PAT%%/\**}"            # the folder a trailing /** hangs from (a Grep/Glob path may be just that)
  # shellcheck disable=SC2053
  if [[ "$REL" == $PAT || "$REL" == "$BASE" ]]; then
    REASON="matches knowledge.never_autoload \"${GLOB}\" (humans-only)"
    break
  fi
done < <(sk_profile_list "$PROJECT_ROOT" knowledge.never_autoload)

if [[ -z "$REASON" ]]; then
  FROZEN=$(sk_frozen_unit_of "$PROJECT_ROOT" "$REL")
  if [[ -n "$FROZEN" && "$FROZEN" != "$(sk_active_unit_dir "$PROJECT_ROOT")" ]]; then
    REASON="lies in ${FROZEN}, a shipped (frozen) unit that is not the active unit"
  fi
fi
[[ -z "$REASON" ]] && exit 0

# Did a human name it? Scan the user's own messages (not tool results) in this session.
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  USER_TEXT=$(grep '"type":"user"' "$TRANSCRIPT" 2>/dev/null | jq -r '
    .message.content |
    if type == "string" then .
    elif type == "array" then (map(select(.type == "text") | .text) | join("\n"))
    else empty end' 2>/dev/null | tr '\\' '/')
  CANDIDATES=("$REL" "$(basename "$REL")")
  P="$REL"
  while [[ "$P" == */* ]]; do P="${P%/*}"; [[ "$P" == */* ]] && CANDIDATES+=("$P"); done
  USER_LC="${USER_TEXT,,}"
  for C in "${CANDIDATES[@]}"; do
    [[ ${#C} -ge 4 ]] || continue
    [[ "$USER_LC" == *"${C,,}"* ]] && exit 0
  done
fi

echo "Blocked: \"${REL}\" ${REASON}." >&2
echo "  It is read only when a human names it in the conversation (a path, parent folder or file name)." >&2
echo "  Ask the user if this file is needed; do not work around this guard." >&2
exit 2
