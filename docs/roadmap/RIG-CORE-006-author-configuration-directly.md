---
id: RIG-CORE-006
area: CORE
title: Author configuration directly
theme: orchestration
horizon: next
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-17T00:00:00Z
updated_at: 2026-09-17T00:00:00Z
---

# RIG-CORE-006: Author Configuration Directly

## Goal

A person can author and read Rig's statement of intent directly, as a set of files Rig owns, without a templating layer standing between the source and the loaded configuration.

## Context

Rig loads one `rig.conf`. Its first real consumer is a chezmoi source repository, which does not author that file: it models the workstation in `.chezmoidata/software.yaml` and renders `rig.conf` from a template. That layering has two costs the consumer has now hit.

The model only exists after a build step, so the checked-in source cannot be read to understand what the machine is meant to be. And it puts a second modelling layer in front of Rig, when Rig's configuration format — with its schema, section model, and fail-closed validation — is already a model.

A single file is also the wrong shape at real size. The consumer's rendered configuration is roughly ninety sections across eighty-one tools, their bindings, providers, profiles, and operations. Nothing outside this repository depends on the file being singular; that is a decision still open to us.

Provider discovery pushes the same problem outward. Because `executable` takes a path, the consumer must place provider executables somewhere and name that path in configuration; today they sit in `~/bin`, a user command surface, even though they are never invoked by hand.

## Boundary

This item covers where Rig reads configuration from and how providers are located. It does not change the section model, field semantics, or validation rules; it does not add templating, includes with logic, or any generation step inside Rig; and it does not migrate the consumer, which is that repository's own work.

## Current state

`rig.conf` is a single file at a single path. `provider.*` sections name provider executables by path. The consumer renders both from chezmoi templates.

## Steps

- [ ] Load configuration from a directory of plain files as well as a single file, with a defined and stable ordering, so a large catalogue can be split along its natural seams.
- [ ] Define the precedence between a single-file and a directory configuration, and fail closed rather than merging ambiguously when both are present.
- [ ] Give Rig a default provider directory under its XDG data location, so a provider can be declared by name and a consumer need not choose a filesystem location or write an absolute path.
- [ ] Keep an explicit `executable` path working for providers outside that directory.
- [ ] Confirm a directory configuration is validated exactly as a single file is, including duplicate section detection across files.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `man/rig.1`
- `README.md`
- `CHANGELOG.md`

## Verify

- `bats tests/`
- `shellcheck bin/rig`
- `mandoc -T lint man/rig.1`
- A configuration split across a directory loads identically to the equivalent single file, including error behaviour on a duplicate section.

## Dependencies / blocks

Independent of RIG-CORE-005, though both must land before the consumer can drop its templating layer.

## Documentation impact

### Decision Records

Expect one. Where configuration is read from, and whether Rig owns a provider location, are contract decisions rather than implementation details. Consolidate into an existing configuration or XDG record rather than adding a third alongside them.

### Specifications

Update the configuration loading contract to cover directory sources, ordering, and precedence.

### Guides

Show authoring a split configuration, and declaring a provider by name.

### Roadmap

None.

## Discussion

### Authoring, not generating

The point is that the loaded configuration is the authored configuration. Adding includes, variables, or conditionals inside Rig would recreate the templating layer this is meant to remove, one level down.

### The manifest stays an observation

The consumer's Homebrew Brewfile must not become a generated projection of this configuration. Rig states what is wanted; the manifest and the live machine are what is there. Generating one side from the other makes the comparison vacuous and destroys the ability to notice that something was installed outside the declaration — which is the drift worth detecting. Nothing in this item should make generation of an acquisition manifest easier or more expected.
