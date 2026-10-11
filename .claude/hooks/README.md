.claude/hooks/
Deterministic hooks wired in .claude/settings.json (merged from templates/root/settings.speckit.json by setup.sh).
hooks.json mirrors that hooks block in plugin layout — keep the two in sync.

session-start.sh              SessionStart           a new session starts with no running command: clears the
                                                     active command, its role and a pending verdict
skill-start.sh                UserPromptSubmit + PreToolUse(Skill)
                                                     both entry paths of an sk.* command (typed `/sk.x` and
                                                     Skill-tool calls): evaluates SKILL.md `preconditions:`,
                                                     then records the command + its role (SKILL.md `role:`,
                                                     resolved from --projects for engineer/qa) and the
                                                     transitions known at start
intercept-delete.sh           PreToolUse(Bash|PowerShell)  blocks rm/del/unlink/Remove-Item (+ aliases, chained forms)
validate-path.sh              PreToolUse(Edit|Write|NotebookEdit)
                                                     keeps writes inside the project (POSIX and Windows paths),
                                                     enforces governance/roles.yaml for the running command's
                                                     role, keeps shipped (frozen) units read-only
guard-read.sh                 PreToolUse(Read|Grep|Glob)  keeps knowledge.never_autoload paths and frozen units out
                                                     of loading unless a human named the file
check-system-prompt-files.sh  PostToolUse(Edit|Write) warns when CLAUDE.md or an @imported file changes
post-response.sh              Stop                   applies SK_RESULT verdicts (a turn without one — a gate
                                                     waiting for the human — keeps the marker); blocks once
                                                     while tracker mirrors are pending
log-cache-metrics.sh          Stop                   appends prompt-cache telemetry to .specify/state/cache-metrics.jsonl

context.sh                    (commands run it)      the loading manifest of one command session: unit files,
                                                     packs, and (review/verify) rules matching the diff
verify-evidence.sh            (sk.verify runs it)    the mechanical quality-gate items, PASS/FAIL/SKIP
story-status.sh               (commands call it)     the one status command: set / field / show / mirror-*
lib-story.sh                  (sourced)              story lookup, frontmatter read/write, sk_transition,
                                                     tracker outbox, active skill, path normalisation
lib-profile.sh                (sourced)              reads .specify/profile.yaml
archive-file.sh               (manual)               safe replacement for deletes → .archive/
cache-metrics-report.sh       (manual)               summarises cache-metrics.jsonl

The story status machine, the SK_RESULT contract and the active-role protocol are specified in
.claude/skills/governance/status-model.md; the tracker mirror in governance/tracker-mirror.md. All
runtime state lives in .specify/state/ (gitignored). Tests: tests/hooks-test.sh.
