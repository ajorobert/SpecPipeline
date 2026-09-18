#!/usr/bin/env bash
# PreToolUse hook — validates that Edit/Write targets stay within the project root
# Exit 2 = block; Exit 0 = allow

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"

INPUT=$(cat)
# Extract file_path — prefer jq, fall back to sed (jq may be absent on Windows bash)
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
  FILE_PATH=$(echo "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Reject obvious path traversal attempts
if echo "$FILE_PATH" | grep -qE '\.\.(/|\\)'; then
  echo "Blocked: path traversal detected in \"$FILE_PATH\"" >&2
  echo "All file operations must stay within the project root: $PROJECT_ROOT" >&2
  exit 2
fi

# Reject absolute paths to system directories
SYSTEM_PREFIXES=("/etc/" "/usr/" "/bin/" "/sbin/" "/lib/" "/boot/" "/sys/" "/proc/" "/root/" "/var/")
for PREFIX in "${SYSTEM_PREFIXES[@]}"; do
  if [[ "$FILE_PATH" == "$PREFIX"* ]] || [[ "$FILE_PATH" == "//$PREFIX"* ]]; then
    echo "Blocked: attempt to edit system path \"$FILE_PATH\"" >&2
    echo "All file operations must stay within the project root: $PROJECT_ROOT" >&2
    exit 2
  fi
done

# Reject home-directory paths (~/... or /home/...)
if [[ "$FILE_PATH" == "~/"* ]] || [[ "$FILE_PATH" == "/home/"* ]]; then
  echo "Blocked: attempt to edit home directory path \"$FILE_PATH\"" >&2
  echo "All file operations must stay within the project root: $PROJECT_ROOT" >&2
  exit 2
fi

# If path is absolute, verify it resolves inside the project root
if [[ "$FILE_PATH" == /* ]]; then
  # Resolve canonical path if possible (may not exist yet for new files)
  RESOLVED=$(realpath -m "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
  PROJECT_RESOLVED=$(realpath -m "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")

  if [[ "$RESOLVED" != "$PROJECT_RESOLVED"* ]]; then
    echo "Blocked: \"$FILE_PATH\" is outside project root." >&2
    echo "Project root: $PROJECT_ROOT" >&2
    exit 2
  fi
fi

# Per-agent write_scope enforcement.
#
# Role resolution order (see .claude/skills/governance/status-model.md):
#   1. .claude/.active-skill-role — the role of the skill currently running, written by
#      post-skill.sh from that skill's subagent_type. This is authoritative: an orchestrator
#      delegates phases to other roles, and each delegated write must be judged by the role
#      that owns the phase, not by whoever started the session.
#   2. session.yaml `role` — the fallback for ad-hoc work outside any skill.
ACTIVE_ROLE_FILE="${PROJECT_ROOT}/.claude/.active-skill-role"
ROLE=""
ROLE_SOURCE=""
if [[ -f "$ACTIVE_ROLE_FILE" ]]; then
  ROLE=$(xargs < "$ACTIVE_ROLE_FILE" 2>/dev/null || true)
  [[ -n "$ROLE" ]] && ROLE_SOURCE="active skill"
fi
if [[ -z "$ROLE" ]]; then
  ROLE=$(sk_session_value "$PROJECT_ROOT" role)
  [[ -n "$ROLE" ]] && ROLE_SOURCE="session.yaml"
fi

if true; then
  if [[ -n "$ROLE" ]] && [[ "$ROLE" != "null" ]]; then
    case "$ROLE" in
      backend)  AGENT_FILE="backend-engineer.md"  ;;
      frontend) AGENT_FILE="frontend-engineer.md" ;;
      *)        AGENT_FILE="${ROLE}.md"           ;;
    esac
    AGENT_PATH="${PROJECT_ROOT}/.claude/agents/${AGENT_FILE}"

    if [[ -f "$AGENT_PATH" ]]; then
      DENY_GLOBS=$(awk '
        /^---[[:space:]]*$/ { fm++; if (fm == 2) exit; next }
        fm != 1 { next }
        /^write_scope:[[:space:]]*$/ { in_ws=1; next }
        in_ws && /^[a-zA-Z_]/ { in_ws=0 }
        in_ws && /^[[:space:]]+deny:[[:space:]]*$/ { in_deny=1; next }
        in_deny && /^[[:space:]]+[a-zA-Z_]/ { in_deny=0 }
        in_deny && /^[[:space:]]+-[[:space:]]/ {
          sub(/^[[:space:]]+-[[:space:]]*/, "")
          gsub(/^["'\'']|["'\'']$/, "")
          print
        }
      ' "$AGENT_PATH")

      if [[ -n "$DENY_GLOBS" ]]; then
        TARGET="$FILE_PATH"
        if [[ "$TARGET" == /* ]]; then
          RESOLVED_TARGET=$(realpath -m "$TARGET" 2>/dev/null || echo "$TARGET")
          PROJECT_RESOLVED=$(realpath -m "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")
          if [[ "$RESOLVED_TARGET" == "$PROJECT_RESOLVED"/* ]]; then
            TARGET="${RESOLVED_TARGET#$PROJECT_RESOLVED/}"
          fi
        fi

        shopt -s globstar nullglob extglob 2>/dev/null || true
        while IFS= read -r GLOB; do
          [[ -z "$GLOB" ]] && continue
          # shellcheck disable=SC2053
          if [[ "$TARGET" == $GLOB ]]; then
            echo "Blocked: role \"${ROLE}\" (from ${ROLE_SOURCE}) may not write to \"${TARGET}\"" >&2
            echo "  matched deny pattern: ${GLOB}" >&2
            echo "  see: .claude/agents/${AGENT_FILE} (write_scope.deny)" >&2
            exit 2
          fi
        done <<< "$DENY_GLOBS"
      fi
    fi
  fi
fi

exit 0
