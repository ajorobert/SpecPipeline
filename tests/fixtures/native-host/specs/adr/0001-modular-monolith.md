# ADR-0001: Modular monolith

## Status
Accepted — 2026-01-10

## Rules
- A module MUST NOT read another module's tables.

## Decision
One deployable, one schema per module.

## Context
Small team, one database cluster.

## Consequences
- Positive: simple deployment.
- Negative: module boundaries are enforced by tests, not the network.

## Alternatives rejected
| Option | Why rejected |
|---|---|
| Microservices | operational cost |
| Shared schema | boundary erosion |
