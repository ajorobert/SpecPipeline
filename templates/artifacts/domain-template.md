# {Module} domain
<!-- One bounded context. Holds what the code cannot tell you: purpose, language, invariants, rationale.
     Entities and schema live in the code; decisions with cross-module reach live in ADRs. -->

## Purpose
{What this context is responsible for, and what it deliberately is not.}

## Language
| Term | Meaning here |
|---|---|
| {term} | {meaning; note where another context uses the word differently} |

## Invariants
- {A rule that must always hold, and where it is enforced}

## Relations
<!-- Mirror of this context's line in bounded-contexts.md, with the contract that carries each relation. -->
- {Upstream/downstream context} — via {specs/openapi/… operation | specs/asyncapi/… channel}

## Rationale
- {Non-obvious choice} — because {reason}. {ADR-NNNN if one exists}

## Tried and rejected
- {Approach} — {why it failed or was rejected}
