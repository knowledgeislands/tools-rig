# How Rig coordinates native tooling

Use this guide when changing provider orchestration or explaining which part of a working setup Rig actually owns. [Explore the interactive architecture diagram](architecture/rig-manager-of-managers.html) for the read and write paths; the [Archify source](architecture/rig-manager-of-managers.json) keeps its source references beside the generated, self-contained HTML so the view can be reused by a documentation consumer.

Rig configuration declares the catalogue, selected profile, and desired tools and resources. Rig parses that data, resolves provider bindings, checks capabilities, and orders tool dependencies before either observing or changing the machine. The selected profile changes _which_ declarations participate; it does not turn a native manager into a second source of package-selection intent.

`rig status` and `rig doctor` follow the observation path. Rig asks native providers about installed tools and managed resources, compares their answers with the selected declarations, and reports missing, present, drifted, or blocked outcomes. The report is Rig's interpretation of observations, not a new installation database.

`rig apply` and `rig upgrade` follow explicit mutation paths. Rig selects and sequences the allowed actions, then invokes Homebrew, uv, mise, npm, ChezMoi, download tools, or macOS facilities through their bounded adapters. Those systems retain their own resolution rules, credentials, source data, and operating state. In particular, ChezMoi still owns its source files and templates; Rig may request application of a declared target but does not replace ChezMoi or use a Brewfile.

Public export is a separate, deliberately selected projection of the catalogue. It is derived from private configuration for a consuming site, not an authority for private declarations or machine state. The diagram concentrates on reconciliation because that is where Rig's manager-of-managers boundary matters most.

The authored JSON and generated HTML should change together. When the implementation changes a depicted relationship, update the JSON's pinned repository revision and source ranges from the committed code, regenerate it with Archify `finalize` against this repository, and inspect the result in light and dark themes. Do not treat a passing layout gate as proof that the architectural claim is still true.
