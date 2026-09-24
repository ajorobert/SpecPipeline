#!/usr/bin/env bash
# Sets (or clears) the active-skill + role markers for a worker dispatched with the Agent tool.
#
# Why this exists: skill-start.sh runs on PreToolUse(Skill) and UserPromptSubmit. The Agent tool
# triggers neither, so a worker dispatched as a subagent would leave validate-path.sh evaluating the
# session role instead of the worker's own. PreToolUse hooks DO fire for tool calls made inside a
# subagent, so the markers set here are enforced for every write that worker makes.
#
# Usage, from an orchestrator, around each dispatch:
#   bash .claude/hooks/set-worker-role.sh sk.plan_sub_planproject           # before Agent(...)
#   bash .claude/hooks/set-worker-role.sh sk.implement_sub_codegen frontend # role override
#   bash .claude/hooks/set-worker-role.sh clear                             # after it returns
#
# The markers are one global pair of files. Dispatch workers ONE AT A TIME.
# Protocol: .claude/skills/governance/worker-dispatch.md

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "${HOOK_DIR}/../.." && pwd)}"
SKILL="${1:-}"
OVERRIDE="${2:-}"

if [[ -z "$SKILL" ]]; then
  echo "usage: set-worker-role.sh <worker-skill> [role-override] | clear" >&2
  exit 1
fi

if [[ "$SKILL" == "clear" ]]; then
  sk_clear_active_skill "$PROJECT_ROOT"
  echo "worker markers cleared"
  exit 0
fi

SKILL_FILE="${PROJECT_ROOT}/.claude/skills/${SKILL}/SKILL.md"
if [[ ! -f "$SKILL_FILE" ]]; then
  echo "set-worker-role.sh: no such skill: ${SKILL}" >&2
  exit 1
fi

if [[ -n "$OVERRIDE" ]]; then
  ROLE="$OVERRIDE"
else
  ROLE=$(sk_skill_role "$PROJECT_ROOT" "$SKILL")
fi

if [[ -z "$ROLE" ]]; then
  echo "set-worker-role.sh: WARNING — no role resolved for ${SKILL}" >&2
  echo "  (subagent_type: missing in SKILL.md, or no .claude/agents/*.md declares that name)" >&2
  echo "  write_scope will fall back to session.yaml — the worker runs effectively unguarded." >&2
else
  # validate-path.sh resolves the role to an agent file the same way; warn when that file is absent,
  # because a missing agent file means write_scope.deny is silently not enforced.
  case "$ROLE" in
    backend)  AGENT_FILE="backend-engineer.md"  ;;
    frontend) AGENT_FILE="frontend-engineer.md" ;;
    mobile)   AGENT_FILE="mobile-engineer.md"   ;;
    *)        AGENT_FILE="${ROLE}.md"           ;;
  esac
  if [[ ! -f "${PROJECT_ROOT}/.claude/agents/${AGENT_FILE}" ]]; then
    echo "set-worker-role.sh: WARNING — role \"${ROLE}\" has no agent file (.claude/agents/${AGENT_FILE})" >&2
    echo "  validate-path.sh will enforce no write_scope for this worker." >&2
  fi
fi

sk_set_active_skill "$PROJECT_ROOT" "$SKILL" "$ROLE"
echo "worker markers set: ${SKILL} -> role ${ROLE:-<none>}"
