---
id: KI-TOOL-RIG-CORE-069
area: CORE
title: Dynamic-type handler fallback
purpose: corrective
theme: rig
kind: deliver
status: draft
horizon: now
priority: medium
size: s
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-19T22:30:17Z
updated_at: 2026-10-19T23:58:00Z
---

# Set a Default Application for an Extension With No Declared Content Type

## Goal

A `macos-handlers` declaration with `kind = "extension"` assigns its handler even when no installed application declares a content type for that extension, so macOS resolves it only to a dynamic `dyn.*` type. Observation and apply agree on the handler for such an extension, and a failure that remains names the cause rather than a bare Launch Services code.

## Context

On 19 October 2026 the chezmoi work's [apply-carry run](/Users/krisbrown/.local/state/ki/agents/chezmoi/apply-carry.report.md) ran `rig apply --target default-application:toml` on `sol`. It failed with `handler assignment failed: -50`. `toml` resolves to the dynamic type `dyn.age81k55rru`: Zed's and Warp's `Info.plist` files list the extension but declare no type for it. Warp stays the handler and `rig doctor` reports `default-application.toml` as drifted. `terra` will very likely fail the same way.

The [toml-review run](/Users/krisbrown/.local/state/ki/agents/chezmoi/toml-review.report.md) confirmed that the declaration is correct and the gap is portable behaviour. In the embedded bridge in `src/rig/29-default-applications.bash`, `contentType()` turns an extension into a type with `UTTypeCreatePreferredIdentifierForTag`, and apply passes that type to `LSSetDefaultRoleHandlerForContentType`, which rejects a dynamic type with -50. There is no fallback. The review did not reproduce the setter failure independently, so the dynamic-type cause is consistent with the evidence but not yet isolated.

## Boundary

- **In: a fallback for dynamic types.** When the resolved type is dynamic, assign the handler through an interface that accepts it. The candidate the carry report named is `NSWorkspace` `setDefaultApplicationAtURL:toOpenContentType:completionHandler:` with a `UTType` built from the extension. Planning confirms on a real Mac which interface works, and whether a declared type should take the same path.
- **In: matching observation.** Observe the handler for an undeclared extension the same way it is assigned, so a successful apply does not still read as drifted.
- **In: a clear failure.** If no interface can assign the handler, report a named detail such as `undeclared-content-type` in apply and doctor.
- **In: tests and guide.** Cover the dynamic-type branch in `tests/rig-default-applications.bats` through the bridge fixture, and state the behaviour in the [default applications guide](../guides/user/default-applications.md).
- **Out:** Finder's per-file override, editing third-party `Info.plist` files, registering a type on an application's behalf, and any apply on `sol` or `terra` during delivery. The attended carry on each Mac follows the release.

## Current state

Not yet grounded. `ki-plan` records the current source facts before Ready.

## Steps

- [ ] Diagnose the dynamic-type failure in isolation and plan this record under `ki-plan`, replacing these placeholder sections; no live handler change.

## Files touched

Not yet planned.

## Verify

Not yet planned.

## Dependencies / blocks

Not blocked. Until it lands, `sol` keeps the TOML drift finding and `terra`'s carry leaves out `default-application:toml`, as the apply-carry report recommends.

## Documentation impact

### Decision Records

Not yet assessed.

### Specifications

Not yet assessed.

### Guides

Not yet assessed.

### Roadmap

Not yet assessed.

## Discussion

- `NSWorkspace`'s setter is asynchronous and may need user consent for some types. Planning should check whether `osascript` can wait for its completion handler, or whether the bridge needs another route.
- Pulling `[default-application.toml]` from the private declaration would hide the owner's intent, so the fix belongs here rather than in chezmoi.

Adoption: Kris's OVERNIGHT decision of 20 October 2026 at 00:28 BST ([mac-studio-setup decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.mac-studio-setup/decisions.md)) authorised acting on the [triage review](/Users/krisbrown/.local/state/ki/agents/mac-studio-setup/triage-review.report.md)'s high-confidence recommendations: adopted into Now, confidence high, for diagnosis and planning, because a recorded assignment failure exposes a bounded portable handler gap whose exact cause and working fallback remain unproved. Diagnosis stays isolated: no live handler change, `duti` call or apply on `sol` or `terra` is authorised.
