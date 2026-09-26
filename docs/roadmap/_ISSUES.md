---
areas: { CLI: 19, CORE: 27, DIST: 9, MIG: 7 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Areas are not mutable themes or groups.

- `CLI` reserves through `019`.
- `CORE` reserves through `027`.
- `DIST` reserves through `009`.
- `MIG` reserves through `007`.
