# Step 2 — Build
Inside `{CodeRoot}` only, exactly the files the plan's Files Affected names (and the migration and tests
the tasks call for).

## Before writing
- Open an existing file in each area you will change — that loads the path-scoped project rules for it —
  and follow the patterns you find. Search before adding an interface, utility or base type; reuse one
  that exists. For a wide search, dispatch an Explore subagent and use its summary.
- Generated clients and types from design's contract codegen are used as they are; never hand-edit them.

## Tasks
Work tasks.md in order, skipping `done` tasks in progress.md.
- A task runs only after every task in its `depends:` is `done`. `[P]` tasks of one group may be written
  together.
- Structure first where a task creates it: types, contracts (matching the spec operations exactly),
  entities, stubs, dependency wiring and test files with named cases for the acceptance criteria. Then the
  logic: rules, conditions, transformations, validations — inside that structure, without new
  abstractions the plan does not call for.
- Write the tests the task's `acceptance:` names, in the project's test framework and Test Layout.
- After each task, set it `done` in progress.md (or `blocked` with the reason, and stop that branch of work).
