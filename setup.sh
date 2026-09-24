#!/usr/bin/env bash
# SpecKit-SSD-SDLC setup.sh
# Run after: git subtree add|pull --prefix=.speckit <framework-url> main --squash
#
# Usage:
#   bash .speckit/setup.sh          # interactive (asks before changing managed regions)
#   bash .speckit/setup.sh --yes    # non-interactive: apply managed-region updates without asking
#                                   # (also the behaviour when stdin is not a terminal)
#   bash .speckit/setup.sh --gemini # also maintain GEMINI.md (same as install.gemini: true in the profile)
#
# Ownership contract — setup.sh touches ONLY these paths:
#   Synced (rsync --delete scoped to each path; the sk.* namespace is framework-reserved):
#     .claude/skills/sk.*   .claude/skills/governance
#     .claude/agents/<framework agent files, by name>   .claude/hooks/*.sh
#   Written:  .claude/.speckit-manifest (version + owned paths)
#   Merged:   .claude/settings.json (hooks added if absent, deny unioned; allow and defaultMode never touched)
#   Spliced:  CLAUDE.md (and GEMINI.md when opted in) — only between the SPECKIT-SSD-SDLC MANAGED markers,
#             rendered from .specify/profile.yaml
#   Created:  .specify/state/ (per-developer runtime state) and its .gitignore entry
# It creates no project knowledge files: /sk.init writes .specify/profile.yaml, .specify/memory/projects/**
# and .specify/memory/constitution.md, and each knowledge home is created by its writer on first use
# (.claude/skills/governance/profile.md). .specify/profile.yaml is read, never written.
# Everything else under .claude/ (settings.local.json, commands/, rules/, non-sk.* skills and the skills
# README registry, other agents, …) is project-owned and is never read, written, archived, or listed.
# skills_archive/ is never copied — project owners copy the packs they want (see skills_archive/README.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SPECKIT_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
TEMPLATES_ROOT="$SCRIPT_DIR/templates/root"
VERSION="$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION")"

ASSUME_YES=false
WANT_GEMINI=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=true ;;
    --gemini) WANT_GEMINI=true ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done
[ -t 0 ] || ASSUME_YES=true

FRAMEWORK_SKILL_DIRS=(governance)
FRAMEWORK_AGENTS=(architect.md backend-engineer.md backend-qa.md frontend-engineer.md frontend-qa.md lead.md po.md security.md)
MANAGED_START="<!-- SPECKIT-SSD-SDLC MANAGED -->"
MANAGED_END="<!-- END SPECKIT-SSD-SDLC MANAGED -->"

if [ "$PROJECT_ROOT" = "$SCRIPT_DIR" ]; then
  echo "ERROR: setup.sh must run from the framework subtree (e.g. .speckit/setup.sh), not the project root." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required (settings merge and every SpecKit hook depend on it)." >&2
  exit 1
fi

echo ""
echo "SpecKit-SSD-SDLC setup v$VERSION"
echo "Framework: $SCRIPT_DIR"
echo "Project:   $PROJECT_ROOT"
echo ""

confirm() {
  local prompt="$1"
  if [ "$ASSUME_YES" = true ]; then return 0; fi
  printf "%s [y/N]: " "$prompt"
  local response
  read -r response
  [ "$response" = "y" ] || [ "$response" = "Y" ]
}

remove_tree() {
  find "$1" -depth -delete
}

# Mirror one framework-owned directory. --delete is scoped to this directory only.
sync_dir() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$src/" "$dst/"
  else
    find "$dst" -mindepth 1 -depth -delete
    cp -R "$src/." "$dst/"
  fi
}

# ─────────────────────────────────────────────
# PHASE 1: Sync framework-owned paths
# ─────────────────────────────────────────────
echo "→ Syncing framework-owned paths ..."
SRC_SKILLS="$SCRIPT_DIR/.claude/skills"
DST_SKILLS="$PROJECT_ROOT/.claude/skills"
mkdir -p "$DST_SKILLS" "$PROJECT_ROOT/.claude/agents" "$PROJECT_ROOT/.claude/hooks"

shopt -s nullglob
for src in "$SRC_SKILLS"/sk.*; do
  [ -d "$src" ] || continue
  sync_dir "$src" "$DST_SKILLS/$(basename "$src")"
done
# sk.* is the framework namespace: a sk.* directory that the framework does not ship is removed.
for dst in "$DST_SKILLS"/sk.*; do
  [ -d "$dst" ] || continue
  if [ ! -d "$SRC_SKILLS/$(basename "$dst")" ]; then
    remove_tree "$dst"
    echo "  - removed obsolete framework skill $(basename "$dst")"
  fi
done
for name in "${FRAMEWORK_SKILL_DIRS[@]}"; do
  sync_dir "$SRC_SKILLS/$name" "$DST_SKILLS/$name"
done
for agent in "${FRAMEWORK_AGENTS[@]}"; do
  cp "$SCRIPT_DIR/.claude/agents/$agent" "$PROJECT_ROOT/.claude/agents/$agent"
done
for hook in "$SCRIPT_DIR/.claude/hooks"/*.sh; do
  cp "$hook" "$PROJECT_ROOT/.claude/hooks/$(basename "$hook")"
  chmod +x "$PROJECT_ROOT/.claude/hooks/$(basename "$hook")"
done
shopt -u nullglob
echo "  ✓ skills (sk.*, governance), agents, hooks"

case "$SCRIPT_DIR/" in
  "$PROJECT_ROOT"/*) FRAMEWORK_REL="${SCRIPT_DIR#"$PROJECT_ROOT"/}" ;;
  *)                 FRAMEWORK_REL="$SCRIPT_DIR" ;;
esac

MANIFEST="$PROJECT_ROOT/.claude/.speckit-manifest"
{
  echo "# SpecKit-SSD-SDLC install manifest — rewritten by setup.sh on every run. Do not edit."
  echo "version: $VERSION"
  echo "framework_dir: $FRAMEWORK_REL"
  echo "scripts_dir: $FRAMEWORK_REL/scripts"
  echo "templates_dir: $FRAMEWORK_REL/templates"
  echo "owned:"
  echo "  - .claude/skills/sk.*"
  for name in "${FRAMEWORK_SKILL_DIRS[@]}"; do echo "  - .claude/skills/$name"; done
  for agent in "${FRAMEWORK_AGENTS[@]}"; do echo "  - .claude/agents/$agent"; done
  echo "  - .claude/hooks/*.sh"
} > "$MANIFEST"
echo "  ✓ .claude/.speckit-manifest (v$VERSION)"

# ─────────────────────────────────────────────
# PHASE 2: Merge settings.json (policy surface only)
# ─────────────────────────────────────────────
SETTINGS="$PROJECT_ROOT/.claude/settings.json"
SPECKIT_SETTINGS="$TEMPLATES_ROOT/settings.speckit.json"
# shellcheck disable=SC2016
MERGE_FILTER='
  .[0] as $p | .[1] as $f
  | $p
  | .permissions = (($p.permissions // {})
      | .deny = (reduce ($f.permissions.deny // [])[] as $x
                   ((.deny // []); if any(.[]; . == $x) then . else . + [$x] end))
      | if has("disableBypassPermissionsMode") then . else .disableBypassPermissionsMode = $f.permissions.disableBypassPermissionsMode end)
  | reduce ($f.hooks | to_entries[]) as $ev (.;
      reduce $ev.value[] as $g (.;
        reduce $g.hooks[] as $h (.;
          if any((.hooks[$ev.key] // [])[]?.hooks[]?; .command == $h.command) then .
          else
            (.hooks[$ev.key] // []) as $groups
            | (first(range(0; $groups | length)
                     | select(($groups[.].matcher // "") == ($g.matcher // ""))) // null) as $i
            | if $i == null
              then .hooks[$ev.key] = $groups + [ (if $g.matcher == null then {} else {matcher: $g.matcher} end) + {hooks: [$h]} ]
              else .hooks[$ev.key][$i].hooks += [$h]
              end
          end)))
'
if [ ! -f "$SETTINGS" ]; then
  jq '.' "$SPECKIT_SETTINGS" > "$SETTINGS"
  echo "  ✓ .claude/settings.json created (hooks + deny policy)"
elif ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  echo "  ! .claude/settings.json is not valid JSON — skipped merge. Fix it and re-run." >&2
else
  MERGED="$(jq -s "$MERGE_FILTER" "$SETTINGS" "$SPECKIT_SETTINGS")"
  if [ "$(jq -S . "$SETTINGS")" = "$(printf '%s' "$MERGED" | jq -S .)" ]; then
    echo "  ✓ .claude/settings.json already contains the SpecKit hooks and deny policy"
  else
    printf '%s\n' "$MERGED" > "$SETTINGS"
    echo "  ✓ .claude/settings.json merged (hooks added if absent, deny unioned; allow and defaultMode untouched)"
  fi
fi

# Per-developer runtime state (.specify/state/, gitignored) — session.yaml is created if absent
STATE_DIR="$PROJECT_ROOT/.specify/state"
mkdir -p "$STATE_DIR"
if [ ! -f "$STATE_DIR/session.yaml" ]; then
  cat > "$STATE_DIR/session.yaml" << 'EOF'
# SpecKit-SSD-SDLC session state — per developer, gitignored, managed by /sk.session

role: null              # po|architect|lead|backend|frontend|backend-qa|frontend-qa|security
session_id: null        # e.g. po-20260409
branch: null            # the working branch (recorded, or created on request)
story_id: null          # story being worked on at session start (sk.session start)
jira_id: null           # linked tracker issue key, if any
active_intent_id: null  # e.g. CHK
active_unit_id: null    # e.g. CHK-PAY
active_story_id: null   # e.g. CHK-PAY-001
stories_touched: []     # list of story IDs worked on this session
units_touched: []       # list of unit IDs worked on this session
EOF
  echo "  ✓ .specify/state/session.yaml created"
fi
echo ""

# ─────────────────────────────────────────────
# PHASE 3: Managed regions in CLAUDE.md / GEMINI.md
# ─────────────────────────────────────────────
# shellcheck source=.claude/hooks/lib-profile.sh
source "$SCRIPT_DIR/.claude/hooks/lib-profile.sh"

NEVER_AUTOLOAD="$(sk_profile_list "$PROJECT_ROOT" knowledge.never_autoload | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')"
[ -n "$NEVER_AUTOLOAD" ] || NEVER_AUTOLOAD="(no humans-only paths declared)"

render_template() {
  awk -v v="$VERSION" -v na="$NEVER_AUTOLOAD" '{ gsub(/\{\{SPECKIT_VERSION\}\}/, v); gsub(/\{\{NEVER_AUTOLOAD\}\}/, na); print }' "$1"
}

current_region() {
  awk -v s="$MANAGED_START" -v e="$MANAGED_END" '
    index($0, s) == 1 { on = 1 }
    on { print }
    on && index($0, e) == 1 { exit }
  ' "$1"
}

splice_managed() {
  local target="$1" template="$2" label
  label="$(basename "$target")"
  local region_file
  region_file="$(mktemp)"
  render_template "$template" > "$region_file"

  if [ ! -f "$target" ]; then
    cp "$region_file" "$target"
    echo "→ Created $label"
  elif grep -qF "$MANAGED_START" "$target"; then
    if [ "$(current_region "$target")" = "$(cat "$region_file")" ]; then
      echo "→ $label managed region is up to date"
    elif confirm "Update the SpecKit managed region in $label? (content outside the markers is preserved)"; then
      awk -v s="$MANAGED_START" -v e="$MANAGED_END" -v rf="$region_file" '
        index($0, s) == 1 && !done { while ((getline l < rf) > 0) print l; skip = 1; next }
        skip { if (index($0, e) == 1) { skip = 0; done = 1 } ; next }
        { print }
      ' "$target" > "$target.speckit-tmp"
      mv "$target.speckit-tmp" "$target"
      echo "→ Updated $label managed region"
    else
      echo "→ $label kept as-is"
    fi
  else
    if confirm "$label has no SpecKit markers. Insert the managed region at the top? (existing content is kept below it)"; then
      { cat "$region_file"; echo ""; cat "$target"; } > "$target.speckit-tmp"
      mv "$target.speckit-tmp" "$target"
      echo "→ Inserted managed region into $label"
    else
      echo "→ $label kept as-is (no managed region)"
    fi
  fi
  find "$region_file" -delete
}

splice_managed "$PROJECT_ROOT/CLAUDE.md" "$TEMPLATES_ROOT/CLAUDE.md"
if [ "$WANT_GEMINI" = true ] || [ "$(sk_profile_get "$PROJECT_ROOT" install.gemini false)" = "true" ]; then
  splice_managed "$PROJECT_ROOT/GEMINI.md" "$TEMPLATES_ROOT/GEMINI.md"
fi

# .gitignore — append any missing SpecKit entries (line-level, idempotent)
GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ -f "$TEMPLATES_ROOT/.gitignore.fragment" ]; then
  touch "$GITIGNORE"
  added=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ""|\#*) continue ;; esac
    if ! grep -qxF "$line" "$GITIGNORE"; then
      if [ "$added" -eq 0 ] && ! grep -qxF "# speckit-managed" "$GITIGNORE"; then
        printf "\n# speckit-managed\n" >> "$GITIGNORE"
      fi
      echo "$line" >> "$GITIGNORE"
      added=$((added + 1))
    fi
  done < "$TEMPLATES_ROOT/.gitignore.fragment"
  [ "$added" -gt 0 ] && echo "→ Added $added SpecKit entries to .gitignore"
fi
echo ""

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────
echo "✓ SpecKit setup complete (v$VERSION)."
echo ""
if [ ! -f "$PROJECT_ROOT/.specify/profile.yaml" ]; then
  echo "Next steps:"
  echo "  1. Run /sk.init in Claude Code. It detects your existing homes (ADRs, domain specs, contracts,"
  echo "     skills registry, rules, branch conventions), proposes .specify/profile.yaml and confirms it with you."
  echo "  2. Project skills: register them in the Registry table of .claude/skills/README.md"
  echo "     (starting points: $FRAMEWORK_REL/skills_archive/)."
fi
echo ""
