---
id: KI-TOOL-RIG-CORE-072
area: CORE
title: Application configuration touch points
purpose: capability
theme: rig
status: triage
priority: medium
size: m
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-24T09:55:48Z
updated_at: 2026-10-24T09:55:48Z
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
