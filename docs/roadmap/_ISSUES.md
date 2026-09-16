---
areas: { CLI: 6, CORE: 4, DIST: 3, MIG: 6 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Areas are not mutable themes or groups.

- `CLI` reserves through `006`.
- `CORE` reserves through `004`.
- `DIST` reserves through `003`.
- `MIG` reserves through `006`.
