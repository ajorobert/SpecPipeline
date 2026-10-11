# Step 3 — Contracts
Outputs: the canonical `specs/openapi/{audience}.yaml` / `specs/asyncapi/{module}.yaml`, edited in place on
the branch; `02-design/contract-changes.md`; `02-design/projects/{Project}.md` for each Backend project.
A contract is never copied into the unit.

1. **Target files.** HTTP operations go into the existing audience file whose consumers match (projects
   router Role, routed ADRs). A new audience file only when architecture.md calls for one — announce it at
   the gate with the reason. Async channels go into the owning module's file.
2. **Operations.** Add or change only what the story needs, in the edited file's own conventions and the
   project's ADRs and rules. Declare auth on every operation in the spec's own mechanism. Never remove an
   operation silently.
3. **Compatibility.** Classify every added, changed or removed operation with a class from the file
   `contracts.compat_rules` names (unset: `additive | deprecating | breaking`). A `breaking` row names
   its versioned replacement or the ADR that accepts the break; with neither, raise it at the gate.
4. **Consumers.** For each row: the impacted Frontend/Mobile projects, and any other project that
   consumes the audience or module.
5. **Verification.** `contracts.verify` set: run it and record the command, result and date; explain a
   failure that is expected before the code exists. Unset: record "none — provider contract tests by sk.test".
6. **contract-changes.md**, from `{templates_dir}/artifacts/contract-changes-template.md`: files touched;
   the operations table (File · Operation · Change · Compatibility · Consumers); verification; the test
   plan — a Provider section (per operation: happy path, errors, auth, edge cases, test data) and one
   `### Consumer ({Project})` section per Frontend/Mobile project, in Impacted Projects order, listing only
   the operations it calls, the fields it uses and the error states it handles (plus platform scenarios
   from its tech-stack.md, such as offline and retry). No consumer: "None — no consumer projects in this unit".
7. **Backend project pages.** For each Backend row, `02-design/projects/{Project}.md` from
   `{templates_dir}/artifacts/project-design-template.md`: this project's slice of architecture,
   data model and contract changes (operations owned, handlers, entities, security, consistency per write
   path). It references the spec operations; it does not restate them.

## Gate 3 — Contracts
Show: `git diff` of every canonical file listed, contract-changes.md, the Backend project pages. Check for:
- every operation the story needs exists; none that no story needs was added;
- the change list and the diff agree, row for row;
- every row has a compatibility class and consumers; every `breaking` row a replacement or an accepting ADR;
- auth is declared per operation; verification is recorded;
- a new audience file, if any, is intended;
- the test plan has a provider section and one consumer section per Frontend/Mobile project.
On cancel: the spec edits and change list written so far stay; UI does not run.

## After the gate — contract codegen
`contracts.codegen` set in `.specify/profile.yaml` and at least one operation changed: run it once, from
the repo root, now — so generated clients and types exist before any project's implement session. Record
`contracts.codegen: ran "{command}" — exit {code}` in contract-changes.md → Verification. A non-zero exit
is shown to the human; never edit generated files by hand. Unset or `none`: record that types are written
by hand in each project.
