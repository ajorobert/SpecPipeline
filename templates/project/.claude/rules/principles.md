---
# No paths: this file applies to every session, so Claude Code loads it every time.
---

# Principles
How decisions are made in this project. Where a principle and an ADR disagree, the ADR wins — a
principle guides the decisions nobody has made yet. Every line is the team's; keep this file under 200
lines, with no versions, module lists or tooling, and no rule another ADR or rule file already carries.

## Principles
<!-- Fixed, checkable principles, numbered. Commands cite them as `principles §N`, and a violation is a
     blocking finding unless an ADR decides otherwise. Reference an ADR instead of restating it. -->
1. {principle} — {ADR-NNNN, when one elaborates it}

## Before accepting a design
<!-- Questions every design must answer. sk.design adds them to its gates. -->
- {question}

## Baseline
<!-- Capabilities every new project of a type must have (for example health checks, structured logging).
     sk.plan opens a project with no code yet with one task per line. -->
- {Backend | Frontend | Mobile}: {capability} — {source}

## Starting work
- Read `specs/adr/adr-index.md` first, match the task to its signal blocks, and load exactly the ADRs they
  list. Nothing loads it for you.
- Open an existing file in the area you are changing before you write one: the rules in `.claude/rules/`
  load when a file their `paths` cover is read, so a session that starts from `git diff`, a search or a new
  file has loaded none of them.
- Skills load by their description; the folders in `knowledge.never_autoload` are opened only when a
  person names a file there.

## Working style
<!-- How the AI should work with the team: questions, pushback, tone. -->
- {…}
