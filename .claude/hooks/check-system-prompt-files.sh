#!/usr/bin/env bash
# PostToolUse hook — warns when a system-prompt file is modified.
# These files are loaded at session start (CLAUDE.md and the always-loaded principles file
# ). Modifying them mid-session leaves the active system prompt stale.
#
# Exit 0 always — this hook is advisory only, never blocking.

set -uo pipefail

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
  FILE_PATH=$(echo "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Files Claude Code loads at session start: CLAUDE.md and the always-loaded principles file (a rule with no paths:).
SYSTEM_PROMPT_FILES=(
  "CLAUDE.md"
  ".claude/rules/principles.md"
)

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_ROOT="${PROJECT_ROOT%/}"

# Normalise backslashes to forward slashes (Windows paths via bash), then make relative.
FILE_PATH="${FILE_PATH//\\//}"
PROJECT_NORM="${PROJECT_ROOT//\\//}"
RELATIVE_PATH="$FILE_PATH"
shopt -s nocasematch
if [[ "$FILE_PATH" == "$PROJECT_NORM"/* ]]; then
  RELATIVE_PATH="${FILE_PATH:${#PROJECT_NORM}+1}"
fi
shopt -u nocasematch

for SP_FILE in "${SYSTEM_PROMPT_FILES[@]}"; do
  if [[ "$RELATIVE_PATH" == "$SP_FILE" ]]; then
    echo ""
    echo "⚠️  SYSTEM PROMPT FILE MODIFIED: $SP_FILE"
    echo "   This file is loaded into the system prompt at session start."
    echo "   The current session's system prompt is now STALE."
    echo "   ➜  Restart Claude Code before continuing to reload updated context."
    echo ""
    exit 0
  fi
done

exit 0
