---
areas: { CLI: 3, CORE: 3, DIST: 2, MIG: 4 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Areas are not mutable themes or groups.

- `CLI` reserves through `003`.
- `CORE` reserves through `003`.
- `DIST` reserves through `002`.
- `MIG` reserves through `004`.
