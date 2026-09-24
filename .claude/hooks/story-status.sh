#!/usr/bin/env bash
# story-status.sh — the one status command. Skills call it; they never edit status.current by hand.
#
#   bash .claude/hooks/story-status.sh set <status> [--by <skill>]   transition the active story
#   bash .claude/hooks/story-status.sh field <name> <value>          set a roll-up field (test-status, …)
#   bash .claude/hooks/story-status.sh show                          active story, status, pending mirrors
#   bash .claude/hooks/story-status.sh mirror-pending                list tracker entries not yet mirrored
#   bash .claude/hooks/story-status.sh mirror-ack <id> [note]        the tracker issue was transitioned
#   bash .claude/hooks/story-status.sh mirror-fail <id> <reason>     the transition failed; kept for retry
#   bash .claude/hooks/story-status.sh mirror-retry                  re-queue every failed entry
#
# Every transition runs through sk_transition in lib-story.sh, which also queues the tracker mirror.
# See .claude/skills/governance/status-model.md and .claude/skills/governance/tracker-mirror.md.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-story.sh
source "${HOOK_DIR}/lib-story.sh"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "${HOOK_DIR}/../.." && pwd)}"

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

cmd="${1:-}"; shift || true

active_story() {
  local f
  f=$(sk_find_story_file "$PROJECT_ROOT")
  if [[ -z "$f" ]]; then
    echo "No active story — run /sk.session focus --unit <id> first." >&2
    exit 1
  fi
  printf '%s' "$f"
}

update_entry() {
  local id="$1" state="$2" note="$3" dir file tmp attempts
  dir=$(sk_outbox_dir "$PROJECT_ROOT")
  file="${dir}/${id}.json"
  [[ -f "$file" ]] || { echo "No outbox entry ${id} (see: story-status.sh mirror-pending)" >&2; exit 1; }
  attempts=$(sed -n 's/.*"attempts":\([0-9]*\).*/\1/p' "$file")
  attempts=$(( ${attempts:-0} + 1 ))
  note="${note//\"/\'}"
  tmp=$(sed -e "s/\"state\":\"[a-z]*\"/\"state\":\"${state}\"/" \
            -e "s/\"attempts\":[0-9]*/\"attempts\":${attempts}/" "$file" | sed 's/}[[:space:]]*$//')
  printf '%s,"note":"%s","updated_at":"%s"}\n' "$tmp" "$note" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$file"
  if [[ "$state" == "done" ]]; then
    mv "$file" "${dir}/done/${id}.json"
  fi
}

case "$cmd" in
  set)
    new="${1:-}"; shift || true
    by="manual"
    [[ "${1:-}" == "--by" ]] && by="${2:-manual}"
    [[ -n "$new" ]] || usage
    story=$(active_story)
    sk_transition "$PROJECT_ROOT" "$story" "$new" "$by" || exit 1
    echo "status.current = ${new}  ($(sk_rel_path "$PROJECT_ROOT" "$story"))"
    n=$(sk_tracker_count "$PROJECT_ROOT" pending)
    [[ "$n" -gt 0 ]] && echo "tracker mirror: ${n} pending — see .claude/skills/governance/tracker-mirror.md"
    ;;
  field)
    name="${1:-}"; value="${2:-}"
    [[ -n "$name" && -n "$value" ]] || usage
    case "$name" in
      test-status|verify-status|security-status|uat-status|jira_id|checkpoint_status|branch) ;;
      *) echo "field ${name} is not a roll-up field (test-status, verify-status, security-status, uat-status, jira_id, checkpoint_status, branch)" >&2; exit 1 ;;
    esac
    story=$(active_story)
    sk_upsert_field "$story" "$name" "$value"
    sk_audit "$PROJECT_ROOT" "field" "$(sk_fm_field "$story" id)" "${name}=${value}"
    echo "${name} = ${value}"
    ;;
  show)
    story=$(sk_find_story_file "$PROJECT_ROOT")
    if [[ -n "$story" ]]; then
      echo "story:   $(sk_fm_field "$story" id)  ($(sk_rel_path "$PROJECT_ROOT" "$story"))"
      echo "status:  $(sk_fm_field "$story" status.current)"
      echo "tracker: $(sk_fm_field "$story" jira_id)"
    else
      echo "story:   none active"
    fi
    echo "mirror:  $(sk_tracker_count "$PROJECT_ROOT" pending) pending, $(sk_tracker_count "$PROJECT_ROOT" failed) failed"
    ;;
  mirror-pending) sk_tracker_pending "$PROJECT_ROOT" ;;
  mirror-ack)
    [[ -n "${1:-}" ]] || usage
    update_entry "$1" done "${2:-}"; echo "mirrored: $1" ;;
  mirror-fail)
    [[ -n "${1:-}" && -n "${2:-}" ]] || usage
    update_entry "$1" failed "$2"; echo "kept for retry: $1 — $2" ;;
  mirror-retry)
    dir=$(sk_outbox_dir "$PROJECT_ROOT"); n=0
    for f in "$dir"/*.json; do
      [[ -f "$f" ]] && grep -q '"state":"failed"' "$f" || continue
      sed -i 's/"state":"failed"/"state":"pending"/' "$f"; n=$((n + 1))
    done
    echo "re-queued: ${n}" ;;
  *) usage ;;
esac
