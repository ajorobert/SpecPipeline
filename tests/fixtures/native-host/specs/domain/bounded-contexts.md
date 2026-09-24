# Bounded contexts

| Context | File | Owns | Code |
|---|---|---|---|
| Orders | [orders.md](orders.md) | carts, orders, checkout | `src/backend/modules/Orders` |

## Context map
- Orders → Payments: customer/supplier via specs/asyncapi/orders.yaml
