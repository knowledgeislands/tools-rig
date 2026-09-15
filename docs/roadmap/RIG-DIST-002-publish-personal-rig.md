---
id: RIG-DIST-002
area: DIST
title: Publish personal rig
theme: distribution
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-CLI-003]
baseline_ref: null
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-15T11:53:55Z
---

# RIG-DIST-002: Publish personal rig

## Goal

A person can deploy an exported rig to a configured personal-site destination such as `rig.midnight.ninja` through an explicit trusted publisher.

## Context

Static export should remain hosting-neutral. Deployment systems already own domains, credentials, uploads, builds, and release state, so Rig should coordinate them without becoming a hosting platform.

## Boundary

This item defines and implements publication invocation. It does not provision DNS, own hosting configuration, store credentials, or make the generated site canonical.

## Discussion

### Publisher authority

`rig publish PUBLICATION` invokes an explicitly configured publisher only after producing or validating the static export. The publisher remains authoritative for deployment and rollback.

### Hosting neutrality

An executable publisher boundary should support a personal server, Cloudflare Pages, GitHub Pages, or another destination without adding any one service as a Rig core dependency.
