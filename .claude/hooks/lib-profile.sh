#!/usr/bin/env bash
# lib-profile.sh — read .specify/profile.yaml. Source it; do not execute it.
#
# The profile is project-owned and every key is optional; callers pass the default.
# Supported YAML subset (what templates/project/.specify/profile.yaml uses):
#   nested maps with 2-space indentation, scalar values, inline lists `[a, b]`,
#   block lists `- item`, and `# comments`. Anchors, multi-line scalars and flow maps are not supported.

sk_profile_file() { printf '%s' "${1}/.specify/profile.yaml"; }

# Print the raw value of a dotted key (e.g. vcs.base_branch). Empty when absent.
_sk_profile_raw() {
  local file="$1" path="$2"
  [[ -f "$file" ]] || return 0
  awk -v path="$path" '
    BEGIN { n = split(path, parts, "."); allowed = 0 }
    {
      line = $0
      sub(/\r$/, "", line)
      match(line, /^ */); indent = RLENGTH
      body = substr(line, indent + 1)
      if (body ~ /^#/ || body == "" || body ~ /^- /) next
      depth = int(indent / 2)
      if (depth > allowed) next
      if (!match(body, /^[A-Za-z_][A-Za-z0-9_.-]*:/)) next
      key = substr(body, 1, RLENGTH - 1)
      rest = substr(body, RLENGTH + 1)
      allowed = depth
      if (key != parts[depth + 1]) next
      if (depth == n - 1) {
        sub(/^[ \t]*/, "", rest)
        if (rest !~ /^["\047]/) sub(/[ \t]+#.*$/, "", rest)
        print rest; exit
      }
      allowed = depth + 1
    }
  ' "$file"
}

# sk_profile_get <root> <dotted.key> [default] — a scalar; the default when absent, empty or null.
sk_profile_get() {
  local value
  value=$(_sk_profile_raw "$(sk_profile_file "$1")" "$2")
  value="${value%\"}"; value="${value#\"}"; value="${value%\'}"; value="${value#\'}"
  [[ -z "$value" || "$value" == "null" || "$value" == "~" ]] && value="${3:-}"
  printf '%s' "$value"
}

# sk_profile_list <root> <dotted.key> — one item per line, from an inline or block list.
sk_profile_list() {
  local file raw
  file=$(sk_profile_file "$1")
  [[ -f "$file" ]] || return 0
  raw=$(_sk_profile_raw "$file" "$2")
  if [[ "$raw" == \[*\] ]]; then
    raw="${raw#[}"; raw="${raw%]}"
    printf '%s\n' "$raw" | tr ',' '\n' | sed "s/^[[:space:]]*//; s/[[:space:]]*$//; s/^[\"']//; s/[\"']$//" | sed '/^$/d'
    return 0
  fi
  [[ -n "$raw" ]] && return 0
  awk -v path="$2" '
    BEGIN { n = split(path, parts, "."); allowed = 0; inlist = 0 }
    {
      line = $0
      sub(/\r$/, "", line)
      match(line, /^ */); indent = RLENGTH
      body = substr(line, indent + 1)
      if (body ~ /^#/ || body == "") next
      if (inlist) {
        if (body ~ /^- / && indent >= want) {
          item = substr(body, 3)
          if (item !~ /^["\047]/) sub(/[ \t]+#.*$/, "", item)
          gsub(/^["\047]|["\047]$/, "", item)
          print item; next
        }
        exit
      }
      if (body ~ /^- /) next
      depth = int(indent / 2)
      if (depth > allowed) next
      if (!match(body, /^[A-Za-z_][A-Za-z0-9_.-]*:/)) next
      key = substr(body, 1, RLENGTH - 1)
      allowed = depth
      if (key != parts[depth + 1]) next
      if (depth == n - 1) { inlist = 1; want = indent; next }
      allowed = depth + 1
    }
  ' "$file"
}
