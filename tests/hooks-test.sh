#!/usr/bin/env bash
# tests/hooks-test.sh — hook behaviour against a throw-away native-host fixture.
# Framework-only (never synced into a project). Runs on Linux, macOS and Windows (Git Bash).
#
#   bash tests/hooks-test.sh
#
# Exit 0 when every case passes. Each case pipes a hook payload into a hook, exactly as Claude Code does.

set -uo pipefail

FRAMEWORK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
ROOT="${WORK}/host"
mkdir -p "$ROOT"
cp -R "$FRAMEWORK/tests/fixtures/native-host/." "$ROOT/"
mkdir -p "$ROOT/.claude/hooks" "$ROOT/.claude/agents" "$ROOT/.claude/skills"
cp "$FRAMEWORK"/.claude/hooks/*.sh "$ROOT/.claude/hooks/"
cp "$FRAMEWORK"/.claude/agents/*.md "$ROOT/.claude/agents/"
for d in "$FRAMEWORK"/.claude/skills/sk.*; do cp -R "$d" "$ROOT/.claude/skills/"; done
export CLAUDE_PROJECT_DIR="$ROOT"

PASS=0; FAIL=0
H="$ROOT/.claude/hooks"
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
json() { jq -cn "$@"; }

# expect <exit-code> <hook> <payload> <label>
expect() {
  local want="$1" hook="$2" payload="$3" label="$4" got
  printf '%s' "$payload" | bash "$H/$hook" >/dev/null 2>"$WORK/err"
  got=$?
  if [[ "$got" == "$want" ]]; then PASS=$((PASS + 1)); printf '  ok    %s\n' "$label"
  else FAIL=$((FAIL + 1)); printf '  FAIL  %s (exit %s, want %s)\n' "$label" "$got" "$want"; sed 's/^/        /' "$WORK/err"; fi
}
check() {
  local label="$1"; shift
  if "$@"; then PASS=$((PASS + 1)); printf '  ok    %s\n' "$label"
  else FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$label"; fi
}

session() {
  mkdir -p "$ROOT/.specify/state"
  cat > "$ROOT/.specify/state/session.yaml" <<EOF
role: $1
active_intent_id: 001-orders
active_unit_id: $2
active_story_id: null
EOF
}
status_of() { sed -n 's/^  current: *//p' "$ROOT/specs/intents/001-orders/units/$1/01-story/story.md" | head -1; }

echo "E2 — validate-path.sh (root guard, Windows forms)"
session null checkout
expect 2 validate-path.sh "$(json --arg p 'C:\Windows\System32\drivers\etc\hosts' '{tool_input:{file_path:$p}}')" 'C:\Windows\…\hosts blocked'
expect 2 validate-path.sh "$(json --arg p 'C:/Users/someone/notes.md' '{tool_input:{file_path:$p}}')" 'C:/Users/… blocked'
expect 2 validate-path.sh "$(json --arg p '/c/Users/someone/notes.md' '{tool_input:{file_path:$p}}')" '/c/Users/… blocked'
expect 2 validate-path.sh "$(json --arg p '/etc/passwd' '{tool_input:{file_path:$p}}')" '/etc/passwd blocked'
expect 2 validate-path.sh "$(json --arg p '..\..\outside.md' '{tool_input:{file_path:$p}}')" '..\ traversal blocked'
expect 0 validate-path.sh "$(json --arg p "$(native "$ROOT")/README.md" '{tool_input:{file_path:$p}}')" 'in-root absolute (forward slashes) allowed'
expect 0 validate-path.sh "$(json --arg p "$(winpath "$ROOT")\\README.md" '{tool_input:{file_path:$p}}')" 'in-root absolute (backslashes) allowed'
expect 0 validate-path.sh "$(json '{tool_input:{file_path:"specs/domain/orders.md"}}')" 'relative in-root allowed'

echo "E3 — write_scope by role, on every path form"
session po checkout
expect 2 validate-path.sh "$(json '{tool_input:{file_path:"specs/intents/001-orders/units/checkout/02-design/architecture.md"}}')" 'po → 02-design (relative) blocked'
expect 2 validate-path.sh "$(json --arg p "$(winpath "$ROOT")\\specs\\intents\\001-orders\\units\\checkout\\02-design\\architecture.md" '{tool_input:{file_path:$p}}')" 'po → 02-design (Windows absolute) blocked'
printf '{"prompt":"/sk.design"}' | bash "$H/skill-start.sh" >/dev/null 2>&1
expect 0 validate-path.sh "$(json '{tool_input:{file_path:"specs/intents/001-orders/units/checkout/02-design/architecture.md"}}')" 'po session, typed /sk.design → architect may write 02-design'
printf '{"stop_hook_active":false}' | bash "$H/post-response.sh" >/dev/null 2>&1
expect 2 validate-path.sh "$(json '{tool_input:{file_path:"specs/intents/001-orders/units/checkout/02-design/architecture.md"}}')" 'role marker cleared at Stop → po blocked again'

echo "E1 — skill-start.sh on both entry paths"
session lead checkout
expect 0 skill-start.sh '{"prompt":"/sk.design --contracts"}' 'typed /sk.design with a populated unit-brief → allowed'
check 'typed /sk.design records active skill' test "$(cat "$ROOT/.specify/state/active-skill" 2>/dev/null)" = "sk.design"
session lead empty-unit
expect 2 skill-start.sh '{"prompt":"/sk.design"}' 'typed /sk.design with no Impacted Projects → blocked'
expect 2 skill-start.sh '{"tool_name":"Skill","tool_input":{"skill":"sk.design"}}' 'Skill(sk.design) with no Impacted Projects → blocked'
expect 0 skill-start.sh '{"prompt":"please run the design"}' 'plain prompt → ignored'
session lead checkout
expect 0 skill-start.sh '{"tool_name":"Skill","tool_input":{"skill":"sk.story_sub_specify"}}' 'Skill(sk.story_sub_specify) → allowed'
check 'sk.story_sub_specify → status draft' test "$(status_of checkout)" = "draft"

echo "E1 — conditional precondition (sk.implement: confirm mode needs an approved plan)"
PLAN="$ROOT/specs/intents/001-orders/units/checkout/03-plan/api/plan.md"
mkdir -p "$(dirname "$PLAN")"
printf -- '---\nstatus: draft\n---\n' > "$PLAN"
expect 2 skill-start.sh '{"prompt":"/sk.implement"}' 'confirm mode + unapproved plan → sk.implement blocked'
printf -- '---\nstatus: approved\n---\n' > "$PLAN"
expect 0 skill-start.sh '{"prompt":"/sk.implement"}' 'confirm mode + approved plan → sk.implement allowed'
check 'sk.implement start leaves the SK_RESULT marker' test "$(cat "$ROOT/.specify/state/last-skill" 2>/dev/null)" = "sk.implement"
mv "$ROOT/.specify/state/last-skill" "$WORK/"

echo "A11 — one status command + tracker outbox"
bash "$H/story-status.sh" set ready --by sk.story >/dev/null
check 'story-status.sh set ready' test "$(status_of checkout)" = "ready"
check 'transition queued for the tracker' test "$(bash "$H/story-status.sh" mirror-pending | grep -c 'SHOP-12 draft→ready')" -ge 1
check 'invalid status rejected' bash -c "! bash '$H/story-status.sh' set bogus >/dev/null 2>&1"
OUT=$(printf '{"stop_hook_active":false}' | bash "$H/post-response.sh")
check 'Stop blocks while mirrors are pending' bash -c "printf '%s' '$OUT' | jq -e '.decision == \"block\"' >/dev/null"
OUT=$(printf '{"stop_hook_active":true}' | bash "$H/post-response.sh")
check 'Stop never blocks twice (stop_hook_active)' test -z "$OUT"
for id in $(bash "$H/story-status.sh" mirror-pending | awk '{print $1}'); do bash "$H/story-status.sh" mirror-fail "$id" "tracker offline" >/dev/null; done
check 'failed mirror kept, not pending' test "$(bash "$H/story-status.sh" show | grep -c '0 pending, 2 failed')" = 1
bash "$H/story-status.sh" mirror-retry >/dev/null
for id in $(bash "$H/story-status.sh" mirror-pending | awk '{print $1}'); do bash "$H/story-status.sh" mirror-ack "$id" >/dev/null; done
OUT=$(printf '{"stop_hook_active":false}' | bash "$H/post-response.sh")
check 'retried + acked → Stop does not block' test -z "$OUT"

echo "E5 — intercept-delete.sh (Bash and PowerShell)"
expect 2 intercept-delete.sh '{"tool_name":"PowerShell","tool_input":{"command":"Remove-Item -Recurse foo"}}' 'PowerShell Remove-Item blocked'
expect 2 intercept-delete.sh '{"tool_name":"PowerShell","tool_input":{"command":"Get-ChildItem x | ri"}}' 'PowerShell alias ri blocked'
expect 2 intercept-delete.sh '{"tool_name":"Bash","tool_input":{"command":"ls && rm -rf x"}}' 'chained rm blocked'
expect 2 intercept-delete.sh '{"tool_name":"Bash","tool_input":{"command":"find . -name x -delete"}}' 'find -delete blocked'
expect 0 intercept-delete.sh '{"tool_name":"Bash","tool_input":{"command":"git status"}}' 'git status allowed'
expect 0 intercept-delete.sh '{"tool_name":"Bash","tool_input":{"command":"npm run format"}}' 'npm run format allowed'

echo "A10/A12 — frozen units and never_autoload"
session backend checkout
expect 2 validate-path.sh "$(json '{tool_input:{file_path:"specs/intents/001-orders/units/cart-v1/02-design/architecture.md"}}')" 'write into a shipped unit blocked'
expect 2 guard-read.sh "$(json '{tool_name:"Read",tool_input:{file_path:"specs/intents/001-orders/units/cart-v1/01-story/story.md"}}')" 'read of a frozen, non-active unit blocked'
expect 2 guard-read.sh "$(json '{tool_name:"Read",tool_input:{file_path:"docs/architecture/overview.md"}}')" 'read of docs/architecture blocked'
expect 2 guard-read.sh "$(json '{tool_name:"Grep",tool_input:{pattern:"x",path:"docs/architecture"}}')" 'grep scoped to docs/architecture blocked'
expect 2 guard-read.sh "$(json '{tool_name:"Glob",tool_input:{pattern:"docs/architecture/**/*.md"}}')" 'glob into docs/architecture blocked'
printf '%s\n' '{"type":"user","message":{"role":"user","content":"check docs/architecture/overview.md for the context"}}' > "$WORK/t.jsonl"
expect 0 guard-read.sh "$(json --arg t "$WORK/t.jsonl" '{tool_name:"Read",tool_input:{file_path:"docs/architecture/overview.md"},transcript_path:$t}')" 'named by the human → allowed'
expect 0 guard-read.sh "$(json '{tool_name:"Read",tool_input:{file_path:"specs/domain/orders.md"}}')" 'ordinary read allowed'
session backend cart-v1
expect 0 guard-read.sh "$(json '{tool_name:"Read",tool_input:{file_path:"specs/intents/001-orders/units/cart-v1/01-story/story.md"}}')" 'frozen unit readable while it is the active unit'

echo "A2 — ADR index guard"
(cd "$ROOT" && bash "$FRAMEWORK/scripts/check-adr-index.sh" >/dev/null 2>&1); check 'fixture ADR index passes' test $? -eq 0
printf '# ADR-0004: Unrouted\n' > "$ROOT/specs/adr/0004-unrouted.md"
(cd "$ROOT" && bash "$FRAMEWORK/scripts/check-adr-index.sh" >/dev/null 2>&1); check 'unrouted ADR fails the guard' test $? -ne 0
mv "$ROOT/specs/adr/0004-unrouted.md" "$WORK/"
mv "$ROOT/specs/adr/0002-idempotent-commands.md" "$WORK/"
(cd "$ROOT" && bash "$FRAMEWORK/scripts/check-adr-index.sh" >/dev/null 2>&1); check 'route to a missing ADR fails the guard' test $? -ne 0
mv "$WORK/0002-idempotent-commands.md" "$ROOT/specs/adr/"
OUT=$(cd "$ROOT" && bash "$FRAMEWORK/scripts/create-adr.sh" "Outbox for integration events")
check 'create-adr.sh takes the next NNNN-kebab name' test "$OUT" = "specs/adr/0004-outbox-for-integration-events.md"

echo ""
echo "passed: ${PASS}  failed: ${FAIL}"
[[ "$FAIL" -eq 0 ]]
