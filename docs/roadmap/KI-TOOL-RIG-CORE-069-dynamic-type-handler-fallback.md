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
updated_at: 2026-10-23T06:45:00Z
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

Grounded at `66c9c57` on 20 October 2026 from source and read-only Launch Services observation on `sol` (macOS 27.0.1, build 26A434). No handler was registered or set.

- **Bridge.** [`29-default-applications.bash`](../../src/rig/29-default-applications.bash) holds the static bridge `RIG_DEFAULT_HANDLER_SCRIPT`. Its `contentType()` calls `UTTypeCreatePreferredIdentifierForTag` with a null conforming type. Observe calls `LSCopyDefaultRoleHandlerForContentType` and apply calls `LSSetDefaultRoleHandlerForContentType`, both with all roles. A non-zero setter code throws `handler assignment failed: <code>`. Nothing in the bridge detects a dynamic type.
- **Two dynamic identifiers.** For `toml`, the legacy call with a null conforming type returns `dyn.age81k55rru`. `UTType typeWithFilenameExtension:` and the legacy call conforming to `public.data` both return `dyn.ah62d4rv4ge81k55rru`, with `dynamic` true. `rs` shows the same split (`dyn.age81e62` against `dyn.ah62d4rv4ge81e62`). For declared extensions (`md`, `yaml`, `json`) all three routes return the same identifier.
- **Observers agree today.** Copying the handler for either `toml` identifier returns `dev.warp.Warp-Stable`, and `NSWorkspace` `URLForApplicationToOpenContentType:` returns `/Applications/Warp.app`. Warp holds `toml` through its extension claim: `LSHandlers` in the Launch Services secure preferences has no `toml` or `dyn.*` entry. A Rig-assigned declared type, `net.daringfireball.markdown`, is stored there with `LSHandlerRoleAll = dev.zed.zed`.
- **Native interface present.** `NSWorkspace` responds to `setDefaultApplicationAtURL:toOpenContentType:completionHandler:`, and the bridge can load `UTType` from `UniformTypeIdentifiers` via `NSClassFromString`. `ObjC.import("UniformTypeIdentifiers")` fails, because the framework has no bridge support. JXA under `osascript` runs a JavaScript function as a block, and a main-queue block completes while the bridge spins `NSRunLoop`.
- **Unproved.** No read-only check can show which setter accepts a dynamic type, so three things remain open. First, -50 is still attributed to the dynamic type only by the carry report. Second, it is unknown whether `LSSetDefaultRoleHandlerForContentType` accepts the `public.data`-conforming `dyn.ah62…` identifier. Third, it is unknown whether `NSWorkspace` calls its completion handler on a thread JXA can receive, and whether it asks for consent. Step 1 settles these on a real Mac with Kris present.
- **Tests.** [`tests/rig-default-applications.bats`](../../tests/rig-default-applications.bats) stubs `osascript`. The fixture requires the bridge text to contain `LSRegisterURL`, `LSSetDefaultHandlerForURLScheme` and `LSSetDefaultRoleHandlerForContentType`, keys its state by `kind-value`, and models `apply-fail`, `decline`, `observe-fail` and `invalid`. Two macOS-only tests compile and reflect the real bridge, and observe a scheme, without calling a setter.
- **Specifications.** [RIG-ORCH-044](../specs/orchestration.md) requires extensions to resolve to content types and file types to be assigned with all roles. [RIG-STATE-044](../specs/state.md) requires observation to compare handlers through Launch Services. Neither mentions dynamic types.

## Steps

- [ ] **1. Attended native probe (Kris, on `sol`, before delivery starts).** Save the probe in Discussion to a temporary file outside any repository and run the rungs in order. After each rung, run `observe` and stop at the first rung where all three observers report Zed. Restore path: rerun the rung that worked with `/Applications/Warp.app dev.warp.Warp-Stable`. That gives Warp back as an explicit entry, the same effective handler as its present implicit claim. Finder's Get Info › Open with › Change All is the manual fallback. Record each rung's printed result in Discussion. This is the only live change in the plan, and Kris makes it.
- [ ] **2. Settle the route.** Replan only the remaining steps if the probe contradicts this. If `modern` takes effect, change `contentType()` for extensions to the `UTType` identifier and keep the existing setter. If only `workspace` takes effect, add a dynamic-only branch that sets through `NSWorkspace`, waits on the run loop for a bounded time, and treats a timeout or an error as failure. Declared types keep the proved Launch Services route in both cases.
- [ ] **3. One identifier for observe and apply.** Resolve every extension through the same `UTType` identifier in both actions, so a dynamic assignment is read back under the key it was written to. For the `workspace` route, observe a dynamic type through `URLForApplicationToOpenContentType:` and the bundle identifier of the application it returns.
- [ ] **4. Named failure.** When a dynamic type's setter still fails, the bridge prints a stable marker that the shell maps to the detail `undeclared-content-type`. Apply reports `rig: <section>: native handler assignment failed (undeclared-content-type).`, and the post-apply ineffective message carries the same detail. A declared type's failure keeps the existing exit-code wording.
- [ ] **5. Tests.** Extend the `osascript` fixture with a `dynamic` behaviour that fails the declared route with the marker, and with whichever route step 2 chose. Cover a dynamic `extension` assigning and then reading present, a dynamic failure reporting `undeclared-content-type` in apply and doctor without claiming success, and a declared extension and UTI keeping their current arguments. Extend the reflection test to the symbols the new route uses, still without calling a setter.
- [ ] **6. Specifications and guide.** Amend RIG-ORCH-044 and RIG-STATE-044 for dynamic types: one identifier for observe and apply, the chosen setter, and the named failure. In the [default applications guide](../guides/user/default-applications.md), say that an extension no installed application declares still works and what `undeclared-content-type` means.
- [ ] **7. Assemble and gate.** Regenerate `bin/rig` with `scripts/assemble-rig` and run the complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository). Do not run an apply on `sol` or `terra`; the attended carry follows release.

## Files touched

- `src/rig/29-default-applications.bash` — bridge identifier, dynamic route and failure marker, and the shell detail mapping.
- `bin/rig` — regenerated, never edited.
- `tests/rig-default-applications.bats` — fixture behaviour and the dynamic-type cases.
- `docs/specs/orchestration.md`, `docs/specs/state.md` — RIG-ORCH-044 and RIG-STATE-044.
- `docs/guides/user/default-applications.md` — dynamic-type behaviour and the named failure.
- This record.

## Verify

- The step 1 probe results are recorded in Discussion, and the chosen route matches them.
- `bats tests/ </dev/null` passes, including the new dynamic-type cases and the unchanged declared-type and scheme cases.
- The reflection test shows that the new route's symbols exist on macOS, still without calling a handler setter.
- The full gate in [Develop Rig](../guides/developer/README.md#verify-the-repository), `git diff --check` and `ki repo audit --repo .` pass.
- After release, the attended carry runs `rig apply --target default-application:toml` on `sol` and then `terra`. It is accepted when `rig doctor` no longer reports `default-application.toml` drifted.

## Dependencies / blocks

Delivery is blocked on step 1, Kris's attended probe on `sol`; until then the route in step 2 is a prediction. No other record blocks it. Until it lands, `sol` keeps the TOML drift finding and `terra`'s carry leaves out `default-application:toml`, as the apply-carry report recommends.

## Documentation impact

### Decision Records

None. The change stays inside [ADR-KI-TOOL-RIG-005](../decisions/ADR-KI-TOOL-RIG-005-provider-execution-contract.md)'s native-tool boundary: Launch Services or `NSWorkspace`, no `duti` and no runtime SDK.

### Specifications

RIG-ORCH-044 and RIG-STATE-044 gain the dynamic-type clauses (step 6).

### Guides

The default applications guide (step 6).

### Roadmap

This record only.

## Discussion

- `NSWorkspace`'s setter is asynchronous and may need user consent for some types. A read-only check on 20 October 2026 showed that JXA runs a function as a block and receives a main-queue completion while it spins the run loop. Whether `NSWorkspace` delivers its completion that way, and whether it asks for consent, is left to step 1.
- The split between `dyn.age81k55rru` and `dyn.ah62d4rv4ge81k55rru` is the likely cause of a quieter defect. Even if a setter accepted the bridge's null-conforming identifier, `NSWorkspace` and Finder resolve the `public.data`-conforming one, so step 3 makes observe and apply agree on a single identifier.
- Pulling `[default-application.toml]` from the private declaration would hide the owner's intent, so the fix belongs here rather than in chezmoi.
- Attended probe for step 1. Rung `legacy` confirms or refutes the -50 cause. Rung `modern` tests whether the `public.data`-conforming identifier is enough. Rung `workspace` tests the `NSWorkspace` route, its completion delivery and any consent prompt.

```js
// osascript -l JavaScript probe.js <rung> /Applications/Zed.app dev.zed.Zed
ObjC.import("Foundation"); ObjC.import("AppKit"); ObjC.import("CoreServices");
function s(r) { var v = ObjC.unwrap(ObjC.castRefToObject(r)); return v ? String(v) : "-"; }
function run(a) {
  $.NSBundle.bundleWithPath("/System/Library/Frameworks/UniformTypeIdentifiers.framework").load;
  var UT = $.NSClassFromString($("UTType")), t = UT.typeWithFilenameExtension($("toml"));
  var legacy = $.UTTypeCreatePreferredIdentifierForTag($.kUTTagClassFilenameExtension, $("toml"), null);
  var modern = t.identifier, ws = $.NSWorkspace.sharedWorkspace, app = $.NSURL.fileURLWithPath($(a[1]));
  if (a[0] === "observe") { var u = ws.URLForApplicationToOpenContentType(t);
    return [s(legacy), s($.LSCopyDefaultRoleHandlerForContentType(legacy, $.kLSRolesAll)), ObjC.unwrap(modern),
      s($.LSCopyDefaultRoleHandlerForContentType(modern, $.kLSRolesAll)), u.isNil() ? "-" : ObjC.unwrap(u.path)].join(" "); }
  if (a[0] === "legacy") return "code " + $.LSSetDefaultRoleHandlerForContentType(legacy, $.kLSRolesAll, $(a[2]));
  if (a[0] === "modern") return "code " + $.LSSetDefaultRoleHandlerForContentType(modern, $.kLSRolesAll, $(a[2]));
  if (a[0] === "workspace") { var done = false, err = "none";
    ws.setDefaultApplicationAtURLToOpenContentTypeCompletionHandler(app, t, function (e) {
      err = (e && !e.isNil()) ? ObjC.unwrap(e.localizedDescription) : "none"; done = true; });
    var end = $.NSDate.dateWithTimeIntervalSinceNow(30);
    while (!done && $.NSDate.date.compare(end) < 0)
      $.NSRunLoop.currentRunLoop.runModeBeforeDate($.NSDefaultRunLoopMode, $.NSDate.dateWithTimeIntervalSinceNow(0.1));
    return done ? "completed error=" + err : "timeout"; }
  throw new Error("rung must be observe, legacy, modern or workspace");
}
```

Evidence from `terra`, 23 October 2026 (Rig `87fa261`, macOS 27), from the chezmoi work's attended applies ([stage3](/Users/krisbrown/.local/state/ki/agents/chezmoi/stage3.report.md), [handlers-retry](/Users/krisbrown/.local/state/ki/agents/chezmoi/handlers-retry.report.md), [drift-resolve](/Users/krisbrown/.local/state/ki/agents/chezmoi/drift-resolve.report.md)):

- `rig apply --target default-application:toml` on `terra` did not fail with -50. macOS showed a confirmation prompt, the apply reported "handler assignment not effective; native confirmation may be required" (exit 1), and after Kris accepted the prompt `.toml` resolved to Zed (`dev.zed.Zed`). A second, unprompted apply completed (`reconciled:extension:toml`) and cleared the 19 October failed-apply record. `rig doctor` on `terra` no longer reports `default-application.toml`. So on `terra` the existing Launch Services route took effect for the dynamic type once the prompt was answered; step 1's probe on `sol` should establish whether `sol`'s -50 is a difference of machine or macOS build rather than of the type.
- `.sh` and `.zsh` failed in exactly the same way first time and now resolve to Zed after the same accept-then-re-run sequence. They are declared types (`public.shell-script`, `public.zsh-script`), not dynamic ones, so their failure is not this record's defect: it is the read-back timing captured as [KI-TOOL-RIG-CORE-070](KI-TOOL-RIG-CORE-070-handler-read-back-after-confirmation.md), which very likely also explains the first `.toml` failure on `terra`.
- All three extensions now open in Zed on `terra`; `sol` still has `.toml` held.

Adoption: Kris's OVERNIGHT decision of 20 October 2026 at 00:28 BST ([mac-studio-setup decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.mac-studio-setup/decisions.md)) authorised acting on the [triage review](/Users/krisbrown/.local/state/ki/agents/mac-studio-setup/triage-review.report.md)'s high-confidence recommendations: adopted into Now, confidence high, for diagnosis and planning, because a recorded assignment failure exposes a bounded portable handler gap whose exact cause and working fallback remain unproved. Diagnosis stays isolated: no live handler change, `duti` call or apply on `sol` or `terra` is authorised.
