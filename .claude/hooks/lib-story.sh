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

# Read a top-level scalar from .claude/session.yaml. Empty for missing / null.
sk_session_value() {
  local root="$1" key="$2" file value
  file="${root}/.claude/session.yaml"
  [[ -f "$file" ]] || return 0
  value=$(grep -E "^${key}:" "$file" 2>/dev/null | head -1 \
    | sed "s/^${key}:[[:space:]]*//" \
    | sed 's/[[:space:]]*#.*//' \
    | tr -d "\"'" \
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

# Set nested status.current (+ entered_at). Converts a legacy flat `status: x` to the nested shape.
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
    /^status:[ \t]*[^ \t#]/       { print "status:"; print "  current: " st; print "  entered_at: " ts; seen = 1; next }
    { print }
  ' "$file" > "${file}.speckit-tmp" && mv "${file}.speckit-tmp" "$file"
}

# Upsert a flat top-level frontmatter field, preserving any trailing comment.
sk_upsert_field() {
  local file="$1" field="$2" value="$3"
  awk -v f="$field" -v v="$value" '
    BEGIN { fm = 0; done = 0 }
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
    >> "${root}/.claude/skill-audit.log" 2>/dev/null || true
}

# ── Active-skill role ─────────────────────────────────────────────────────────
# write_scope.deny in .claude/agents/*.md must be evaluated against the role of the
# skill that is currently running, not the session role. A lead orchestrating sk.design
# must not be denied the architect's own output. post-skill.sh records the role in
# .claude/.active-skill-role; validate-path.sh prefers it; post-response.sh clears it.

# Print the framework role for a skill name, or nothing.
# SKILL.md `subagent_type:` → the agent file whose `name:` matches → that agent's `role:`.
sk_skill_role() {
  local root="$1" skill="$2" skill_file agent_name f role
  skill_file="${root}/.claude/skills/${skill}/SKILL.md"
  [[ -f "$skill_file" ]] || return 0
  agent_name=$(sk_fm_field "$skill_file" subagent_type)
  [[ -n "$agent_name" ]] || return 0
  for f in "${root}"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    if [[ "$(sk_fm_field "$f" name)" == "$agent_name" ]]; then
      role=$(sk_fm_field "$f" role)
      printf '%s' "$role"
      return 0
    fi
  done
  return 0
}

sk_set_active_role() {
  local root="$1" role="$2"
  [[ -n "$role" ]] || return 0
  printf '%s' "$role" > "${root}/.claude/.active-skill-role" 2>/dev/null || true
}

sk_clear_active_role() {
  local root="$1" f="${1}/.claude/.active-skill-role"
  [[ -f "$f" ]] || return 0
  find "$f" -delete 2>/dev/null || true
}
