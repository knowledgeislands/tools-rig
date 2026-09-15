---
areas: { CLI: 1, CORE: 2, DIST: 1, MIG: 3 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Areas are not mutable themes or groups.

- `CLI` reserves through `001`.
- `CORE` reserves through `002`.
- `DIST` reserves through `001`.
- `MIG` reserves through `003`.
