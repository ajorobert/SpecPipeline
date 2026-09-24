# ADR Index
A router, not a table: it tells an AI which decisions to load for the task at hand.
Every ADR in `specs/adr/` is routed from at least one block below, and every route resolves
(`check-adr-index.sh`). Add a new ADR to the block(s) whose signals it answers — never append a flat list.

## Loading rules
1. Always load the ALWAYS block.
2. Load every block whose signals match the task: story tags, the files being changed, or the words of
   the request. Load only the ADRs listed in matching blocks.
3. Read an ADR's `## Rules` first; read the rest only when the rules do not settle the question.
4. A superseded ADR is routed only from its successor, never from a signal block.

## ALWAYS
<!-- Decisions every change must respect. Keep this block short. -->
- [ADR-0001: {title}](0001-{kebab-title}.md) — {one line: what it constrains}

## Signals

### {signal, signal, signal}
<!-- e.g. "http api, endpoint, contract, openapi" -->
- [ADR-NNNN: {title}](NNNN-{kebab-title}.md) — {one line}

### {signal, signal}
- [ADR-NNNN: {title}](NNNN-{kebab-title}.md) — {one line}
