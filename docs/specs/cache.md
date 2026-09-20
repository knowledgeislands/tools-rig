# Cache maintenance — RIG-CACHE

This area of the [Rig Specifications](index.md) defines maintenance of cache data that Rig itself owns. It follows the XDG ownership boundary established by [ADR-RIG-002](../decisions/ADR-RIG-002-xdg-directory-contract.md).

## Command

### RIG-CACHE-001 — Explicit bounded cleanup

`rig clean [--dry-run]` MUST inspect only the effective Rig cache directory. It MUST NOT load Rig configuration, invoke a provider, inspect provider-native caches, or remove configuration, data, state, export destinations, or active publication staging.

Without `--dry-run`, Rig MUST remove every independently eligible artifact while continuing past unsafe or changed candidates. With `--dry-run`, Rig MUST perform the same discovery and validation but MUST NOT create, move, or remove any path.

_Conformance:_ conforming

_Verify:_ Run cleanup with missing configuration and isolated cache roots containing eligible, unsafe, and unrelated data; compare preview and mutation effects.

_Evidence:_ `rig_command_clean` limits traversal to the effective Rig publication cache and `tests/rig.bats` covers no-op, preview, mutation, and provider-independent operation.

## Classification and retention

### RIG-CACHE-002 — Publication cache classes

Active publication work MUST exist only beneath `publish/staging`. A complete export retained after publisher failure or interruption MUST move atomically into `publish/retained` before Rig reports its retained path. A successful publication MUST remove only its own staging tree.

Retained exports MUST remain until an explicit successful `rig clean`; Rig MUST NOT remove them automatically by age, count, retry success, or ordinary lifecycle operation. A flat `publish/*.rig-publish.*` entry outside the named namespaces MUST be classified as `legacy-unclassified` and skipped rather than inferred safe from its name, modification time, or process-like suffix.

_Conformance:_ conforming

_Verify:_ Exercise publication success, native failure, and interruption; inspect the resulting namespaces and run cleanup against a flat legacy-shaped entry.

_Evidence:_ publication Bats cases cover staging and retention, while cleanup cases verify indefinite retained data and fail-closed legacy classification.

### RIG-CACHE-003 — Exact artifact eligibility

An eligible publication artifact MUST be one immediate, real directory beneath the canonical retained or cleanup namespace, MUST have a valid `PUBLICATION.rig-publish.NUMBER` basename, and MUST contain exactly one regular, non-symlink `rig.json`. Symlinks, nested or additional content, invalid names, substituted parents, and unknown shapes MUST remain unchanged and be reported as skipped.

_Conformance:_ conforming

_Verify:_ Supply valid candidates alongside symlinks, extra files, invalid entries, and a symlinked cache boundary.

_Evidence:_ `rig_clean_artifact_shape`, namespace validation, and adversarial Bats cases enforce the exact shape.

## Safe removal

### RIG-CACHE-004 — Claim and bounded deletion

Before deleting a retained artifact, Rig MUST atomically move it into the cleanup-only namespace, revalidate its exact shape, unlink only `rig.json`, and remove only its now-empty directory. Rig MUST NOT use recursive deletion. A later cleanup MUST recognize and resume an exact-shape cleanup claim left by interruption.

Concurrent cleanup processes MUST be unable to claim the same retained artifact twice. An artifact retained after enumeration MUST wait for a later cleanup. Interruption MUST preserve any unfinished cleanup claim, report its path when known, and return the conventional signal status.

_Conformance:_ conforming

_Verify:_ Run concurrent cleaners, invoke the interruption handler with a claimed artifact, and confirm active staging and unsafe content remain unchanged.

_Evidence:_ `rig_clean_claim`, `rig_clean_remove_claim`, and `rig_clean_interrupted` implement the boundary; Bats covers concurrency and claim recovery.

## Reporting

### RIG-CACHE-005 — Deterministic cleanup report

Cleanup MUST write a deterministic tab-separated report with `CLASS`, `STATE`, `ACTION`, and `PATH` columns followed by eligible, removed, and skipped counts. Preview actions MUST be `would-remove`; mutation actions MUST be `removed` or `skipped`.

A complete scan or preview without skipped candidates MUST return 0. Any independently skipped or failed candidate MUST return 1 after safe work continues. Invalid syntax or inability to validate the effective Rig cache boundary MUST return 2. Mutation MUST use Rig's terminal-aware stderr progress channel and honour `RIG_PROGRESS=always|never`.

_Conformance:_ conforming

_Verify:_ Compare reports and statuses for no-op, preview, successful removal, mixed safe and unsafe candidates, and invalid cache boundaries; force progress in redirected output.

_Evidence:_ cleanup Bats cases assert report rows, summaries, statuses, and progress.
