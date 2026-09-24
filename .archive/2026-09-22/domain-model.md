Domain Model
Loaded by: sk.design_sub_architecture, sk.plan, sk.design_sub_datamodel
Updated by: sk.design_sub_datamodel — do not edit manually

<!-- Records the global entity ownership map across all bounded contexts.
     sk.design_sub_datamodel appends new entities here when a unit's data model is defined.
     sk.plan_sub_analyze checks for naming conflicts and ownership violations against this file.

     BOUNDED CONTEXTS
     List each bounded context (typically maps 1:1 to a unit or service).
     Under each, list the entities it owns.

     Entity entry format:
       - {EntityName}: {key attributes} — {cross-domain deps if any}

     Example:
     ### order-service (INTENT-001-ORD)
     - Order: id, userId, status, lineItems[], totalAmount — depends on Product (inventory-service)
     - LineItem: orderId, productId, quantity, unitPrice
     - OrderEvent: orderId, eventType, timestamp, payload (append-only)

     SHARED KERNEL
     Entities or value objects shared across bounded contexts without ownership by one service.
     Format: - {Type}: {definition} — used by: {service-a}, {service-b}

     Example:
     - Money: amount (decimal), currency (ISO 4217) — used by: order-service, billing-service
     - Address: street, city, postalCode, countryCode — used by: order-service, shipping-service

     CONTEXT MAP
     Describe integration relationships between bounded contexts.
     Relationship types: Conformist | Anti-Corruption Layer | Shared Kernel | Open Host Service | Published Language

     Format: {upstream-service} → {downstream-service}: {relationship type} — {brief description}

     Example:
     - inventory-service → order-service: Open Host Service — order-service reads product availability via REST; no shared schema
     - billing-service → order-service: Conformist — billing conforms to order domain event schema for invoice triggers
-->

Bounded Contexts:

Shared Kernel:

Context Map:
