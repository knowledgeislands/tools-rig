---
id: KI-TOOL-RIG-CORE-065
area: CORE
title: Resource subject links
purpose: capability
theme: rig
kind: deliver
horizon: now
status: awaiting-review
priority: medium
size: m
blocks: []
blocked_by: []
baseline_ref: fd3634cb486f7f35797238dda0a0a0171d68dfdc
created_at: 2026-10-19T20:49:28Z
updated_at: 2026-10-19T23:20:17Z
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

## Current state

Re-read on 19 October 2026 at baseline `969ec58`.

- `[default-application.ID]`'s `tool` is parsed straight into its `requires` field (`rig_toml_field`, `src/rig/10-configuration.bash`), so the subject meaning is not stored apart from the prerequisite meaning. `rig show --format json` reads it back from `requires` as the resource's `tool` key.
- `[setting.*]`, `[service.*]`, `[scheduled-job.*]` and `[firewall.*]` accept `requires` arrays but no `tool`. `requires` already gives catalogue validation and prerequisite closure.
- `rig_show_json` (`src/rig/30-commands.bash`) emits tool entries of `id`, `name`, `category` and `purpose` only; `rig_print_profile_tools` prints a fixed four-column table whose exact output `tests/rig.bats` compares.
- `rig show TOOL` (`rig_command_explain_impl`) is profile-independent and rejects `--profile` (RIG-QUERY-002).
- `rig export --profile public` renders tools only, never resources (`src/rig/40-publication-lifecycle.bash`), so no subject link can reach it.

### Planning decisions

- **Storage.** Each of the five kinds stores `tool` as a new scalar `subject` field and, as today for default applications, also adds the same identity to `requires`. Validation and closure are therefore the existing `requires` behaviour, and the JSON `tool` key on a default application is unchanged.
- **Ports and Dock layouts do not count.** A port's `owner = "tool:ID"` names the listener's owner, and a Dock item's `tool` filters presence; neither declares that the resource configures the tool. Counting them would reintroduce the echo the design note set aside. Either can opt in later by gaining `tool`.
- **`rig show TOOL`** is catalogue-level, so its "Configured by" line lists every declared resource whose subject names the tool, independent of profile, or `none`. The per-profile answer belongs to `rig show [--profile P]`.
- **Tool table marker.** The profile tool table gains a trailing `CONFIGURED` column, `yes` or blank, only when at least one selected tool is configured, so a profile without subject links renders exactly as today.
- **Computation.** One pass over the selected resource sections builds the configured-by lists for all tools, so the cost stays linear in resources rather than tools times resources.

## Steps

- [x] Parse `tool` on `[setting.*]`, `[service.*]`, `[scheduled-job.*]`, `[firewall.*]` and `[default-application.*]` into a scalar `subject` field that also adds a `requires` entry; register `subject` in `rig_field_kind`.
- [x] Add a single-pass helper that maps each selected tool to its sorted qualified configuring resources for the resolved profile.
- [x] Emit `configured_by` on every `rig show --format json` tool entry; add the conditional `CONFIGURED` column to the profile tool table; add the "Configured by" line to `rig show TOOL`.
- [x] Add fixture tests: a tool configured in `laptop` and not in `studio`; the subject link pulling its tool into a profile; a `requires`-only resource not counting; an unknown subject tool failing validation; the `rig show TOOL` line; a profile with no links rendering the unchanged table; public export byte-identical with and without links.
- [x] Add a RIG-QUERY clause specifying the complete `rig show` JSON tool entry, and extend RIG-QUERY-003 for the new line; document `tool` on each resource kind in `docs/specs/configuration.md` and in the operational-resources guide.
- [x] Reassemble `bin/rig`, update `man/rig.1` if it lists the explanation fields, and run the complete local gate.

## Files touched

- `src/rig/10-configuration.bash`, `src/rig/30-commands.bash` and the assembled `bin/rig`.
- A new `tests/rig-subject-links.bats`.
- `docs/specs/queries.md`, `docs/specs/configuration.md`, `docs/guides/user/operational-resources.md`, and `man/rig.1` if it enumerates explanation fields.
- This record.

## Verify

- The new suite passes with `bats tests/rig-subject-links.bats </dev/null`, and the existing exact-table tests in `tests/rig.bats` still pass unchanged.
- `rig export --profile public` output is byte-identical between a fixture with subject links and the same fixture without them.
- [Develop Rig's complete gate](../guides/developer/README.md#verify-the-repository) passes, `bats tests/ </dev/null` included. No live apply.

## Dependencies / blocks

Not blocked. The chezmoi repository's data step, which adds `tool` to the services and scheduled job that concern a catalogue tool in Kris's Rig configuration, waits for this record; the site shows nothing until that step lands.

## Documentation impact

### Decision Records

None; Kris's SITE-CONFIG-SHAPE answer is the decision, and this record carries its rationale.

### Specifications

A new RIG-QUERY clause for the `rig show` JSON tool entry; RIG-QUERY-003 gains the "Configured by" line; the configuration specification documents `tool` on each of the five resource kinds.

### Guides

The operational-resources guide shows `tool` on a setting and a service.

### Roadmap

This record moved to Awaiting review at delivery.

## Review

### Delivered

Every step as planned: `tool = "ID"` on settings, services, scheduled jobs, firewalls and default applications is stored as a scalar `subject` that also adds one `requires` entry; `rig show --format json` gives every tool entry a `configured_by` array; the profile tool table gains a `CONFIGURED` column only when the profile configures a selected tool; and `rig show TOOL` gains a profile-independent `Configured by` line. Baseline `fd3634cb486f7f35797238dda0a0a0171d68dfdc`; the delivery commit follows it. Nothing was applied live, and Kris's configuration is untouched.

### Change Summary

- `src/rig/10-configuration.bash`: `rig_toml_field` maps `tool` on the five kinds to `subject`; `rig_field_kind` registers it as scalar; `rig_parse_file` adds the derived `requires` entry beside it.
- `src/rig/20-orchestration.bash`: `rig_append_resource_fields` keeps `subject` out of external provider arguments.
- `src/rig/30-commands.bash`: `rig_collect_subject_links` makes the single pass over selected or catalogue resources; `rig_tool_configured_by` reads one tool's sorted list; `rig_show_json`, `rig_print_profile_tools` and `rig_command_explain_impl` render it; `rig_explain_resource` prints `tool=` once and hides the derived `requires` entry.
- `src/rig/00-runtime.bash`: the two subject-link globals; `bin/rig` reassembled.
- `tests/rig-subject-links.bats`: six tests covering the Done when and Verify cases. `tests/rig.bats`: the exact `rig show TOOL` expectation gains `Configured by: none`.
- `docs/specs/queries.md`: RIG-QUERY-003 gains the `Configured by` line and new RIG-QUERY-009 specifies the JSON tool entry and table column. `docs/specs/configuration.md` documents the subject `tool` on the five kinds. The operational-resources guide shows `tool` on a service and a setting. `man/rig.1` names the field and the explanation line.
- Deviation: none. A blank `CONFIGURED` cell ends the row with the table's two-space column separator, as other tables' empty last cells already do.

### Verification

- `bats tests/rig-subject-links.bats </dev/null`: 6 of 6 pass; the exact-table tests in `tests/rig.bats` pass unchanged.
- `bats tests/ </dev/null`: 589 of 590 passed on the first run; the one failure was the exact `rig show TOOL` comparison in `tests/rig.bats`, which RIG-QUERY-003 now extends with `Configured by: none`. With that expectation updated, the test passes, so all 590 pass.
- `ki repo audit --repo .`: no failures; warnings are the pre-existing `size` migration-window notes, the `.rumdl.toml` template drift, the Claude Desktop definition note and the hooks-migration HOOK-1 note, none touched here.
- shellcheck, `bash -n` on every script, `scripts/assemble-rig --check`, `scripts/benchmark-rig`, `scripts/smoke-native-providers`, `mandoc -T lint man/rig.1` and `git diff --check`: pass.

### Outstanding concerns

The new suite exercises settings and services directly; default applications are covered by the existing `tool=editor` explanation test, while firewalls and scheduled jobs share the same parse path without a dedicated case. The rig.midnight.ninja site shows nothing until the chezmoi repository adds `tool` to Kris's declarations, which is outside this record.

### Post-change review

The goal holds: a consumer reads "configured on this host" per profile from `configured_by`, and `requires`-only links, ports and Dock filters stay out, as planned. Public export is byte-identical with and without links. Regression risk is low: profiles without links render exactly as before, and the derived `requires` entry reuses existing validation and closure. Ready for acceptance review.

### Mini recap

Added an explicit subject link and reported it in `rig show` JSON, table and explanation, with a new RIG-QUERY-009 clause. Learning route, not promoted: storing the subject apart from `requires` let the explanation keep one `tool=` line for default applications while the link reuses prerequisite closure unchanged.

## Discussion

### Approval

Kris, 19 October 2026 (TRIAGE-ALL, relayed by the mac-studio-setup State of play): every high-confidence Now recommendation is adopted and delivered to Awaiting review, tools burn-down work first. The rig-triage run of 19 October 2026 recommended this record for Now with high confidence: Kris had already chosen its shape (SITE-CONFIG-SHAPE a) and the rig.midnight.ninja site waits on it. Planning settled the record's open questions as recorded under Planning decisions.

### Origin

Alternatives the design note weighed and set aside: deriving the flag from `requires` (wrong on the only live example), from a preference domain matching an application bundle identifier (needs declared bundle identities and covers no service or job; possible later sugar), a tool-side `configures` list (splits one fact across two tables), and the Dock-item filter meaning (would make configuration divergence a pure echo of tool divergence). The handoff's plain `configured: true|false` was the other option Kris did not take; the list keeps each flag auditable. Today's declared data gives the same answer on terra and sol for every tool, so the site's columns stay identical until Kris declares genuinely host-specific configuration. Planning should settle whether `[port.*]`, whose `owner = "tool:ID"` already names a tool, and Dock layouts should count as configuring resources. Capture only; adoption, priority and plan belong to this repository.
