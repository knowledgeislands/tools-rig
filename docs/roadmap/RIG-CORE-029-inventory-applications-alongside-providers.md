---
id: RIG-CORE-029
area: CORE
title: Inventory applications alongside providers
theme: orchestration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 09e167f01f37968a5c3dded4562b0bf119567ff6
created_at: 2026-09-27T08:13:24Z
updated_at: 2026-09-30T20:11:30Z
---

## Goal

`rig status --unmanaged` reports installed applications that no declaration claims, whether or not the configuration happens to declare any provider of its own.

## Context

`rig_collect_unmanaged` in `src/rig/21-provider-state.bash` gathers declared `[provider.*]` sections into `RIG_QUERY_ITEMS`, then adds the built-in applications inventory only under a condition:

```sh
if [ "$RIG_RESOLVED_PLATFORM" = macos ] && [ "${#RIG_QUERY_ITEMS[@]}" -eq 0 ]; then
  RIG_QUERY_ITEMS[${#RIG_QUERY_ITEMS[@]}]=macos-applications
fi
```

The guard tests for an empty provider set, so `macos-applications` is a fallback for a configuration that declares nothing rather than a baseline the declared providers extend. Declaring a single provider of any kind removes the application scan entirely, and nothing in the output says a surface went unexamined.

This workstation declares exactly two providers, `homebrew` and `paperclip`, so the scan never runs. `rig status --unmanaged` prints `Unmanaged: 0` alongside `Unmanaged listeners: 16` and `Unmanaged skills: 16`. At the same time `/Applications` holds at least five bundles that no catalogue entry and no Brewfile line claims — Clockology, Home Assistant, Mercury, Nitro, and Prime Video, all Mac App Store purchases. The zero is arithmetically correct for the providers consulted and wrong as an answer to the question the flag asks.

The gap also propagates into another repository's reasoning. `DOTFILES-UE-036` states that `rig status --unmanaged` "independently reports any application bundle no declaration claims", and treats that as the safety net justifying a narrower Brewfile assertion. On this machine that net has never been in place.

## Boundary

This is about which inventory surfaces `--unmanaged` consults and how it reports a surface it did not examine. It does not change what counts as unmanaged once a surface is scanned, the inventory capability protocol, the state vocabulary, or exit statuses. It does not add new inventory providers, and it does not decide which of this workstation's undeclared applications should be declared — that is configuration work owned by the chezmoi source.

Whether wrapped iOS-on-macOS bundles should be inventoried the same way as native ones is a real question the scan will meet, but it is a classification concern rather than this dispatch bug.

## Current state

The built-in macOS applications inventory runs only when no providers are declared. A configuration with Homebrew and Paperclip providers therefore omits that inventory without a problem row.

## Steps

- [x] Run the built-in applications inventory on macOS after declared provider inventories, even when providers are configured.
- [x] Deduplicate an exact application path also reported by a declared provider without conflating unrelated provider identities that share a name.
- [x] Report an unavailable or failed application scan through the existing inventory problem channel, distinct from an examined empty result.
- [x] Add isolated cases with zero, one unrelated, and one overlapping declared provider, plus a failed applications scan.

## Files touched

`src/rig/21-provider-state.bash`, generated `bin/rig`, unmanaged-inventory Bats coverage, and state or orchestration Specifications describing the baseline.

## Verify

Assert that an unclaimed application appears with and without a declared provider, one claimed application appears once, and a failed scan is visible. Run ShellCheck, assembly check, and the Bats suite.

## Dependencies / blocks

No build-order dependency. Provider fixtures from [RIG-CORE-033](RIG-CORE-033-make-tests-machine-independent.md) may be reused, but this item must retain its own assertions.

## Documentation impact

### Decision Records

None expected for the bounded macOS baseline.

### Specifications

Specify the macOS baseline and the meaning of an unavailable scan.

### Guides

Update unmanaged-inventory guidance if it currently implies a different coverage rule.

### Roadmap

The other repository's safety-net rationale remains its own record to review separately.

## Review

### Delivered

From baseline `09e167f01f37968a5c3dded4562b0bf119567ff6`, macOS application inventory runs alongside configured providers. An unexamined scan produces an inventory problem rather than an apparent empty result.

### Change Summary

The collector appends the built-in scan on macOS and suppresses only duplicate canonical application paths already observed from a declared provider. The test harness confines application roots and property-list access to inert fixtures. The state Specification and user command guide describe the coverage rule.

### Verification

The focused six-case application-inventory suite and full Bats suite passed. ShellCheck, Bash syntax, assembly check, benchmark, native-provider smoke test, man lint, and scoped Specification and roadmap audits passed. The repository-wide audit reports unrelated Agora metadata and rubric drift outside this item.

### Outstanding concerns

The cross-repository `DOTFILES-UE-036` rationale still needs its owner to revisit it. This item does not classify iOS-on-macOS bundles or modify the person's catalogue.

### Post-change review

Deduplication is limited to the exact canonical application path; shared names in distinct provider namespaces remain separate. Tests never inventory the runner's real Applications directory.

### Mini recap

The missing macOS baseline is delivered for acceptance review, with the repository-wide Agora audit exception recorded rather than changed out of scope.

## Done

Accepted 2026-09-30 by Kris Brown on the review packet above.

## Discussion

### Fallback or baseline

Reading the guard as a deliberate fallback is possible: perhaps a configuration that declares providers was meant to own its own inventory completely. That reading does not survive the evidence, because neither declared provider here inventories applications and no diagnostic reports the absence. The two candidate fixes differ in what they assume. Always including `macos-applications` on macOS treats it as a platform baseline and risks double-reporting if a future provider also claims applications. Including it unless a declared provider announces the same surface needs providers to declare what they inventory, which is a protocol change and the larger claim.

Planning selected the macOS baseline. Declaring `inventory` does not promise application coverage, so no declared provider can suppress the platform scan. Two inventories naming the same exact application path have observed one bundle and should emit one unmanaged row; a shared unqualified label or numeric identity is not enough to merge provider namespaces. A failed scan goes through the existing problem channel and must not look like an observed empty scan.

### Silence is the underlying defect

Whichever dispatch rule wins, the reason this went unnoticed for so long is that an unexamined surface and an examined empty surface print the same line. `RIG_UNMANAGED_PROBLEMS` already exists for a provider whose inventory did not reach `observed`, so the report has somewhere to say "not examined" — it simply has no entry for a surface that was never dispatched at all. Making the skip visible is cheaper than deciding the dispatch rule and would have surfaced this on the first run.

### Cross-repository consequence

`DOTFILES-UE-036` in the chezmoi source should be re-read once this is understood, because its stated rationale depends on a check that does not currently run. That is a note for that record's own planning rather than a dependency of this one; each repository owns what it can verify, and this record owns only the dispatch behaviour.
