# Pre-flight and run model
Framework-owned. Every sk.* command runs this first, then its own steps.

## Run model
- **One command per session.** A command reads the previous phase's artifacts from disk and writes its
  own; nothing downstream reads a conversation. Start each command in a fresh session. Implement, test
  and review run once per project (`--projects <name>`) on a unit with several projects.
- **The command does its own work.** Its steps (`steps/*.md` in the command's folder) run in this session,
  in order, and are read when reached. Gates, questions and ADRs happen inline, with the human.
- **Subagents only read.** Use one for a narrow, read-only job that returns a short summary: code
  reconnaissance (the built-in Explore agent) or a fresh-eyes check (`sk-reviewer`). A subagent never
  writes a file and never asks the human anything.
- **Re-running a command resumes it.** A step whose output is listed `[missing]` by `context.sh` runs; an
  output that is present is kept (a gated output also needs `status: approved`). `sk.implement` resumes
  from the first open task in `progress.md`. A command re-runs a finished step only when `--refresh
  "<change>"` names it.

## Steps
1. Run `bash .claude/hooks/context.sh <command> [--projects <name>]`. It prints the unit, the story's
   status and `checkpoint_mode`, the projects in scope, `templates_dir` / `scripts_dir`, the files to read
   (each `[present]`, `[missing]` or its `status:`), the capability packs to load and — for review and
   verify — the rule files that match the diff. It exits non-zero when there is no active unit: STOP and
   show its message.
2. Read `specs/adr/adr-index.md`, then the ADRs its ALWAYS block lists and those of every block whose
   signals match the story's `tags` and text. Follow the index's own loading rules; never glob `specs/adr/`.
3. Read the files `context.sh` lists as present, in order, and the packs it lists.
4. Before writing code in an area, open an existing file there: that read is what loads the path-scoped
   rules in `.claude/rules/` for it. Never read a rules folder wholesale, except the files `context.sh`
   lists for review and verify.
5. `checkpoint_mode` missing from the story: use `validate` and say so.

## Always
- Precedence on conflict: ADRs → `.claude/rules/` (the principles file first) → capability packs → the
  unit's design → existing code. Report every conflict with the winning source.
- A home that does not exist is skipped with a one-line note; a command never creates a placeholder.
- Never read a path in `knowledge.never_autoload` (`.specify/profile.yaml`), or a shipped unit other than
  the active one, unless the human names it.
- Write only the outputs of this command. Status changes go through `bash .claude/hooks/story-status.sh`.
- Templates: `{templates_dir}/artifacts/<name>`. A missing template is not a stop: write the artifact from
  the structure the step describes.
- End with the completion report the command defines. Its last line names the next command, to run in a
  fresh session.
