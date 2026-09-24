#!/usr/bin/env bash
# tests/install-test.sh — "definition of native" (report §8.1, §8.2, §8.4) against the native-host fixture.
# Framework-only (never synced into a project). Runs on Linux, macOS and Windows (Git Bash). Needs git + jq.
#
#   bash tests/install-test.sh
#
# Installs the framework into a copy of tests/fixtures/native-host the way a host does (framework under
# .speckit/, then setup.sh), and asserts that only framework-owned paths change, nothing is scaffolded
# into the host's knowledge homes, and a second run is byte-identical.

set -uo pipefail

FRAMEWORK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
HOST="${WORK}/host"
PASS=0; FAIL=0
check() {
  local label="$1"; shift
  if "$@"; then PASS=$((PASS + 1)); printf '  ok    %s\n' "$label"
  else FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$label"; fi
}

mkdir -p "$HOST"
cp -R "$FRAMEWORK/tests/fixtures/native-host/." "$HOST/"
cd "$HOST" || exit 1
git init -q -b dev . && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -qm "host"

# The framework as a subtree would deliver it: framework files only, no tests/ai_reports/.archive.
mkdir -p .speckit
for p in .claude/agents .claude/hooks .claude/skills templates scripts setup.sh VERSION README.md; do
  mkdir -p ".speckit/$(dirname "$p")"
  cp -R "$FRAMEWORK/$p" ".speckit/$p"
done
git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -qm "subtree"

echo "setup.sh — first run"
bash .speckit/setup.sh --yes > "$WORK/run1.log" 2>&1
check 'setup.sh exits 0' test $? -eq 0

CHANGED=$(git status --porcelain --untracked-files=all | sed 's/^...//' | sed 's/^"\(.*\)"$/\1/')
UNEXPECTED=$(printf '%s\n' "$CHANGED" | grep -vE '^(\.claude/skills/sk\.[^/]+/|\.claude/skills/governance/|\.claude/agents/(architect|backend-engineer|backend-qa|frontend-engineer|frontend-qa|lead|mobile-engineer|po|security)\.md$|\.claude/hooks/[^/]+\.sh$|\.claude/\.speckit-manifest$|\.claude/settings\.json$|CLAUDE\.md$|\.gitignore$)' | sed '/^$/d')
check '§8.2 git status shows only framework-owned paths, CLAUDE.md, settings, .gitignore' test -z "$UNEXPECTED"
[[ -n "$UNEXPECTED" ]] && printf '        unexpected: %s\n' $UNEXPECTED

for p in specs/domains history/adr .specify/memory/domain-model.md .specify/memory/service-registry.md \
         .specify/memory/system-context.md .specify/memory/architecture-decisions.md .specify/memory/skill-routing.md \
         .specify/memory/standards .specify/project-config.md specs/guide.yaml GEMINI.md \
         .claude/skills/system-context .claude/skills/domain-model .claude/skills/standards; do
  check "§8.2 nothing at ${p}" test ! -e "$p"
done
check '§8.1 host knowledge files untouched' git diff --quiet HEAD -- specs .specify/profile.yaml .specify/memory .claude/skills/README.md .claude/rules docs
check 'host skills untouched' git diff --quiet HEAD -- .claude/skills/backend-architecture .claude/skills/web-patterns
check 'runtime state dir created and gitignored' bash -c 'test -f .specify/state/session.yaml && git check-ignore -q .specify/state/session.yaml'

echo "settings.json merge"
check 'host allow rule kept' jq -e '.permissions.allow | index("Bash(dotnet test *)")' .claude/settings.json
check 'B3 no defaultMode imposed' jq -e '.permissions | has("defaultMode") | not' .claude/settings.json
check 'D5 disableBypassPermissionsMode under permissions' jq -e '.permissions.disableBypassPermissionsMode == "disable" and (has("disableBypassPermissionsMode") | not)' .claude/settings.json
check 'E1 UserPromptSubmit wired to skill-start.sh' jq -e '[.hooks.UserPromptSubmit[].hooks[].command] | any(test("skill-start.sh"))' .claude/settings.json
check 'E5 delete guard matches PowerShell' jq -e '[.hooks.PreToolUse[] | select(.matcher | test("PowerShell"))] | length == 1' .claude/settings.json
check 'E5 PowerShell Remove-Item denied' jq -e '.permissions.deny | index("PowerShell(Remove-Item *)")' .claude/settings.json
check 'A12 read guard wired' jq -e '[.hooks.PreToolUse[] | select(.matcher == "Read|Grep|Glob")] | length == 1' .claude/settings.json

echo "CLAUDE.md managed region (D4)"
check 'host prose kept below the region' grep -q 'Run `dotnet test` before pushing backend changes.' CLAUDE.md
check 'imports the system knowledge base' grep -qx '@specs/knowledge-base.md' CLAUDE.md
check 'renders never_autoload from the profile' grep -q '`docs/architecture/\*\*`' CLAUDE.md
check 'states no removed home' bash -c '! grep -nE "skill-routing|specs/domains|history/adr|project-config|system-context|service-registry|domain-model" CLAUDE.md'

echo "setup.sh — second run (§8.4)"
git -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1 && git -c user.email=t@t -c user.name=t commit -qm "installed"
bash .speckit/setup.sh --yes > "$WORK/run2.log" 2>&1
check 'second run exits 0' test $? -eq 0
check 'second run is byte-identical' test -z "$(git status --porcelain --untracked-files=all)"

echo "opt-ins"
bash .speckit/setup.sh --yes --gemini > "$WORK/run3.log" 2>&1
check 'D3 --gemini adds GEMINI.md' test -f GEMINI.md

echo ""
echo "passed: ${PASS}  failed: ${FAIL}"
[[ "$FAIL" -eq 0 ]] || { echo "logs: $WORK"; exit 1; }
