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
updated_at: 2026-10-30T00:28:30Z
---

# Set a Default Application for an Extension With No Declared Content Type

## Goal

A `macos-handlers` declaration with `kind = "extension"` assigns its handler even when no installed application declares a content type for that extension, so macOS resolves it only to a dynamic `dyn.*` type. Observation and apply agree on the handler for such an extension, and a failure that remains names the cause rather than a bare Launch Services code.

## Context

On 19 October 2026 the chezmoi work's [apply-carry run](/Users/krisbrown/.local/state/ki/agents/chezmoi/apply-carry.report.md) ran `rig apply --target default-application:toml` on `sol`. It failed with `handler assignment failed: -50`. `toml` resolves to the dynamic type `dyn.age81k55rru`: Zed's and Warp's `Info.plist` files list the extension but declare no type for it. Warp stays the handler and `rig doctor` reports `default-application.toml` as drifted. The 23 October evidence below supersedes the initial expectation that terra would fail the same way.

The [toml-review run](/Users/krisbrown/.local/state/ki/agents/chezmoi/toml-review.report.md) confirmed that the declaration is correct and the gap is portable behaviour. In the embedded bridge in `src/rig/29-default-applications.bash`, `contentType()` turns an extension into a type with `UTTypeCreatePreferredIdentifierForTag`, and apply passes that type to `LSSetDefaultRoleHandlerForContentType`, which returned -50 in the recorded sol apply. There is no fallback. The review did not reproduce the setter failure independently, so the dynamic-type cause is consistent with the evidence but not yet isolated.

## Boundary

- **In: a fallback for dynamic types.** When the resolved type is dynamic, assign the handler through an interface that accepts it. The candidate the carry report named is `NSWorkspace` `setDefaultApplicationAtURL:toOpenContentType:completionHandler:` with a `UTType` built from the extension. Planning confirms on a real Mac which interface works, and whether a declared type should take the same path.
- **In: matching observation.** Observe the handler for an undeclared extension the same way it is assigned, so a successful apply does not still read as drifted.
- **In: a clear failure.** If no interface can assign the handler, report a named detail such as `undeclared-content-type` in apply and doctor.
- **In: tests and guide.** Cover the dynamic-type branch in `tests/rig-default-applications.bats` through the bridge fixture, and state the behaviour in the [default applications guide](../guides/user/default-applications.md).
- **Out:** Finder's per-file override, editing third-party `Info.plist` files, registering a type on an application's behalf, and any apply on `sol` or `terra` during delivery. The attended carry on each Mac follows the release.

## Current state

Historical diagnosis grounded at `66c9c57` on 20 October 2026 from source and read-only Launch Services observation on `sol` (macOS 27.0.1, build 26A434). No handler was registered or set.

- **Bridge.** [`29-default-applications.bash`](../../src/rig/29-default-applications.bash) holds the static bridge `RIG_DEFAULT_HANDLER_SCRIPT`. Its `contentType()` calls `UTTypeCreatePreferredIdentifierForTag` with a null conforming type. Observe calls `LSCopyDefaultRoleHandlerForContentType` and apply calls `LSSetDefaultRoleHandlerForContentType`, both with all roles. A non-zero setter code throws `handler assignment failed: <code>`. Nothing in the bridge detects a dynamic type.
- **Two dynamic identifiers.** For `toml`, the legacy call with a null conforming type returns `dyn.age81k55rru`. `UTType typeWithFilenameExtension:` and the legacy call conforming to `public.data` both return `dyn.ah62d4rv4ge81k55rru`, with `dynamic` true. `rs` shows the same split (`dyn.age81e62` against `dyn.ah62d4rv4ge81e62`). For declared extensions (`md`, `yaml`, `json`) all three routes return the same identifier.
- **Observers agree today.** Copying the handler for either `toml` identifier returns `dev.warp.Warp-Stable`, and `NSWorkspace` `URLForApplicationToOpenContentType:` returns `/Applications/Warp.app`. Warp holds `toml` through its extension claim: `LSHandlers` in the Launch Services secure preferences has no `toml` or `dyn.*` entry. A Rig-assigned declared type, `net.daringfireball.markdown`, is stored there with `LSHandlerRoleAll = dev.zed.zed`.
- **Native interface present.** `NSWorkspace` responds to `setDefaultApplicationAtURL:toOpenContentType:completionHandler:`, and the bridge can load `UTType` from `UniformTypeIdentifiers` via `NSClassFromString`. `ObjC.import("UniformTypeIdentifiers")` fails, because the framework has no bridge support. JXA under `osascript` runs a JavaScript function as a block, and a main-queue block completes while the bridge spins `NSRunLoop`.
- **Unproved.** No read-only check can show which setter accepts a dynamic type, so three things remain open. First, -50 is still attributed to the dynamic type only by the carry report. Second, it is unknown whether `LSSetDefaultRoleHandlerForContentType` accepts the `public.data`-conforming `dyn.ah62…` identifier. Third, it is unknown whether `NSWorkspace` calls its completion handler on a thread JXA can receive, and whether it asks for consent. Step 1 settles these on a real Mac with Kris present.
- **Tests.** [`tests/rig-default-applications.bats`](../../tests/rig-default-applications.bats) stubs `osascript`. The fixture requires the bridge text to contain `LSRegisterURL`, `LSSetDefaultHandlerForURLScheme` and `LSSetDefaultRoleHandlerForContentType`, keys its state by `kind-value`, and models `apply-fail`, `decline`, `observe-fail` and `invalid`. Two macOS-only tests compile and reflect the real bridge, and observe a scheme, without calling a setter.
- **Specifications.** [RIG-ORCH-044](../specs/orchestration.md) requires extensions to resolve to content types and file types to be assigned with all roles. [RIG-STATE-044](../specs/state.md) requires observation to compare handlers through Launch Services. Neither mentions dynamic types.

Planning rechecked against `80ab019ae96fa4b01adfa28ecd7622ce59b73b44` on 30 October 2026. Record history contains the 20 October diagnosis (`6e060d096f1f39fc297fcc4589c43a8f86b6b4bc`) and the 23 October terra evidence (`6ecdd0457bf89cccceaa2b1d2725c6a35dd9c7cf`), with no later probe result. The latter proves that the existing setter can work for TOML on terra, so dynamic types are not universally rejected; it does not establish a working route or explain -50 on sol.

[Handler read-back after confirmation](KI-TOOL-RIG-CORE-070-handler-read-back-after-confirmation.md) is awaiting review, with its implementation already present in `e882998`: `rig_default_application_confirmed` polls after a successful setter, using `RIG_HANDLER_CONFIRMATION_TIMEOUT` (120 seconds for a terminal, 0 unattended by default) and `RIG_HANDLER_CONFIRMATION_INTERVAL` (2 seconds by default). The bridge still uses the legacy null-conforming identifier and setter. Its non-zero result returns before the confirmation helper, so that change does not resolve sol's recorded -50. The fixture now also models `confirm-after:<n>`; preserve that coverage and the distinct confirmation outcomes.

## Steps

- [ ] **1. Resolve RIG-069-PROBE before Ready.** Kris must separately authorise and attend the native probe on sol; this planning run cannot perform it. First record the current OS/build, Rig revision, application bundle identifiers and effective handlers, and agree restoration to that observed baseline. The historical Warp handler below is not a current restoration instruction. Review the Discussion probe before executing it. Run `legacy`, `modern`, then `workspace`, with `observe` after each; record setter return, completion/error/timeout, prompts and the two Launch Services handler values plus the NSWorkspace application. Allow Kris to answer each prompt and bound effective read-back to 120 seconds; do not advance to another rung while a prompt or completion is outstanding. Stop at the first rung whose three observers agree on Zed. Record any restoration result and disclose that restoring an effective handler may leave an explicit Launch Services entry. If no rung works or observations disagree, stop and replan rather than changing a third-party type declaration.
- [ ] **2. Settle and approve one route.** Replace the remaining conditional plan with the evidenced route and obtain plan approval before Ready. If `legacy` succeeds and read-back converges with the delivered confirmation helper, investigate the historical failure and narrow this record with Kris rather than adding an unnecessary fallback. If `modern` alone succeeds, resolve extensions with the UTType identifier and retain the existing setter. If only `workspace` succeeds, add a dynamic-only NSWorkspace setter and a run-loop completion wait bounded to 30 seconds, treating native error or timeout as failure. Preserve declared UTI, declared extension and scheme behaviour. A completion timeout must not launch another setter or claim cancellation of a native request.
- [ ] **3. Align observation and assignment.** For the selected dynamic route, use one resolved identifier in both actions. If NSWorkspace is required, observe through `URLForApplicationToOpenContentType:` and the returned application's bundle identifier. Preserve the shell's confirmation helper after successful native completion, including its attended/unattended budget and declined/unanswered outcomes; do not add a second consent wait in the bridge.
- [ ] **4. Name proved dynamic failures.** Define a stable bridge response that the shell can distinguish from a bundle identifier or arbitrary native output. Map a proved dynamic setter rejection to `undeclared-content-type` in apply and doctor without a success receipt. Give completion timeout and observation failure distinct details; do not label an unanswered or declined prompt as a type failure. Preserve declared-type exit-code diagnostics and the confirmation helper's messages. Observation must not manufacture historical setter failure from a handler mismatch; if doctor needs last-apply evidence, use the existing failed-apply evidence path and verify it.
- [ ] **5. Extend contained tests.** Add fixture cases for the selected route's dynamic success and native rejection, observe/apply identifier agreement, and dynamic completion timeout if the workspace route is needed. Assert apply exits unsuccessfully on rejection or timeout, keeps failed-apply evidence and doctor names the failure; successful recovery clears it. Retain declared extension, explicit UTI, scheme and `confirm-after:<n>`/decline coverage. Verify timeout does not trigger another setter. Extend macOS reflection tests only for the selected symbols, without calling a real setter. Fixture tests must assert route/identifier arguments, not just the presence of symbol text.
- [ ] **6. Align the public contract.** Amend RIG-ORCH-044 and RIG-STATE-044 for the proved dynamic route, shared identifier and truthful failure reporting. Update the default applications guide with the supported behaviour, named errors and retained confirmation wait. Align the existing default-applications man-page text and changelog with any newly visible behaviour; do not promise support before the route is proved.
- [ ] **7. Assemble and verify.** Regenerate `bin/rig` with `scripts/assemble-rig --write` and run the complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository), with contained Bats fixtures and stdin redirected from `/dev/null`. No live handler apply is part of delivery. An attended carry after release requires its own authority.

## Files touched

- `src/rig/29-default-applications.bash` - selected bridge route, observation and failure mapping; retain the existing confirmation helper.
- `bin/rig` - regenerated, never edited.
- `tests/rig-default-applications.bats` - dynamic fixture cases, argument assertions and read-only reflection checks.
- `docs/specs/orchestration.md`, `docs/specs/state.md` - RIG-ORCH-044 and RIG-STATE-044.
- `docs/guides/user/default-applications.md`, `man/rig.1`, `CHANGELOG.md` - visible handler behaviour and errors.
- This record. The related handler read-back record is read-only.

## Verify

- Before Ready: Discussion contains sol's attended probe evidence, an agreed route, concrete remaining steps and owner approval. No setter or probe is authorised by this planning record alone.
- `bats tests/rig-default-applications.bats </dev/null` and `bats tests/ </dev/null` pass with dynamic success/rejection, identifier agreement, recovery, declared-type/scheme regressions and existing confirmation outcomes. Workspace timeout coverage is required only if that route is selected.
- Read-only macOS reflection tests prove symbol availability, not setter effectiveness. Fixtures prove shell and bridge contracts, not native acceptance of a dynamic type.
- The full gate in [Develop Rig](../guides/developer/README.md#verify-the-repository), including assembly consistency, and `git diff --check` pass. Repository audit findings must be resolved or explicitly dispositioned before delivery is claimed verified.
- After release and separate authority, an attended sol carry succeeds and doctor no longer reports `default-application.toml` drifted. Terra's 23 October success is retained as evidence; repeat there only if separately required, not as an unresolved initial carry.

## Dependencies / blocks

Ready is blocked solely on RIG-069-PROBE: there is no attended sol setter/read-back result that chooses a route or refutes the need for a fallback. Read-only source, interface reflection and terra's success cannot supply it. Kris must separately authorise and attend the probe, then approve the resulting concrete plan. This run changes no handler and leaves the record draft.

The confirmation helper from [Handler read-back after confirmation](KI-TOOL-RIG-CORE-070-handler-read-back-after-confirmation.md) is already present, so that record's awaiting-review status is not a build-order blocker and `blocked_by` stays empty. Do not change or accept it. Sol's TOML hold remains; terra's TOML carry succeeded on 23 October, superseding the earlier instruction to omit that target there.

## Documentation impact

### Decision Records

None. The change stays inside [ADR-KI-TOOL-RIG-005](../decisions/ADR-KI-TOOL-RIG-005-provider-execution-contract.md)'s native-tool boundary: Launch Services or `NSWorkspace`, no `duti` and no runtime SDK.

### Specifications

RIG-ORCH-044 and RIG-STATE-044 gain the proved dynamic-type clauses and truthful failure contract (step 6).

### Guides

The default applications guide, aligned man-page text and changelog (step 6).

### Roadmap

This record only.

## Discussion

### RIG-069-PROBE - Native setter evidence

**Context:** The 23 October evidence establishes a successful legacy TOML assignment on terra, not sol. The current bridge still uses that legacy route, and the delivered confirmation helper only runs after the setter succeeds. The sol -50 cause and the effective alternative remain unproved.

**Query:** Will Kris separately authorise and attend the bounded sol probe in step 1, then return the rung results, effective read-back after consent and restoration outcome so the route can be settled and the plan approved?

**Options:**

a) (recommended, confidence high - only attended sol evidence distinguishes native rejection from confirmation timing) Keep this record draft and arrange the bounded probe with Kris; no live change in this planning run.

b) Keep this record draft and defer the probe; sol's TOML hold remains and implementation cannot start.

### Native interface and identifier rationale

- `NSWorkspace`'s setter is asynchronous and may need user consent for some types. A read-only check on 20 October 2026 showed that JXA runs a function as a block and receives a main-queue completion while it spins the run loop. Whether `NSWorkspace` delivers its completion that way, and whether it asks for consent, is left to step 1.
- The split between `dyn.age81k55rru` and `dyn.ah62d4rv4ge81k55rru` is the likely cause of a quieter defect. Even if a setter accepted the bridge's null-conforming identifier, `NSWorkspace` and Finder resolve the `public.data`-conforming one, so step 3 makes observe and apply agree on a single identifier.
- Pulling `[default-application.toml]` from the private declaration would hide the owner's intent, so the fix belongs here rather than in chezmoi.

### Historical probe proposal

This is the 20 October proposal, retained for review before any separately authorised attended run. Step 1 supplies the current safety and evidence requirements; the snippet alone is not an execution instruction.

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

### Terra evidence

Evidence from `terra`, 23 October 2026 (Rig `87fa261`, macOS 27), from the chezmoi work's attended applies ([stage3](/Users/krisbrown/.local/state/ki/agents/chezmoi/stage3.report.md), [handlers-retry](/Users/krisbrown/.local/state/ki/agents/chezmoi/handlers-retry.report.md), [drift-resolve](/Users/krisbrown/.local/state/ki/agents/chezmoi/drift-resolve.report.md)):

- `rig apply --target default-application:toml` on `terra` did not fail with -50. macOS showed a confirmation prompt, the apply reported "handler assignment not effective; native confirmation may be required" (exit 1), and after Kris accepted the prompt `.toml` resolved to Zed (`dev.zed.Zed`). A second, unprompted apply completed (`reconciled:extension:toml`) and cleared the 19 October failed-apply record. `rig doctor` on `terra` no longer reports `default-application.toml`. So on `terra` the existing Launch Services route took effect for the dynamic type once the prompt was answered; step 1's probe on `sol` should establish whether `sol`'s -50 is a difference of machine or macOS build rather than of the type.
- `.sh` and `.zsh` failed in exactly the same way first time and now resolve to Zed after the same accept-then-re-run sequence. They are declared types (`public.shell-script`, `public.zsh-script`), not dynamic ones, so their failure is not this record's defect: it is the read-back timing captured as [KI-TOOL-RIG-CORE-070](KI-TOOL-RIG-CORE-070-handler-read-back-after-confirmation.md), which very likely also explains the first `.toml` failure on `terra`.
- All three extensions now open in Zed on `terra`; `sol` still has `.toml` held.

### Planning authority

Planning on 30 October 2026 is bounded by GO-PLAN a) under ORCA-HOST: no live probe, handler write or implementation. The coordinator authorised proceeding despite the unrelated missing-size audit warning on the tailnet listener record; it remains untouched.

Adoption: Kris's OVERNIGHT decision of 20 October 2026 at 00:28 BST ([mac-studio-setup decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.mac-studio-setup/decisions.md)) authorised acting on the [triage review](/Users/krisbrown/.local/state/ki/agents/mac-studio-setup/triage-review.report.md)'s high-confidence recommendations: adopted into Now, confidence high, for diagnosis and planning, because a recorded assignment failure exposes a bounded portable handler gap whose exact cause and working fallback remain unproved. Diagnosis stays isolated: no live handler change, `duti` call or apply on `sol` or `terra` is authorised.
