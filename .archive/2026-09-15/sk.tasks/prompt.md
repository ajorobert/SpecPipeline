# sk.tasks
Generates actionable task breakdown for a story.
Role: lead | Level: story

Internal sub-skill — invoked by sk.implement orchestrator. Do not invoke directly.

## Input Artifacts
specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md (required)
story-{ID}.md frontmatter (checkpoint_status)

## Steps
1. Verify plan.md exists — if missing: STOP, run sk.plan first
2. Verify checkpoint gate:
   confirm or validate mode → checkpoint_status must = approved
   not approved → STOP, instruct user to approve plan first
3. [REFINE MODE] if tasks.yaml exists, [CREATE MODE] if not
4. New service detection:
   If no existing src/{service}/ code — this is the first story for a new service.
   Add to Phase 1 (setup) tasks:
   - id: T001, description: "Configure structured JSON logging with trace_id propagation"
   - id: T002, description: "Implement GET /health endpoint (200 ok + 503 degraded responses)"
   - id: T003, description: "Instrument RED metrics middleware (rate, errors, duration per endpoint)"
5. Generate task breakdown as YAML (see Output Format below):
   - phase: setup       — project structure, config, dependencies
   - phase: foundation  — blocking prerequisites: schema migrations, shared utilities
   - phase: story-N     — user story tasks in priority order (multiple phases allowed)
     - Write test tasks before implementation tasks (TDD order)
   - phase: crosscut    — logging, error handling, documentation
6. Write tasks to:
   specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.yaml

## Output Format
```yaml
story_id: {INTENT-CODE}-{UNIT-CODE}-{NNN}
generated_at: {ISO-8601-date}
phases:
  - id: setup
    name: "Setup"
    tasks:
      - id: T001
        description: "{description}"
        file: "{src/path/to/target file}"
        parallel: false           # true = can run concurrently with other parallel:true tasks in same phase
        depends_on: []            # list of task ids that must complete first
        agent: backend            # backend | frontend | lead | security
        artifacts_needed: []      # list of spec file paths this task reads
        status: pending           # pending | in-progress | done | blocked
  - id: foundation
    name: "Foundation"
    tasks: []
  - id: story-1
    name: "{descriptive phase name}"
    tasks: []
  - id: crosscut
    name: "Cross-Cutting Concerns"
    tasks: []
```

## Output Artifacts
specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.yaml

## Quality Bar
- Test tasks before implementation tasks within each phase (TDD order)
- parallel: true only when tasks have no shared write targets
- depends_on lists all blocking task ids explicitly
- Each task has a specific file path (not a directory)
- agent field matches the role that should execute the task
