# Release Rig

Rig owns its release artifacts and version. The Knowledge Islands website owns the public tool registry and stable routes that recommend one released version:

- `https://knowledgeislands.info/tooling/rig/` for people;
- `https://knowledgeislands.info/install/rig` for installers.

Those routes are an indirection layer, not release authority. A website handoff must name an already published exact Rig version and its immutable installer URL.

## Pre-release checklist

- [ ] Complete the repository [definition of done](definition-of-done.md), including the single public-surface alignment check.
- [ ] Confirm `bin/rig` help and command-local help, README, user and developer guides, `man/rig.1`, Bash and Zsh completions, `CHANGELOG.md`, tests, Specifications, and Decision Records describe the same release candidate.
- [ ] Confirm the intended version agrees across the `bin/rig` version source, `rig --version`, changelog release entry, intended `vX.Y.Z` tag, installer examples, and companion Homebrew formula handoff.
- [ ] Run the complete verification gate in the [developer guide](README.md), including the public command-inventory alignment test and manual rendering check.
- [ ] Inspect the release diff and committed candidate. Exclude unrelated working-tree changes and record anything deliberately deferred.
- [ ] Obtain explicit authority for each external mutation: tag creation, push, GitHub release publication, formula update, and website recommendation handoff.

## Publish the release

1. Create the annotated `vX.Y.Z` tag and GitHub release from the verified commit according to the repository release workflow.
2. Verify immutable artifacts before changing any recommendation:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh | bash -s -- vX.Y.Z
   rig --version
   man rig
   ```

3. Confirm a fresh released installation reports the tagged version and exposes the shipped manual and completion command.

## Hand off the recommendation

After the release is published, create a canonical work item in `knowledgeislands/ki-website` through that repository's selected KI workflow. The item must carry:

- the exact `vX.Y.Z` version;
- `https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh` as the immutable installer target;
- the expected `/tooling/rig/` product page and `/install/rig` stable endpoint;
- verification that both routes advertise and resolve the same version.

Do not make Rig's build depend on the receiving website. A missed or delayed handoff is recommendation drift to report explicitly, not a reason to rewrite release history or transfer publication authority.
