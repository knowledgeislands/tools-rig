---
id: KI-TOOL-RIG-CORE-070
area: CORE
title: Handler read-back after confirmation
purpose: corrective
theme: rig
status: triage
priority: medium
size: s
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-23T06:43:00Z
updated_at: 2026-10-23T06:43:00Z
---

# KI-TOOL-RIG-CORE-070: Read Back a Default Handler Only After macOS Confirms It

## Goal

An attended `rig apply` of a `default-application` resource that makes macOS ask the person to confirm the new handler records the outcome the person chose. A change the person accepts is recorded as applied on the first run, with no failed-apply record and no second run needed to clear it; a change the person declines, or never answers, is still reported as not effective.

## Context

On 23 October 2026 the chezmoi work applied the `.sh`, `.zsh` and `.toml` handlers on `terra` (Rig at `87fa261`). Each first apply failed with "handler assignment not effective; native confirmation may be required", although macOS had shown a confirmation prompt. About a minute after Kris accepted it, each extension resolved to Zed, and a second, unprompted apply completed (`reconciled:extension:toml`) and cleared the failed-apply records. Evidence: the [handlers-retry](/Users/krisbrown/.local/state/ki/agents/chezmoi/handlers-retry.report.md) and [drift-resolve](/Users/krisbrown/.local/state/ki/agents/chezmoi/drift-resolve.report.md) reports. In the earlier [stage3](/Users/krisbrown/.local/state/ki/agents/chezmoi/stage3.report.md) run Kris declined the prompt by mistake, and the same failure wording appeared.

The [stage3-blind review](/Users/krisbrown/.local/state/ki/agents/chezmoi/stage3-blind.report.md) located the cause: the adapter accepts the native setter's success and then [reads the handler back](../../src/rig/29-default-applications.bash) at once, so the observation still shows the old handler while the prompt is open. The "native confirmation may be required" wording is a generic suggestion, not detection of a dialog.

This is distinct from [KI-TOOL-RIG-CORE-069](KI-TOOL-RIG-CORE-069-dynamic-type-handler-fallback.md): `.sh` and `.zsh` are declared types (`public.shell-script`, `public.zsh-script`), and the timing affects declared and dynamic types alike.

## Boundary

- **In:** a bounded wait or poll for the effective handler after the setter succeeds, so a confirmation the person answers within the bound is observed; distinct reporting of a timeout, a decline and an ineffective assignment; Bats coverage through the bridge fixture; the default applications guide.
- **Out:** the dynamic-type setter route, which KI-TOOL-RIG-CORE-069 owns; detecting or answering the macOS dialog programmatically; any live handler change during delivery.

## Dependencies / blocks

None. Planning should check whether KI-TOOL-RIG-CORE-069's chosen route, if it moves to `NSWorkspace`'s asynchronous setter, already supplies the wait, and merge the two if so.

## Discussion

- The bound needs choosing: long enough for an attended person to read and answer the prompt, short enough that an unattended run does not hang. Unattended applies never get a prompt answered, so they should fail promptly with a named detail.
- Observed on `terra`, macOS 27; the prompt has not been characterised on `sol`.
