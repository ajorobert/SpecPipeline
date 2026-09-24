Data Standards
Loaded by: sk.datamodel

Naming Conventions:

Required Fields:

Migration Rules:

Soft Delete Policy:

Multi-tenancy Pattern:

Index Strategy:
# DDIA Ch 3 — one index per distinct query pattern.
# Composite indexes: equality fields first, range field last.
# REQUIRED: every query pattern in the unit's Access Patterns section must have a corresponding index.
# Document index type (B-tree, hash, GIN, etc.) when non-default.

Partitioning Key:
# DDIA Ch 6 — required if collection expected to exceed 10M rows or high write throughput.
# Key range: good for range queries, risk of hot spots on sequential keys (e.g. timestamps).
# Hash: even distribution, loses range query capability.
# Document partition key choice and hot-spot risk assessment.

Transaction Boundaries:
# DDIA Ch 7 — for each write path, declare:
# - Which operations are atomic (single transaction boundary)
# - Isolation level: READ COMMITTED | REPEATABLE READ | SERIALIZABLE
# - Read-modify-write cycles: flag as race condition risk, require explicit locking strategy
# Example: create_order() — atomic with inventory.decrement(); SERIALIZABLE; uses SELECT FOR UPDATE
