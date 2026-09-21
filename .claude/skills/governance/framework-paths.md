# Framework Paths
Framework-owned block, referenced by path. Resolves where the framework's own assets live, which
differs between this repository and an installed project.

## Why this is needed
`setup.sh` syncs only `.claude/skills/sk.*`, `.claude/skills/governance`, the memory-pointer skills,
the framework agents and `.claude/hooks/*.sh` into a project. It does **not** copy `templates/` or
`scripts/` — those stay in the framework subtree (normally `.speckit/`). A skill that writes
`{TEMPLATES_DIR}/artifacts/...` as a bare path therefore resolves nothing in an installed project.

## Procedure
1. Read `.claude/.speckit-manifest` (written by `setup.sh` on every run).
2. Take these values:
   - `TEMPLATES_DIR` = `templates_dir:` (for example `.speckit/templates`)
   - `SCRIPTS_DIR`   = `scripts_dir:`   (for example `.speckit/scripts`)
   - `FRAMEWORK_DIR` = `framework_dir:` (for example `.speckit`)
3. If the manifest is missing, the framework repository is being used directly. Fall back to
   `TEMPLATES_DIR = templates`, `SCRIPTS_DIR = scripts`, `FRAMEWORK_DIR = .`.
4. If a resolved template file does not exist, log
   `Template missing: {path} — writing {artifact} from the structure described in this prompt.`
   and continue. A missing template is never a STOP.

## Rules
- Every reference to a framework template is written `{TEMPLATES_DIR}/artifacts/<name>` — never a bare
  `templates/...` path.
- Templates are read-only. A skill never writes into `{TEMPLATES_DIR}` or `{FRAMEWORK_DIR}`.
- Project-owned paths (`.specify/`, `specs/`, `history/`, `.claude/session.yaml`) are always relative to
  the project root and never go through this resolution.
