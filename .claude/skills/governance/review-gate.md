# Review Gate Protocol
Framework-owned block, referenced by path from every orchestrator gate (`sk.design`, `sk.plan`,
`sk.implement`, `sk.implement_sub_implementproject`, `sk.test`, `sk.uat`, `sk.security-audit`). The skill supplies
the gate name, the artifact list and its own "Check for" items. This file supplies the behaviour.

## Schedule
Gates are driven by `checkpoint_mode`, read from the active story's frontmatter
(`.claude/skills/governance/preflight.md`). The meaning of each mode is defined in
`.claude/skills/governance/checkpoint-rules.md`.

| checkpoint_mode | Gate behaviour |
|---|---|
| autopilot | No pause. Auto-approve and log `Gate {name} skipped (checkpoint_mode: autopilot)`. |
| confirm   | Pause at gates the skill marks confirm+ |
| validate  | Pause at every gate |

A skill may raise the mode for one run (for example, a new bounded context forces validate). It
never lowers the mode, and it always logs the override.

## Display
```
{skill} | Gate — {gate name}  [checkpoint_mode: {mode}]

Review:
  {artifact paths written or updated in this run}

Check for:
  {skill-specific checklist}

Type 'approved' to approve all {items}.
Type 'approved {Project} {Project}' to approve specific projects (per-project gates only).
Type 'cancel' to stop — everything written so far is preserved.
```

## Handling input
- `approved` → apply the skill's approval effect (for example, `status: approved` in front-matter)
  and continue.
- `approved {Project} …` → apply the effect only to the named projects. Unnamed projects stay
  unapproved and are listed in the completion report.
- `cancel` → STOP. Do not change statuses. List every artifact written so far and suggest the
  next command.
- Any other input → repeat the prompt. Silence is never approval.

## Autopilot hard stops
In autopilot, an engineering review that reports BLOCKING or MEDIUM findings still STOPs the
pipeline. Show the findings and advise fixing them or escalating `checkpoint_mode` to `confirm`.
ADVISORY findings are logged and the pipeline continues.
