#!/usr/bin/env bash
# lib-story.sh — shared helpers for SpecKit hooks. Source it; do not execute it.
#
# Story location (canonical): specs/intents/{intent}/units/{unit}/01-story/story.md
#   1. specs/intents/*/units/{active_unit_id}/01-story/story.md
#   2. scan specs/intents/*/units/*/01-story/story.md for frontmatter id == active_story_id
#   3. scan for frontmatter unit == active_unit_id
# Status is nested in frontmatter (see templates/artifacts/story-template.md):
#   status:
#     current: draft
#     entered_at: 2026-01-01T00:00:00Z
#
# Runtime state (per developer, gitignored) lives in .specify/state/ — never under .claude/, which
# Claude Code treats as a sensitive path and refuses to write under acceptEdits or headless runs.

_SK_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-profile.sh
source "${_SK_LIB_DIR}/lib-profile.sh"

SK_STATUSES="draft ready in-progress testing review verify security-review done shipped review-rejected rolled-back"

sk_state_dir() {
  local d="${1}/.specify/state"
  mkdir -p "$d" 2>/dev/null || true
  printf '%s' "$d"
}

sk_session_file() { printf '%s' "${1}/.specify/state/session.yaml"; }

# Normalise a tool path for comparison: backslashes → '/', drive letters upper-cased, and
# `/c/...` (Git Bash) or `C:\...` forms mapped to one `C:/...` form. Relative paths pass through.
sk_norm_path() {
  local p="${1//\\//}"
  # On Windows (Git Bash / MSYS / Cygwin) every POSIX absolute path — /c/…, /tmp/…, /cygdrive/… —
  # maps to one drive path. Elsewhere cygpath does not exist and POSIX paths pass through.
  if [[ "$p" == /* && "$p" != //* ]] && command -v cygpath >/dev/null 2>&1; then
    p=$(cygpath -m "$p" 2>/dev/null || printf '%s' "$p")
  fi
  if [[ "$p" =~ ^([A-Za-z]):(/.*)?$ ]]; then
    p="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]'):${BASH_REMATCH[2]}"
  fi
  while [[ "$p" == *//* && "$p" != //* ]]; do p="${p//\/\//\/}"; done
  printf '%s' "${p%/}"
}

# True when a normalised path is absolute on any OS (POSIX `/…`, Windows `C:/…`, UNC `//host/…`).
sk_is_abs() { [[ "$1" == /* || "$1" =~ ^[A-Za-z]:/ || "$1" =~ ^[A-Za-z]:$ ]]; }

# Print a path relative to the project root, or the normalised absolute path when it lies outside.
sk_rel_path() {
  local root path
  root=$(sk_norm_path "$1"); path=$(sk_norm_path "$2")
  if ! sk_is_abs "$path"; then printf '%s' "${path#./}"; return; fi
  if command -v realpath >/dev/null 2>&1; then
    path=$(sk_norm_path "$(realpath -m "$path" 2>/dev/null || printf '%s' "$path")")
    root=$(sk_norm_path "$(realpath -m "$root" 2>/dev/null || printf '%s' "$root")")
  fi
  local lp lr
  lp=$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]'); lr=$(printf '%s' "$root" | tr '[:upper:]' '[:lower:]')
  if [[ "$lp" == "$lr" ]]; then printf '.'; return; fi
  if [[ "$lp" == "$lr"/* ]]; then printf '%s' "${path:${#root}+1}"; return; fi
  printf '%s' "$path"
}

# Read a top-level scalar from the session file. Empty for missing / null.
sk_session_value() {
  local file value
  file=$(sk_session_file "$1")
  [[ -f "$file" ]] || return 0
  value=$(grep -E "^${2}:" "$file" 2>/dev/null | head -1 \
    | sed "s/^${2}:[[:space:]]*//" \
    | sed 's/[[:space:]]*#.*//' \
    | tr -d "\"'\r" \
    | xargs 2>/dev/null || true)
  [[ "$value" == "null" ]] && value=""
  printf '%s' "$value"
}

# Print a frontmatter field by dotted path (e.g. status.current). Empty for missing / null.
sk_fm_field() {
  local file="$1" path="$2" value
  [[ -f "$file" ]] || return 0
  value=$(awk -v path="$path" '
    BEGIN { n = split(path, parts, "."); fm = 0; allowed = 0 }
    { sub(/\r$/, "") }
    /^---[[:space:]]*$/ { fm++; if (fm == 2) exit; next }
    fm != 1 { next }
    {
      match($0, /^ */); indent = RLENGTH
      line = substr($0, indent + 1)
      if (line ~ /^#/ || line == "") next
      depth = int(indent / 2)
      if (depth > allowed) next
      if (!match(line, /^[A-Za-z_][A-Za-z0-9_-]*:/)) next
      key = substr(line, 1, RLENGTH - 1)
      rest = substr(line, RLENGTH + 1)
      sub(/^[ \t]*/, "", rest)
      sub(/[ \t]+#.*$/, "", rest)
      gsub(/^["\047]|["\047]$/, "", rest)
      allowed = depth
      if (key != parts[depth + 1]) next
      if (depth == n - 1) { print rest; exit }
      allowed = depth + 1
    }
  ' "$file")
  [[ "$value" == "null" ]] && value=""
  printf '%s' "$value"
}

# Print the active story file path, or nothing. Runs in a subshell so shopt changes do not leak.
sk_find_story_file() (
  local root="$1" unit story f
  unit=$(sk_session_value "$root" active_unit_id)
  story=$(sk_session_value "$root" active_story_id)
  shopt -s nullglob
  if [[ -n "$unit" ]]; then
    for f in "$root"/specs/intents/*/units/"$unit"/01-story/story.md; do
      printf '%s' "$f"; return 0
    done
  fi
  if [[ -n "$story" ]]; then
    for f in "$root"/specs/intents/*/units/*/01-story/story.md; do
      if [[ "$(sk_fm_field "$f" id)" == "$story" ]]; then printf '%s' "$f"; return 0; fi
    done
  fi
  if [[ -n "$unit" ]]; then
    for f in "$root"/specs/intents/*/units/*/01-story/story.md; do
      if [[ "$(sk_fm_field "$f" unit)" == "$unit" ]]; then printf '%s' "$f"; return 0; fi
    done
  fi
  return 0
)

# Relative unit directory (specs/intents/{i}/units/{u}) of the active story, or nothing.
sk_active_unit_dir() {
  local story
  story=$(sk_find_story_file "$1")
  [[ -n "$story" ]] || return 0
  sk_rel_path "$1" "$(dirname "$(dirname "$story")")"
}

# Low-level writer: set nested status.current (+ entered_at). Use sk_transition, not this.
sk_set_status() {
  local file="$1" new_status="$2" ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  awk -v st="$new_status" -v ts="$ts" '
    function comment(s) { return match(s, /[ \t]#.*/) ? " " substr(s, RSTART + 1) : "" }
    function close_block() {
      if (inblk) {
        if (!did_cur) print "  current: " st
        if (!did_ent) print "  entered_at: " ts
        inblk = 0
      }
    }
    BEGIN { fm = 0; inblk = 0; seen = 0; did_cur = 0; did_ent = 0 }
    { sub(/\r$/, "") }
    /^---[[:space:]]*$/ {
      fm++
      if (fm == 2) {
        close_block()
        if (!seen) { print "status:"; print "  current: " st; print "  entered_at: " ts; seen = 1 }
      }
      print; next
    }
    fm != 1 { print; next }
    inblk && /^[ \t]+current:/    { print "  current: " st comment($0); did_cur = 1; next }
    inblk && /^[ \t]+entered_at:/ { print "  entered_at: " ts comment($0); did_ent = 1; next }
    inblk && /^[ \t]/             { print; next }
    inblk                         { close_block() }
    /^status:[ \t]*(#.*)?$/       { print; inblk = 1; seen = 1; next }
    { print }
  ' "$file" > "${file}.speckit-tmp" && mv "${file}.speckit-tmp" "$file"
}

# Upsert a flat top-level frontmatter field, preserving any trailing comment.
sk_upsert_field() {
  local file="$1" field="$2" value="$3"
  awk -v f="$field" -v v="$value" '
    BEGIN { fm = 0; done = 0 }
    { sub(/\r$/, "") }
    /^---[[:space:]]*$/ {
      fm++
      if (fm == 2 && !done) { print f ": " v; done = 1 }
      print; next
    }
    fm == 1 && index($0, f ":") == 1 {
      c = match($0, /[ \t]#.*/) ? " " substr($0, RSTART + 1) : ""
      print f ": " v c; done = 1; next
    }
    { print }
  ' "$file" > "${file}.speckit-tmp" && mv "${file}.speckit-tmp" "$file"
}

sk_audit() {
  local root="$1" skill="$2" story="$3" status="$4"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") | ${skill} | ${story} | ${status}" \
    >> "$(sk_state_dir "$root")/skill-audit.log" 2>/dev/null || true
}

sk_valid_status() { [[ " $SK_STATUSES " == *" $1 "* ]]; }

# ── The one status transition ─────────────────────────────────────────────────
# Every status change — from a hook or from a skill through story-status.sh — goes through here:
# validate → write status.current → audit → queue the tracker mirror (governance/tracker-mirror.md).
# sk_transition <root> <story-file> <new-status> <actor>
sk_transition() {
  local root="$1" file="$2" new="$3" actor="$4" old
  sk_valid_status "$new" || { echo "invalid status: ${new} (valid: ${SK_STATUSES})" >&2; return 1; }
  [[ -f "$file" ]] || { echo "story file not found: ${file}" >&2; return 1; }
  old=$(sk_fm_field "$file" status.current)
  [[ "$old" == "$new" ]] && return 0
  sk_set_status "$file" "$new" || return 1
  sk_audit "$root" "$actor" "$(sk_fm_field "$file" id)" "$new"
  sk_tracker_enqueue "$root" "$file" "$old" "$new" "$actor"
  return 0
}

# ── Tracker mirror outbox ─────────────────────────────────────────────────────
# The framework owns ID and status; the tracker follows. Hooks cannot reach the tracker (only the model
# can, through its MCP connector), so each transition is queued as one JSON file and the model drains
# the queue. Stop (post-response.sh) blocks the turn's end while entries are pending.
sk_outbox_dir() {
  local d
  d="$(sk_state_dir "$1")/tracker-outbox"
  mkdir -p "$d/done" 2>/dev/null || true
  printf '%s' "$d"
}

sk_tracker_enabled() {
  [[ "$(sk_profile_get "$1" tracker.kind none)" != "none" ]] \
    && [[ "$(sk_profile_get "$1" tracker.mode mirror)" == "mirror" ]]
}

sk_tracker_enqueue() {
  local root="$1" file="$2" from="$3" to="$4" actor="$5" issue story id dir
  sk_tracker_enabled "$root" || return 0
  story=$(sk_fm_field "$file" id)
  issue=$(sk_fm_field "$file" jira_id)
  [[ -z "$issue" ]] && issue=$(sk_fm_field "$file" tracker_id)
  if [[ -z "$issue" ]]; then
    echo "tracker mirror: story ${story:-?} has no jira_id — transition ${from:-none} → ${to} not mirrored" >&2
    return 0
  fi
  dir=$(sk_outbox_dir "$root")
  id="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"
  printf '{"id":"%s","issue":"%s","story":"%s","from":"%s","to":"%s","actor":"%s","state":"pending","attempts":0,"queued_at":"%s"}\n' \
    "$id" "$issue" "$story" "${from:-none}" "$to" "$actor" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    > "${dir}/${id}.json"
}

# Print "id issue from→to (state)" for every entry that is not done, oldest first.
sk_tracker_pending() {
  local dir f
  dir=$(sk_outbox_dir "$1")
  for f in "$dir"/*.json; do
    [[ -f "$f" ]] || continue
    sed -n 's/.*"id":"\([^"]*\)".*"issue":"\([^"]*\)".*"from":"\([^"]*\)".*"to":"\([^"]*\)".*"state":"\([^"]*\)".*"attempts":\([0-9]*\).*/\1 \2 \3→\4 (\5, attempts \6)/p' "$f"
  done
}

sk_tracker_count() {
  local state="${2:-pending}" dir n=0 f
  dir=$(sk_outbox_dir "$1")
  for f in "$dir"/*.json; do
    [[ -f "$f" ]] && grep -q "\"state\":\"${state}\"" "$f" && n=$((n + 1))
  done
  printf '%s' "$n"
}

# ── Active skill ──────────────────────────────────────────────────────────────
# write_scope.deny in .claude/agents/*.md is evaluated against the role of the skill that is running,
# not the session role. The skill-start hooks record the skill and its role; validate-path.sh prefers
# them; post-response.sh clears them at the end of the turn.

# Print the framework role for a skill name, or nothing.
# SKILL.md `subagent_type:` → the agent file whose `name:` matches → that agent's `role:`.
sk_skill_role() {
  local root="$1" skill="$2" skill_file agent_name f
  skill_file="${root}/.claude/skills/${skill}/SKILL.md"
  [[ -f "$skill_file" ]] || return 0
  agent_name=$(sk_fm_field "$skill_file" subagent_type)
  [[ -n "$agent_name" ]] || return 0
  for f in "${root}"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    if [[ "$(sk_fm_field "$f" name)" == "$agent_name" ]]; then
      sk_fm_field "$f" role
      return 0
    fi
  done
  return 0
}

sk_set_active_skill() {
  local root="$1" skill="$2" role="$3" dir
  dir=$(sk_state_dir "$root")
  printf '%s' "$skill" > "${dir}/active-skill" 2>/dev/null || true
  [[ -n "$role" ]] && printf '%s' "$role" > "${dir}/active-skill-role" 2>/dev/null || true
}

sk_active_skill() { [[ -f "${1}/.specify/state/active-skill" ]] && tr -d '[:space:]' < "${1}/.specify/state/active-skill"; }
sk_active_role()  { [[ -f "${1}/.specify/state/active-skill-role" ]] && tr -d '[:space:]' < "${1}/.specify/state/active-skill-role"; }

sk_clear_active_skill() {
  local f
  for f in "${1}/.specify/state/active-skill" "${1}/.specify/state/active-skill-role"; do
    [[ -f "$f" ]] && find "$f" -delete 2>/dev/null
  done
  return 0
}

# ── Skill start (shared by the Skill-tool and the slash-command paths) ────────
# The skill name from a hook payload: `.tool_input.skill` (Skill tool) or a leading `/sk.x` in
# `.prompt` (a user-typed command, which expands without any Skill tool call).
sk_skill_from_input() {
  local input="$1" name=""
  if command -v jq >/dev/null 2>&1; then
    name=$(printf '%s' "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null)
    if [[ -z "$name" ]]; then
      name=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null \
        | sed -n '1s/^[[:space:]]*\/\(sk\.[A-Za-z0-9_.-]*\).*/\1/p')
    fi
  else
    name=$(printf '%s' "$input" | sed -n 's/.*"skill"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    [[ -z "$name" ]] && name=$(printf '%s' "$input" \
      | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"[[:space:]]*\/\(sk\.[A-Za-z0-9_.-]*\).*/\1/p')
  fi
  name="${name%.}"
  [[ "$name" == sk.* ]] && printf '%s' "$name"
  return 0
}

# Conditional skills defer their transition to the Stop hook (SK_RESULT verdict).
sk_is_conditional() {
  case "$1" in sk.test|sk.review|sk.verify|sk.implement|sk.ship|sk.security-audit) return 0 ;; esac
  return 1
}

# Bookkeeping when a skill starts: active skill + role, the deferred-verdict marker, and the
# transitions that are known at invocation time (governance/status-model.md).
sk_on_skill_start() {
  local root="$1" skill="$2" story new=""
  sk_set_active_skill "$root" "$skill" "$(sk_skill_role "$root" "$skill")"
  if sk_is_conditional "$skill"; then
    printf '%s' "$skill" > "$(sk_state_dir "$root")/last-skill" 2>/dev/null || true
    return 0
  fi
  case "$skill" in
    sk.story_sub_specify) new="draft" ;;
    *) return 0 ;;
  esac
  # A brand-new unit has no story.md yet; the story template already starts at draft.
  story=$(sk_find_story_file "$root")
  [[ -n "$story" ]] || return 0
  sk_transition "$root" "$story" "$new" "$skill" || true
}

# ── Frozen units ──────────────────────────────────────────────────────────────
# A unit whose story is `shipped` is frozen: read-only, and excluded from loading unless it is the
# active unit. Print the unit dir (relative) when <rel-path> lies inside a frozen unit.
sk_frozen_unit_of() {
  local root="$1" rel="$2" unit_dir story st
  [[ "$rel" =~ ^(specs/intents/[^/]+/units/[^/]+)(/|$) ]] || return 0
  unit_dir="${BASH_REMATCH[1]}"
  story="${root}/${unit_dir}/01-story/story.md"
  [[ -f "$story" ]] || return 0
  st=$(sk_fm_field "$story" status.current)
  [[ "$st" == "shipped" ]] && printf '%s' "$unit_dir"
  return 0
}
