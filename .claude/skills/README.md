.claude/skills/
Framework-owned (synced by setup.sh — do not edit in a consuming project):
  sk.*/                    process skills (SKILL.md + prompt.md); the sk. namespace is reserved
  governance/              checkpoint rules, quality gates, pack resolution, shared prompt blocks
  system-context/ service-registry/ domain-model/ architecture-decisions/ standards/
                           pointer stubs into .specify/memory/

Anything else in this folder is project-owned (for example capability packs) and is never touched by
setup.sh. Register project packs in .specify/memory/skill-routing.md so sk.* skills can load them.
