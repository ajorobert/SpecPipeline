scripts/
Shell scripts for framework automation.

create-adr.sh          — reserves the next ADR file, specs/adr/NNNN-kebab-title.md, and prints its path (sk.adr)
check-adr-index.sh     — ADR drift guard: every ADR in specs/adr/ is routed from adr-index.md and every route resolves (sk.adr, sk.ship, verify-evidence.sh, CI)
