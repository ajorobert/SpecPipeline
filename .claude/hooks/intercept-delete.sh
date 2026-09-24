#!/usr/bin/env bash
# PreToolUse(Bash|PowerShell) — blocks delete commands and redirects to the archive workflow.
# Exit 2 = block; Exit 0 = allow.
#
# Matches a delete verb at the start of any command segment (after ; & | && || ` or $( ),
# so chained and piped forms are caught too. PowerShell verbs and aliases are included because the
# PowerShell tool reaches the filesystem without going through bash.

set -uo pipefail

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
  COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi
[[ -z "$COMMAND" ]] && exit 0

# Bash: rm rmdir unlink shred del · PowerShell: Remove-Item and its aliases ri rd erase, plus
# [System.IO.File]::Delete / [System.IO.Directory]::Delete.
VERBS='rm|rmdir|unlink|shred|del|erase|rd|ri|remove-item'
SEGMENT_START='(^|[;&|`]|&&|\|\||\$\()[[:space:]]*'
if printf '%s' "$COMMAND" | tr '\n' ';' | grep -qiE "${SEGMENT_START}(sudo[[:space:]]+)?(${VERBS})([[:space:]]|$)" \
  || printf '%s' "$COMMAND" | grep -qiE '\[(System\.)?IO\.(File|Directory)\]::Delete|xargs[[:space:]]+(-[^[:space:]]+[[:space:]]+)*rm([[:space:]]|$)|find[[:space:]].*[[:space:]]-delete([[:space:]]|$)'; then
  echo "Direct deletion is blocked in this project." >&2
  echo "" >&2
  echo "To remove a file, use the archive script instead:" >&2
  echo "  bash .claude/hooks/archive-file.sh \"<relative-path>\" \"<reason for removal>\"" >&2
  echo "" >&2
  echo "This moves the file to .archive/ and logs it for human review." >&2
  exit 2
fi

exit 0
