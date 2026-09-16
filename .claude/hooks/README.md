.claude/hooks/
Deterministic hooks wired in .claude/settings.json (merged from templates/root/settings.speckit.json by setup.sh).
hooks.json mirrors that hooks block in plugin layout — keep the two in sync.

intercept-delete.sh           PreToolUse(Bash)       blocks rm/del/unlink; points to archive-file.sh
validate-path.sh              PreToolUse(Edit|Write) keeps writes inside the project; enforces agent write_scope.deny
check-skill-preconditions.sh  PreToolUse(Skill)      evaluates SKILL.md `preconditions:` against the active story
check-system-prompt-files.sh  PostToolUse(Edit|Write) warns when CLAUDE.md or an @imported file changes
post-skill.sh                 PostToolUse(Skill)     advances story status for unconditional skills
post-response.sh              Stop                   records sk.test/sk.review/sk.verify SK_RESULT verdicts
log-cache-metrics.sh          Stop                   appends prompt-cache telemetry to .claude/cache-metrics.jsonl
lib-story.sh                  (sourced)              story lookup (01-story/story.md) + frontmatter read/write helpers
archive-file.sh               (manual)               safe replacement for deletes → .archive/
cache-metrics-report.sh       (manual)               summarises cache-metrics.jsonl
