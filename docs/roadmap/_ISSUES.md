---
areas: { CLI: 26, CORE: 60, DIST: 11, MIG: 8 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Reserve a number by committing this ledger's advance on its own before writing the record. Areas are not mutable themes or groups.

- `CLI` reserves through `026`.
- `CORE` reserves through `060`.
- `DIST` reserves through `011`.
- `MIG` reserves through `008`.
