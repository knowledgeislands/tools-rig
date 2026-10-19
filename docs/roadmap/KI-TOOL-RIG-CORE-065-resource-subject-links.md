---
id: KI-TOOL-RIG-CORE-065
area: CORE
title: Resource subject links
purpose: capability
theme: rig
status: triage
priority: medium
size: m
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-19T20:49:28Z
updated_at: 2026-10-19T20:49:28Z
---

# Resource Subject Links and Per-Profile Configured Tools

## Goal

A setting, service, scheduled job or firewall can name the catalogue tool it configures with one optional `tool = "ID"` subject link, and `rig show [--profile P] --format json` reports, for every tool entry, the qualified resources in that profile which configure it, so a consumer such as the rig.midnight.ninja site reads "configured on this host" from Rig instead of reverse-engineering resource fields.

## Context

The rig.midnight.ninja site asked for a per-host flag showing which tools carry their own configuration (Ask A in [KB-MIDNIGHT-RIG-SITE-001](/Users/krisbrown/workspaces/personal/apps-rig.midnight.ninja/docs/roadmap/KB-MIDNIGHT-RIG-SITE-001-show-hosts-per-tool.md)). The [rig site configuration design note](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/design/rig-site-config.md), sections 1 and 2, found that the existing `requires` link means "prerequisite", not "configures": `dock.workstation` requires dockutil and spark-desktop but configures neither. `[default-application.ID]` already carries `tool` with the subject meaning, parsed into `requires` (`src/rig/10-configuration.bash`). The `rig show` JSON has no specification today, although the site already depends on it.

Kris chose this shape on 19 October 2026 (SITE-CONFIG-SHAPE a), [Tools burndown decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/decisions.md)): an explicit `tool` subject link, `configured_by` in the `rig show` JSON, and a new specification clause covering that JSON.

## Boundary

- In: an optional `tool = "ID"` on `[setting.*]`, `[service.*]`, `[scheduled-job.*]` and `[firewall.*]`, with the meaning `[default-application.*]` already gives it; the subject tool entering the profile's prerequisite closure as a `requires` entry does; validation that the named tool exists in the catalogue.
- In: deriving, during profile resolution after resource selection, that a selected tool is configured by a profile when the profile selects at least one setting, default application, service, scheduled job or firewall whose subject `tool` names it. A `requires`-only link does not count.
- In: every `tools[]` entry in `rig show --format json` always carrying `configured_by`, an array of qualified resource identities such as `default-application:svg` in bytewise order, empty when none; the text forms gaining a matching "Configured by" line in `rig show TOOL` and a marker in the tool table.
- In: a RIG-QUERY clause in [the queries specification](../specs/queries.md) specifying the complete `rig show` JSON tool entry, including `id`, `name`, `category`, `purpose` and `configured_by`; the configuration specification and guide documenting `tool` on each resource kind.
- Out: any change to `rig export --profile public`, which stays byte-identical (RIG-PUB-002); a public-export profile comparison; the coarse acquisition kind (Ask B), parked until the site side asks; adding the links to Kris's configuration, which the chezmoi repository owns.

## Done when

`rig show` JSON for a fixture `laptop` and `studio` carries `configured_by`. Fixture tests cover a tool configured in one profile and not the other, the subject link selecting its tool, a `requires`-only resource not counting, and public-export byte-identity. The configuration guide documents `tool` on each resource kind, and the RIG-QUERY clause specifies the JSON.

## Dependencies / blocks

Not blocked. The chezmoi repository's data step, which adds `tool` to the services and scheduled job that concern a catalogue tool in Kris's Rig configuration, waits for this record; the site shows nothing until that step lands.

## Discussion

Alternatives the design note weighed and set aside: deriving the flag from `requires` (wrong on the only live example), from a preference domain matching an application bundle identifier (needs declared bundle identities and covers no service or job; possible later sugar), a tool-side `configures` list (splits one fact across two tables), and the Dock-item filter meaning (would make configuration divergence a pure echo of tool divergence). The handoff's plain `configured: true|false` was the other option Kris did not take; the list keeps each flag auditable. Today's declared data gives the same answer on terra and sol for every tool, so the site's columns stay identical until Kris declares genuinely host-specific configuration. Planning should settle whether `[port.*]`, whose `owner = "tool:ID"` already names a tool, and Dock layouts should count as configuring resources. Capture only; adoption, priority and plan belong to this repository.
