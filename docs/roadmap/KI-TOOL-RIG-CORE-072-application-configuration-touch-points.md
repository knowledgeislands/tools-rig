---
id: KI-TOOL-RIG-CORE-072
area: CORE
title: Application configuration touch points
purpose: capability
theme: rig
kind: deliver
status: draft
horizon: soon
priority: medium
size: m
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-24T09:55:48Z
updated_at: 2026-10-24T10:16:13Z
---

# KI-TOOL-RIG-CORE-072: Record Each Tool's Configuration Touch Points

## Goal

A declared tool can record its configuration touch points: the places on the machine where it keeps the configuration and state it reads or writes in the course of being used. Rig then documents what each application changes, and when the tool is removed or retired, the same list says what to review or remove, so the inventory no longer has to be rediscovered by hand.

## Context

Kris, 24 October 2026 at 10:53 BST, after the chezmoi work had deleted Fileside and Tagception from `terra`:

> in the rig, I also want to capture for each of them each of the tools and such that we're using. If it's modifying files directly, not things of its output necessarily, but things that it uses for configuration, I think it'd be useful for us to capture that as part of using the application and document those touch points. So, for example, the full set that you've just had and given me for file side and for tagception ... if we did keep something like that, we would have wanted to have these files in them. So that can be a roadmap item that goes into rig.

Two worked examples from that work show the shape of a touch-point list, each path checked on `terra` before deletion:

- [fileside-tagception-delete.sh](/Users/krisbrown/.local/state/ki/agents/chezmoi/fileside-tagception-delete.sh): for Fileside, `~/Library/Application Support/Fileside`, `~/Library/Logs/Fileside` and the `app.fileside.fileside` preferences domain; for Tagception, `~/Library/Caches/com.madebyevan.Tagception`, `~/Library/WebKit/com.madebyevan.Tagception` and the `com.madebyevan.Tagception` domain. The script drops each domain through `defaults delete` before removing its plist, so `cfprefsd` does not write it back.
- [adobe-system-delete.sh](/Users/krisbrown/.local/state/ki/agents/chezmoi/adobe-system-delete.sh): system-wide, root-owned touch points under `/Library/Application Support`, `/Library/Preferences` and `/Library/Logs`, including a `regid.1986-12.com.adobe` directory and three `com.adobe.*` plists whose names do not follow the application's own name.

Rig already has two neighbouring pieces:

- The [retired application report](../guides/user/retired-applications.md) takes declared `data-paths` on a separate `retired-application` declaration, and checks exact bundle-identifier candidates in Application Support, Caches, Preferences, Saved Application State and Containers. It skips group containers, WebKit, Logs, launch agents and system-wide locations, and the declaration is written only after the application has gone.
- [RIG-CAT-007](../specs/catalogue.md#rig-cat-007--tool-owned-generated-artifacts) keeps generated launchers and handlers with the tool that owns them. That covers artifacts Rig or a provider creates, not the files the application itself writes.

## Boundary

- **In:** a catalogue field on a tool for its touch points, each entry carrying a kind (preferences domain, Application Support, cache, container, group container, WebKit data, log, launch agent, launch daemon, or other configuration file), a literal path or domain, and its scope (user or system); `rig explain` showing them; observation of each touch point in `rig status` or `rig doctor`; carrying a tool's touch points into its `retired-application` evidence so the declaration need not repeat them; the catalogue specification, the retired application guide and Bats coverage.
- **Out:** user output files such as documents, exports and downloads the application produces; any automatic deletion, which stays a reviewed, owner-run step as in the worked examples until a separate record proposes otherwise; discovery by scanning the file system or tracing file access; managing configuration contents, which [KI-TOOL-RIG-CORE-064](KI-TOOL-RIG-CORE-064-unmanaged-configuration-scan.md) owns; reading or printing secrets held at a touch point; the personal catalogue data itself.

## Shaping

The intended approach is one list per tool. A declared tool carries its touch points in the catalogue, each with a kind, a literal path or preferences domain, and a user or system scope. `rig explain` shows the list, `rig status` or `rig doctor` observes each entry, and a later `retired-application` declaration inherits the list rather than repeating it in `data-paths`. Observation reads only: it reports whether each touch point exists, never its contents, and Rig deletes nothing. A removal aid at most lists the touch points for review, or writes a script for the owner to run, in the shape of the Fileside, Tagception and Adobe worked examples.

Known dependencies: the existing retired application report and its `data-paths`, which this record either extends or moves onto the tool; [RIG-CAT-007](../specs/catalogue.md#rig-cat-007--tool-owned-generated-artifacts), which stays the owner of artifacts Rig or a provider generates; and the `defaults` stub in `tests/helpers/isolate.bash`, which any test of a preferences domain must go through. The personal touch-point data lives in the chezmoi source under `dot_config/rig/conf.d/` and is not part of this record's delivery.

Decisions still needed are the planning questions under Discussion: a new field or `data-paths` moved onto the tool; how a preferences domain is expressed apart from its plist, and tested without reaching the real user domain; whether conventional bundle-identifier candidates are derived on an active tool and marked as candidates; how a system-scope touch point is observed and reported without `sudo`; and whether the removal aid stops at a list or generates a script. The split with KI-TOOL-RIG-CORE-064 is settled at adoption, below, but the shape of the shared list is decided in the joint design.

Conditions for promotion to Next: the field shape is agreed in the joint design with KI-TOOL-RIG-CORE-064, so 064's declaration can reuse the same list; the remaining planning questions have answers or an agreed default; and the record still fits size `m`, or is split before planning.

## Dependencies / blocks

None. Blocks nothing. Planning should settle the overlap with KI-TOOL-RIG-CORE-064 before either is designed: this record lists where an application keeps its configuration, and 064 would manage what is in it, so 064's declaration could reuse this list.

## Discussion

### Ownership split

tools-rig owns the schema, validation, `explain`, observation and any doctor or removal behaviour. The personal list of touch points for each of Kris's tools is configuration, not executable content, so it lives in the chezmoi source under `dot_config/rig/conf.d/` beside the tool declarations it extends, and goes through Kris's `chezmoi diff` review. No workstation path or bundle identifier from the worked examples belongs in `bin/rig`; tests use synthetic identities.

### Planning questions

- Whether touch points are a new field on a tool, or the existing `data-paths` moved onto the tool with a kind added, so a tool and its later retirement share one list.
- How to express a preferences domain apart from its plist path, since removing one needs `defaults delete` before the file, and how a test confirms that without reaching the real user domain (the AGENTS.md hazard behind the `defaults` stub).
- Whether Rig derives the conventional bundle-identifier candidates on an active tool as the retired report already does, and marks them as candidates rather than declared touch points.
- How a system-scope touch point is observed without `sudo`, and reported when it cannot be read.
- Whether a removal aid stops at listing the touch points for review, or generates a script like the worked examples for the owner to run; either way Rig never deletes without that step.

### Adoption

Kris adopted this record on 24 October 2026 as Deliver / draft at Soon, choosing interactively after a blind review recommended it with high confidence. It stays a separate record from [KI-TOOL-RIG-CORE-064](KI-TOOL-RIG-CORE-064-unmanaged-configuration-scan.md) and is designed alongside it. This record says where an application keeps its configuration and state; 064 would manage what is in that configuration, so its declaration could reuse this list. Adoption grants no plan, implementation, personal declaration or live operation.
