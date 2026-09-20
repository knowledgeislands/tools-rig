---
id: RIG-CORE-009
area: CORE
title: Cache cleanup lifecycle
theme: orchestration
horizon: soon
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-20T10:40:01Z
updated_at: 2026-09-20T10:40:01Z
---

# RIG-CORE-009: Cache cleanup lifecycle

## Goal

Rig users can identify and safely remove obsolete Rig-owned cached data so upgrades and retained diagnostic artifacts do not consume unbounded disk space.

## Context

Rig uses its XDG cache directory for temporary publication trees and may retain complete failed publication exports for diagnosis. Future versions may introduce other versioned or replaceable cached artifacts. Without an explicit lifecycle, obsolete data can accumulate while users cannot reliably distinguish safe-to-remove Rig data from current state or provider-owned caches.

## Boundary

This item does not make cleanup part of the current documentation lifecycle, remove provider-native caches, delete configuration or state, or author a broad filesystem cleanup mechanism. It does not change the present publication failure-retention contract before a replacement policy is specified and verified.

## Shaping

- Define the exact Rig-owned cache classes and which artifacts are current, retained for diagnosis, or obsolete.
- Choose an explicit, inspectable cleanup surface with a non-mutating preview and bounded deletion targets.
- Specify retention, interruption, symlink, path-substitution, and concurrent-process safety before implementation.
- Keep Homebrew, uv, chezmoi, browser, language-runtime, and other provider-native caches outside Rig ownership.
- Promote to Next once the cache inventory, retention policy, command shape, and verification strategy are agreed.

## Discussion

### Ownership boundary

Cleanup must be based on data Rig created beneath its own cache root. Provider ownership remains unchanged: Rig may explain that another system owns storage, but it must not treat that system's cache as Rig-managed data.

### Safety model

The useful operation is narrower than generic disk cleanup. A preview should identify exact candidates and reasons, while deletion must fail closed for unexpected file types, substituted paths, active staging trees, or anything outside the pinned Rig cache root.

### Retention policy

Failed publication exports are intentionally retained for diagnosis today. Shaping must decide whether age, count, explicit selection, successful retry, or another observable condition makes one eligible for cleanup without erasing the only useful failure evidence.
