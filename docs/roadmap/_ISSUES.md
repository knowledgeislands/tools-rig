---
areas: { CLI: 25, CORE: 44, DIST: 10, MIG: 8 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Reserve a number by committing this ledger's advance on its own before writing the record. Areas are not mutable themes or groups.

- `CLI` reserves through `025`.
- `CORE` reserves through `044`.
- `DIST` reserves through `010`.
- `MIG` reserves through `008`.
