---
id: RIG-CORE-026
area: CORE
title: Diagnose unusable configuration
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-26T10:00:00Z
updated_at: 2026-09-26T10:00:00Z
---

## Goal

When Rig cannot use somebody's configuration, `rig doctor` explains what is wrong and what to do about it, rather than failing in the same way as every other command.

## Context

`rig doctor` exists to check whether Rig can operate. Given a configuration it cannot load it does neither: it emits the parse rejection and stops.

Observed against a configuration directory containing a retired `[publication.midnight-ninja]` table:

```text
$ rig doctor
rig: error: …/conf.d/10-bad.toml:1: [publication.midnight-ninja] is retired; export a view profile with rig export --profile
$ echo $?
2
```

One line, exit 2, and no diagnosis — identical to what `rig status` prints for the same input. This happened on this workstation for real: a live `90-profiles.toml` still carried a table the source had already migrated away from, and every Rig command refused until the one stale path was reapplied. The command a person reaches for when Rig has stopped working is precisely the command that cannot answer.

The message itself is good. It names the file, the line, the retired construct and the replacement. What is missing is that `doctor` treats an unloadable configuration as a reason not to run instead of as the finding it is.

## Boundary

This does not make any other command tolerate a configuration it cannot parse; a rejection is still a rejection, and `rig apply` should keep refusing. It does not add a repair or migration mode, and it does not relax the retired-construct check.

## Discussion

### What doctor would have to do differently

Report the load failure as its own finding, with the file and reason, and then continue with whatever it can still check without configuration — provider availability, executable paths, platform. That means `doctor` loading configuration defensively where every other command loads it strictly.

### Exit status

A configuration Rig cannot load is a finding, not a rejection of the `doctor` invocation, so the honest status is the one `doctor` already uses for an unhealthy check rather than 2. Settling that is part of the work.
