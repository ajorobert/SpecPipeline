#!/usr/bin/env bash
# PreToolUse(Edit|Write|NotebookEdit) — keeps writes inside the project root, enforces the running
# role's write_scope.deny, and keeps shipped (frozen) units read-only.
# Exit 2 = block; Exit 0 = allow.
#
# Paths are normalised first (sk_norm_path): `\` → `/`, and `C:/…`, `c:\…`, `/c/…` are all treated as
# absolute. Every rule below is evaluated on the project-relative path, identically on Linux, macOS
# and Windows.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
else
  FILE_PATH=$(echo "$INPUT" | sed -n 's/.*"\(file_path\|notebook_path\)"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\2/p')
  FILE_PATH="${FILE_PATH//\\\\/\\}"
fi
[[ -z "$FILE_PATH" ]] && exit 0

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
block() { echo "Blocked: $1" >&2; echo "Project root: $PROJECT_ROOT" >&2; exit 2; }

NORM=$(sk_norm_path "$FILE_PATH")

# Path traversal, in either separator style.
if [[ "/$NORM/" == */../* ]]; then
  block "path traversal in \"$FILE_PATH\""
fi
if [[ "$NORM" == "~"* ]]; then
  block "home-directory path \"$FILE_PATH\""
fi

REL=$(sk_rel_path "$PROJECT_ROOT" "$NORM")
if sk_is_abs "$REL"; then
  block "\"$FILE_PATH\" is outside the project root"
fi
[[ "$REL" == "." ]] && exit 0

# ── Role write scope ──────────────────────────────────────────────────────────
# The running skill's role (.specify/state/active-skill-role) wins; session.yaml `role` is the
# fallback for ad-hoc work outside any skill. See governance/status-model.md.
ROLE=$(sk_active_role "$PROJECT_ROOT")
ROLE_SOURCE="active skill"
if [[ -z "$ROLE" ]]; then
  ROLE=$(sk_session_value "$PROJECT_ROOT" role)
  ROLE_SOURCE="session.yaml"
fi

ROLES_FILE="${PROJECT_ROOT}/.claude/skills/governance/roles.yaml"
if [[ -n "$ROLE" && "$ROLE" != "null" && -f "$ROLES_FILE" ]]; then
  role_block() {
    echo "Blocked: role \"${ROLE}\" (from ${ROLE_SOURCE}) may not write to \"${REL}\"" >&2
    echo "  $1" >&2
    echo "  see: .claude/skills/governance/roles.yaml (${ROLE})" >&2
    exit 2
  }
  while IFS= read -r GLOB; do
    [[ -z "$GLOB" ]] && continue
    # shellcheck disable=SC2053
    [[ "$REL" == $GLOB ]] && role_block "matched deny pattern: ${GLOB}"
  done < <(sk_yaml_list "$ROLES_FILE" "${ROLE}.deny")
  if [[ "$(sk_yaml_get "$ROLES_FILE" "${ROLE}.code_roots")" == "deny" ]]; then
    while IFS=$'\t' read -r _ _ CODE_ROOT; do
      [[ -z "$CODE_ROOT" || "$CODE_ROOT" == "." ]] && continue
      [[ "$REL" == "$CODE_ROOT" || "$REL" == "$CODE_ROOT"/* ]] && role_block "inside code root ${CODE_ROOT}"
    done < <(sk_projects "$PROJECT_ROOT")
  fi
fi

# ── Frozen units ──────────────────────────────────────────────────────────────
# A shipped unit is read-only (governance/status-model.md → Promote, then freeze). Status moves go
# through story-status.sh (Bash), not Edit/Write. Only sk.hotfix may write there.
FROZEN=$(sk_frozen_unit_of "$PROJECT_ROOT" "$REL")
if [[ -n "$FROZEN" ]]; then
  case "$(sk_active_skill "$PROJECT_ROOT")" in
    sk.hotfix) ;;
    *)
      echo "Blocked: ${FROZEN} is shipped and frozen — \"${REL}\" is read-only." >&2
      echo "  Durable knowledge belongs in its home (ADR, domain spec, rule file); new work starts a new unit." >&2
      exit 2 ;;
  esac
fi

exit 0
