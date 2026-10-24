---
areas: { CLI: 27, CORE: 73, DIST: 12, MIG: 8 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Reserve a number by committing this ledger's advance on its own before writing the record. Areas are not mutable themes or groups.

- `CLI` reserves through `027`.
- `CORE` reserves through `073`.
- `DIST` reserves through `012`.
- `MIG` reserves through `008`.
