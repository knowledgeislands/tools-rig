---
areas: { CLI: 21, CORE: 35, DIST: 9, MIG: 7 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Areas are not mutable themes or groups.

- `CLI` reserves through `021`.
- `CORE` reserves through `035`.
- `DIST` reserves through `009`.
- `MIG` reserves through `007`.
