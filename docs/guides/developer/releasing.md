# Release Rig

Rig owns its release artifacts and version. The Knowledge Islands website owns the public tool registry and stable routes that recommend one released version:

- `https://knowledgeislands.info/tooling/rig/` for people;
- `https://knowledgeislands.info/install/rig` for installers.

The website routes are an indirection layer, not release authority. A website handoff must name an already published exact Rig version and its immutable installer URL.

## Prepare the release

1. Complete the repository [definition of done](done.md), then confirm the intended version is represented in `bin/rig`, `CHANGELOG.md`, the manual, completion output, and README.
2. Run the complete repository verification gate from the [developer guide](README.md).
3. Review the release diff and obtain the authority required to tag, push, and publish. These are separate external mutations and are never implied by preparing repository changes.
4. Create the annotated `vX.Y.Z` tag and GitHub release from the verified commit according to the repository's release workflow.
5. Verify the immutable artifacts before changing any recommendation:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh | bash -s -- vX.Y.Z
   rig --version
   man rig
   ```

## Hand off the recommendation

After the release is published, create a canonical work item in `knowledgeislands/ki-website` through that repository's selected KI workflow. The item must carry:

- the exact `vX.Y.Z` version;
- `https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh` as the immutable installer target;
- the expected `/tooling/rig/` product page and `/install/rig` stable endpoint;
- verification that both routes advertise or resolve the same version.

Do not make the Rig build depend on the receiving website. A missed or delayed handoff is recommendation drift to report explicitly, not a reason to rewrite release history or transfer publication authority.

At the time this guide was introduced, the intended advertised release was `v0.1.0`. Verify the live routes during every handoff; do not treat this historical statement as current website state.
