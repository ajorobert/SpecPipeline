# Worker Dispatch
Framework-owned block, referenced by path from every orchestrator that fans out to `_sub_` workers.
It defines how a worker is dispatched so that it runs in a genuinely isolated context.

## Why the Agent tool, not the Skill tool
The Skill tool loads a skill's content into the **current** context. A worker invoked that way shares
the orchestrator's window: its reads accumulate in the main context, and the preamble it loads can
never sit at the front of a window, so it can never be a cache prefix.

The Agent tool forks a real context. The worker gets a clean window and only its final report comes
back. That is what makes this framework's three standing claims true rather than aspirational:

- the worker sees only what its own job needs;
- the main context grows by a short report, not by the worker's whole working set;
- the worker's invariant preamble IS the front of its window, so repeat invocations of the same
  worker across a fan-out hit the prompt cache on that prefix.

## The two markers
`skill-start.sh` runs on `PreToolUse(Skill)` and `UserPromptSubmit`. The Agent tool triggers neither.
Without its markers `validate-path.sh` falls back to the session role, and the worker's
`write_scope.deny` is not enforced.

PreToolUse hooks DO fire for tool calls made inside a subagent, so markers set before the dispatch
are enforced for every write the worker makes. The orchestrator sets them and clears them:

```
bash .claude/hooks/set-worker-role.sh <worker-skill> [role-override]   # immediately BEFORE Agent(...)
bash .claude/hooks/set-worker-role.sh clear                            # immediately AFTER it returns
```

Omit `role-override` unless the worker's role depends on the project type (the implement and test
families). Without it the role comes from the worker's `subagent_type:` → that agent's `role:`.
Never override a planning worker to a project-type role: `03-plan/**` is denied to the engineer
roles, and only `lead` may write there.

The script warns when a role resolves to no agent file. Treat that warning as a failure to guard, not
as noise: `validate-path.sh` enforces no deny set for a role it cannot resolve, so that worker runs
unguarded. The fix is to add the agent file, never to ignore the warning.

## One worker at a time
The markers are a single pair of files under `.specify/state/`. Two workers in flight at once would
share one role and the second dispatch would silently re-scope the first. **Dispatch sequentially.**
Wall-clock is not the constraint: the per-project review gates and the sequencing declared in
`02-design/impact-analysis.md` already serialize most fan-outs.

## The dispatch prompt
Keep it short, and keep its prefix byte-identical across the projects of one fan-out — only the
parameter block at the end varies. That stable prefix is what the prompt cache keys on. The worker's
`prompt.md` remains the single source of truth; never inline it into the orchestrator.

```
Execute the worker skill defined at .claude/skills/{worker}/prompt.md.
Read that file first and follow it exactly. It names every other file to load, and the order.

You are an isolated worker. Report back ONLY:
  - the artifacts you wrote, as paths
  - decisions the orchestrator or another project's worker must know
  - blockers, open questions, and anything you could not complete
Do not paste file contents, plans, specs or code into your report.

Parameters:
  Project:     {Project}
  CodeRoot:    {CodeRoot}
  ProjectType: {ProjectType}
  Role:        {role}
  UNIT_DIR:    {UNIT_DIR}
```

Use the worker's own `subagent_type:` from its SKILL.md as the Agent call's `subagent_type`.

A worker reports; it does not converse. If it comes back with a question the orchestrator cannot
answer from the artifacts, raise it at the next gate rather than re-dispatching to negotiate.

## A worker can never talk to a human
A subagent has no channel to the user. Any step that asks a question, runs a review gate, or waits for
`approved` MUST run in the main context. This is a hard boundary, not a preference — a gate inside a
subagent either hangs or, worse, self-approves.

Consequences, already applied:
- `sk.story` is **not** migrated and must not be. Its whole pipeline is an interactive clarification
  loop ("present EXACTLY ONE question at a time — after the user answers …").
- `sk.implement_sub_implementproject` stays Skill-invoked: it owns the Scaffolding Review gate. It
  dispatches its own two workers as subagents around that gate.
- A worker that would have asked something records it as an open question and reports it up. The
  orchestrator raises it at its next gate.
- A worker that would have raised an ADR reports `ADR required: {decision}` instead. The orchestrator
  runs `Skill(sk.adr)` in the main context, where sk.adr can interact.

## Nested dispatch
A subagent can dispatch a subagent; this was verified. Two rules when you use it:
- Dispatch stays sequential at every level. One worker in flight in the whole tree.
- The markers are global, so a parent that dispatches a child must **re-set its own markers** when the
  child returns — `set-worker-role.sh <parent-skill> [role]`, not `clear` — or the parent's own
  remaining writes run unguarded.

Prefer flat dispatch. Nest only when the middle layer owns a gate or per-project state that the
orchestrator should not hold.

## Choosing the agent and role
A worker's `subagent_type:` in SKILL.md is a **default, not a rule**. The implement and test families
serve every project type from one skill, so the dispatcher picks both the agent and the role from the
project's `Type` in `unit-brief.md` → Impacted Projects:

| Project Type | `--role` / marker | Agent tool `subagent_type` |
|---|---|---|
| Backend  | `backend`  | SpecKit Backend Engineer Agent |
| Frontend | `frontend` | SpecKit Frontend Engineer Agent |
| Mobile   | `mobile`   | SpecKit Mobile Engineer Agent |

For the test family, use the QA agents instead: Backend → `backend-qa` / QA Backend Agent;
Frontend and Mobile → `frontend-qa` / QA Frontend Agent.

Planning and analysis workers are the exception: they always run as `lead`, whatever the project type,
because `03-plan/**` is denied to every engineer and QA role.

## Migration state
| Pipeline | Workers dispatched as subagents | Note |
|---|---|---|
| `sk.plan` | planproject, analyze | always `lead` |
| `sk.design` | architecture, datamodel, contracts, ui-design | gates and ADRs stay with the orchestrator |
| `sk.implement` | scaffolding, codegen | implementproject stays Skill-invoked (owns a gate) |
| `sk.test` | testproject | QA agent and role per project type |
| `sk.story` | — none, by design | fully interactive |

## What stays in the main context
Only `_sub_` workers are dispatched as subagents. The skills that emit `SK_RESULT`
(`sk.implement`, `sk.test`, `sk.review`, `sk.security-audit`, `sk.verify`, `sk.ship`) stay in the main
context, because the Stop hook that applies their verdict (`post-response.sh`) does not fire on
subagent completion (`governance/status-model.md`).

## Resume is unaffected
Dispatch changes nothing about resume. State lives on disk — `.specify/state/session.yaml` plus the
phase artifacts (`governance/phase-layout.md`). A developer can stop after any worker, restart the
machine, and continue in a new session; `sk.session restore` recovers focus from the branch alone.
An interrupted worker leaves its partial artifacts, and the orchestrator's RESUME mode picks up from
the first missing one. Isolation makes this better, not worse: each phase starts in a small window.
