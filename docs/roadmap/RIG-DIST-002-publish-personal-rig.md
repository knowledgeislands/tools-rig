---
id: RIG-DIST-002
area: DIST
title: Publish personal rig
theme: distribution
horizon: now
status: in-progress
blocks: []
blocked_by: []
baseline_ref: 8807b5579585f1f22b7de832a97d5af68e7181db
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-16T22:30:29Z
---

# RIG-DIST-002: Publish personal rig

## Goal

A person can deploy an exported rig to a configured personal-site destination such as `rig.midnight.ninja` through an explicit trusted publisher.

## Context

Static export should remain hosting-neutral. Deployment systems already own domains, credentials, uploads, builds, and release state, so Rig should coordinate them without becoming a hosting platform.

## Boundary

This item defines and implements publication invocation. It does not provision DNS, own hosting configuration, store credentials, or make the generated site canonical.

## Current state

Rig validates publication declarations, but it cannot yet export their static artifact or dispatch a trusted publisher. The provider dispatcher and public export are both prerequisites. The publisher invocation protocol, artifact handoff, and failure-cleanup contract still need approval before implementation can be marked Ready.

## Locked contract

`rig publish PUBLICATION` renders and validates one isolated export tree under the Rig cache, then invokes exactly one selected custom provider with capability `publish` as `rig-provider-v1 publish PROVIDER PUBLICATION directory ABS_EXPORT_DIR`. It deletes staging after success, preserves the path with a diagnostic after publisher failure or interruption, and preserves the native exit result. Export or validation failure invokes no publisher. Credentials, destination configuration, deployment semantics, DNS, and hosting state remain publisher-owned.

## Steps

- [ ] Approve `rig publish PUBLICATION` as the only initial network publication command and require it to reuse the provider dispatcher with an explicit `publish` capability rather than introduce a second executable runner.
- [ ] Approve the publisher handoff contract: Rig generates and validates one isolated export directory, passes its literal path and the selected publication identity through a documented fixed argument protocol, invokes exactly the configured publisher once, and preserves its native exit result.
- [ ] Approve staging retention and cleanup behaviour for publisher success, publisher failure, and interrupted publication so failure remains diagnosable without silently treating an artifact as deployed.
- [ ] Generate or validate the static artifact through RIG-CLI-003 before dispatch and reject unknown publications, unavailable publishers, missing capabilities, and invalid output.
- [ ] Dispatch only the publication's configured publisher through the common capability and trust checks, with no implicit fallback or hosting-specific core behaviour.
- [ ] Add selection, single-invocation, literal-argument, native-exit, unavailable-capability, failure-cleanup, and non-selected-publisher tests.
- [ ] Align top-level and command help, completion, README command inventory, `rig(1)`, publishing Specification evidence, and the curated v1 changelog.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `README.md`
- `CHANGELOG.md`
- `man/rig.1`
- `docs/specs/publishing.md`
- `docs/roadmap/RIG-DIST-002-publish-personal-rig.md`

## Verify

- `shellcheck bin/rig install.sh`
- `bats tests/`
- `mandoc -T lint man/rig.1`
- Use two recording publishers to prove exactly one selected executable receives the fixed literal handoff and its native exit result is preserved.
- Prove `rig publish` cannot invoke an undeclared executable, a provider without `publish`, or any publisher while export validation fails.

## Dependencies / blocks

RIG-CLI-003 must provide the validated offline artifact. RIG-CLI-001 must provide the common provider capability dispatcher that publisher execution reuses. Readiness is gated on explicit approval of the publisher handoff and staging-cleanup decisions above; hosting credentials and destination setup remain external publisher concerns.

## Delegation

After both dependencies and the publisher protocol are settled, dispatcher integration and adversarial publisher fixture tests can proceed as bounded parallel lanes. One owner must retain the invocation contract, failure semantics, final integration, and documentation alignment.

## Documentation impact

### Decision Records

No new decision is expected if implementation follows ADR-RIG-004 and XDR-RIG-001. Amend them only if publisher authority, arguments, or credential ownership moves across the trust boundary.

### Specifications

Mark RIG-PUB-007 conforming only after tests evidence explicit selection, one trusted invocation, literal handoff, and native outcome preservation.

### Guides

Document how to declare, review, invoke, and troubleshoot a publisher without embedding service credentials or hosting-specific setup in Rig.

### Roadmap

Keep RIG-CLI-003 and RIG-CLI-001 as explicit prerequisites and retain hosting-specific integrations as separate work only when a concrete publisher is selected.

## Discussion

### Publisher authority

`rig publish PUBLICATION` invokes an explicitly configured publisher only after producing or validating the static export. The publisher remains authoritative for deployment and rollback.

### Hosting neutrality

An executable publisher boundary should support a personal server, Cloudflare Pages, GitHub Pages, or another destination without adding any one service as a Rig core dependency.
