---
areas: { CLI: 12, CORE: 22, DIST: 7, MIG: 7 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Areas are not mutable themes or groups.

- `CLI` reserves through `012`.
- `CORE` reserves through `022`.
- `DIST` reserves through `007`.
- `MIG` reserves through `007`.
