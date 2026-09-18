.claude/hooks/
Deterministic hooks wired in .claude/settings.json (merged from templates/root/settings.speckit.json by setup.sh).
hooks.json mirrors that hooks block in plugin layout — keep the two in sync.

intercept-delete.sh           PreToolUse(Bash)       blocks rm/del/unlink; points to archive-file.sh
validate-path.sh              PreToolUse(Edit|Write) keeps writes inside the project; enforces agent write_scope.deny
                                                     against .claude/.active-skill-role first, session.yaml role as fallback
check-skill-preconditions.sh  PreToolUse(Skill)      evaluates SKILL.md `preconditions:` against the active story
check-system-prompt-files.sh  PostToolUse(Edit|Write) warns when CLAUDE.md or an @imported file changes
post-skill.sh                 PostToolUse(Skill)     records .active-skill-role; advances story status for unconditional skills
post-response.sh              Stop                   applies SK_RESULT verdicts (sk.implement/test/review/
                                                     security-audit/verify/ship); clears .active-skill-role
log-cache-metrics.sh          Stop                   appends prompt-cache telemetry to .claude/cache-metrics.jsonl
lib-story.sh                  (sourced)              story lookup (01-story/story.md) + frontmatter read/write helpers
archive-file.sh               (manual)               safe replacement for deletes → .archive/
cache-metrics-report.sh       (manual)               summarises cache-metrics.jsonl

The story status machine, the SK_RESULT contract and the active-skill-role protocol are specified
in .claude/skills/governance/status-model.md — the hooks implement exactly that file.
