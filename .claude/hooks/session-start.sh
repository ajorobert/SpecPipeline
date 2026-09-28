#!/usr/bin/env bash
# SessionStart hook — a new session starts with no running skill.
# Clears the active skill, its role and the pending SK_RESULT marker, so a skill left waiting at a gate
# in an earlier session never scopes this session's writes or receives this session's verdict.
# The session focus (.specify/state/session.yaml) is kept. Never exits non-zero.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"

cat >/dev/null
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "${HOOK_DIR}/../.." && pwd)}"
sk_clear_active_skill "$PROJECT_ROOT" all
exit 0
