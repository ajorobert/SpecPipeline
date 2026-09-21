#!/usr/bin/env bash
# PreToolUse hook — checks a skill's declared preconditions before invocation.
# Exit 2 = block; Exit 0 = allow.
#
# Reads the `preconditions:` YAML block from the skill's SKILL.md and evaluates each entry.
# Supported rule forms:
#   - story.<dotted.path> == <value>             (values compare case-insensitively; empty/null = "null")
#   - story.<dotted.path> != <value>
#   - story.<dotted.path> in [<v1>, <v2>]
#   - file_exists: <glob>                        (glob relative to project root)
#   - file_contains: <glob> :: <ERE>             (at least one matching file contains the pattern)
#   - when <story condition> => <rule>           (rule evaluated only when the condition holds)
# Globs may use {unit_dir}: the active unit folder (e.g. specs/intents/001-auth/units/login).
#
# The active story is located via lib-story.sh (01-story/story.md of the active unit).

set -uo pipefail

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
SKILL_FILE="${PROJECT_ROOT}/.claude/skills/${SKILL_NAME}/SKILL.md"
if [[ ! -f "$SKILL_FILE" ]]; then
  shopt -s nullglob
  NESTED=("${PROJECT_ROOT}/.claude/skills"/*/"${SKILL_NAME}"/SKILL.md)
  shopt -u nullglob
  [[ ${#NESTED[@]} -gt 0 ]] && SKILL_FILE="${NESTED[0]}"
fi
[[ -f "$SKILL_FILE" ]] || exit 0

# Extract preconditions block (list items between `preconditions:` and the next top-level key or `---`)
PRECONDS=$(awk '
  /^preconditions:[[:space:]]*$/ { in_block=1; next }
  in_block && /^[a-zA-Z_][a-zA-Z0-9_-]*:/ { in_block=0 }
  in_block && /^---[[:space:]]*$/ { in_block=0 }
  in_block && /^[[:space:]]*-[[:space:]]/ {
    sub(/^[[:space:]]*-[[:space:]]*/, "")
    print
  }
' "$SKILL_FILE")

[[ -z "$PRECONDS" ]] && exit 0

STORY_FILE=$(sk_find_story_file "$PROJECT_ROOT")
UNIT_DIR_REL=""
if [[ -n "$STORY_FILE" ]]; then
  UNIT_DIR_ABS="$(dirname "$(dirname "$STORY_FILE")")"
  UNIT_DIR_REL="${UNIT_DIR_ABS#"$PROJECT_ROOT"/}"
fi

FAIL=0
FAIL_MESSAGES=()

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Evaluate a story condition. Echo "true"/"false"; echo "nostory" when no active story; "invalid" otherwise.
story_condition() {
  local expr="$1" path op expected actual item
  if [[ "$expr" =~ ^story\.([A-Za-z0-9_.-]+)[[:space:]]+in[[:space:]]+\[(.*)\][[:space:]]*$ ]]; then
    path="${BASH_REMATCH[1]}"; op="in"; expected="${BASH_REMATCH[2]}"
  elif [[ "$expr" =~ ^story\.([A-Za-z0-9_.-]+)[[:space:]]*(==|!=)[[:space:]]*(.+)$ ]]; then
    path="${BASH_REMATCH[1]}"; op="${BASH_REMATCH[2]}"; expected="${BASH_REMATCH[3]}"
  else
    echo "invalid"; return
  fi
  [[ -z "$STORY_FILE" ]] && { echo "nostory"; return; }
  actual=$(lower "$(sk_fm_field "$STORY_FILE" "$path")")
  [[ -z "$actual" ]] && actual="null"
  LAST_PATH="$path"; LAST_ACTUAL="$actual"
  case "$op" in
    "==") [[ "$actual" == "$(lower "$(echo "$expected" | sed "s/^[\"']//; s/[\"']$//" | xargs)")" ]] && echo true || echo false ;;
    "!=") [[ "$actual" != "$(lower "$(echo "$expected" | sed "s/^[\"']//; s/[\"']$//" | xargs)")" ]] && echo true || echo false ;;
    "in")
      IFS=',' read -ra ITEMS <<< "$expected"
      for item in "${ITEMS[@]}"; do
        item=$(lower "$(echo "$item" | sed "s/[\"']//g" | xargs)")
        [[ "$actual" == "$item" ]] && { echo true; return; }
      done
      echo false ;;
  esac
}

expand_glob() {
  local glob="$1"
  if [[ "$glob" == *"{unit_dir}"* ]]; then
    [[ -z "$UNIT_DIR_REL" ]] && return 1
    glob="${glob//\{unit_dir\}/$UNIT_DIR_REL}"
  fi
  printf '%s' "$glob"
}

eval_rule() {
  local rule="$1" glob pattern result f
  if [[ "$rule" =~ ^file_exists:[[:space:]]*(.+)$ ]]; then
    if ! glob=$(expand_glob "${BASH_REMATCH[1]}"); then
      FAIL=1; FAIL_MESSAGES+=("  - no active story — cannot resolve {unit_dir} in: ${rule}"); return
    fi
    if ! compgen -G "${PROJECT_ROOT}/${glob}" >/dev/null; then
      FAIL=1; FAIL_MESSAGES+=("  - required file(s) not found: ${glob}")
    fi
    return
  fi

  if [[ "$rule" =~ ^file_contains:[[:space:]]*(.+)[[:space:]]+::[[:space:]]+(.+)$ ]]; then
    pattern="${BASH_REMATCH[2]}"
    if ! glob=$(expand_glob "${BASH_REMATCH[1]}"); then
      FAIL=1; FAIL_MESSAGES+=("  - no active story — cannot resolve {unit_dir} in: ${rule}"); return
    fi
    while IFS= read -r f; do
      [[ -n "$f" ]] && grep -qE "$pattern" "$f" 2>/dev/null && return
    done < <(compgen -G "${PROJECT_ROOT}/${glob}")
    FAIL=1; FAIL_MESSAGES+=("  - no file matching ${glob} contains /${pattern}/")
    return
  fi

  if [[ "$rule" == story.* ]]; then
    result=$(story_condition "$rule")
    case "$result" in
      true) ;;
      false)
        FAIL=1
        FAIL_MESSAGES+=("  - $(story_condition_message "$rule")") ;;
      nostory)
        FAIL=1; FAIL_MESSAGES+=("  - no active story found — cannot evaluate: ${rule}") ;;
      *)
        echo "check-skill-preconditions.sh: WARNING — unrecognized rule: ${rule}" >&2 ;;
    esac
    return
  fi

  echo "check-skill-preconditions.sh: WARNING — unrecognized rule: ${rule}" >&2
}

story_condition_message() {
  local rule="$1" path actual
  [[ "$rule" =~ ^story\.([A-Za-z0-9_.-]+) ]] && path="${BASH_REMATCH[1]}"
  actual=$(sk_fm_field "$STORY_FILE" "$path")
  echo "story.${path} is \"${actual:-<empty>}\" — rule not met: ${rule}"
}

while IFS= read -r RULE; do
  RULE=$(printf '%s' "$RULE" | sed 's/[[:space:]]#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
  # YAML list items may be quoted (needed when a rule contains ": " or starts with "{")
  if [[ "$RULE" == \"*\" ]] || [[ "$RULE" == \'*\' ]]; then
    RULE="${RULE:1:${#RULE}-2}"
  fi
  [[ -z "$RULE" ]] && continue

  if [[ "$RULE" == when\ * ]] && [[ "$RULE" == *" => "* ]]; then
    COND="${RULE#when }"; COND="${COND%% => *}"
    THEN="${RULE#* => }"
    case "$(story_condition "$COND")" in
      true)    eval_rule "$THEN" ;;
      false)   ;;
      nostory) FAIL=1; FAIL_MESSAGES+=("  - no active story found — cannot evaluate: ${RULE}") ;;
      *)       echo "check-skill-preconditions.sh: WARNING — unrecognized condition: ${COND}" >&2 ;;
    esac
    continue
  fi

  eval_rule "$RULE"
done <<< "$PRECONDS"

if [[ "$FAIL" -eq 1 ]]; then
  echo "Skill \"${SKILL_NAME}\" blocked — preconditions not met:" >&2
  for MSG in "${FAIL_MESSAGES[@]}"; do
    echo "$MSG" >&2
  done
  [[ -n "$STORY_FILE" ]] && echo "Active story: ${STORY_FILE#"$PROJECT_ROOT"/}" >&2
  echo "" >&2
  echo "See ${SKILL_FILE#"$PROJECT_ROOT"/} for the declared preconditions." >&2
  exit 2
fi

exit 0
