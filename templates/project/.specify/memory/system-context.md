System Context
Loaded by: sk.story_sub_specify, sk.impact, sk.ff

<!-- Populate this file during sk.init or early in the project.
     sk.ff will not proceed if this file is empty.
     Every field marked [REQUIRED] must be filled before running sk.story_sub_specify.
     Use plain text or short bullet lists — no markdown headings needed within sections. -->

System Overview
<!-- [REQUIRED] One or two sentences describing what this system does and for whom.
     Example: "Multi-tenant SaaS platform for managing restaurant inventory and ordering.
     Serves restaurant operators and kitchen staff across web and mobile surfaces." -->

System Type:
<!-- [REQUIRED] e.g. monolith | modular monolith | microservices | serverless | hybrid
     Example: "Microservices (REST + async events)" -->

Services:
<!-- [REQUIRED] One line per backend service. Add entries as new services are defined via sk.design_sub_contracts.
     Format: - {service-name}: {one-sentence responsibility}
     Example:
     - auth-service: Issues and validates JWT tokens; manages user credentials and sessions
     - order-service: Manages order lifecycle from creation through fulfillment
     - inventory-service: Tracks stock levels and triggers reorder workflows -->

Frontend Surfaces:
<!-- One line per frontend application or surface.
     Format: - {surface-name}: {type} — {one-sentence description}
     Example:
     - web-app: single-page web app — operator dashboard for managing menus, inventory, and orders
     - mobile-app: cross-platform native app — kitchen display and order fulfilment for staff -->

External Dependencies:
<!-- Third-party services, APIs, and infrastructure this system relies on.
     Format: - {name}: {purpose}
     Example:
     - Stripe: payment processing
     - SendGrid: transactional email
     - AWS S3: file storage for menu assets -->

Current Development Focus:
<!-- [OPTIONAL] What the team is actively building right now.
     Helps sk.story_sub_specify and sk.impact narrow context to relevant services.
     Example: "Implementing order splitting and multi-location inventory sync (Intent: INV-004)" -->
