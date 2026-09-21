# Release Rig

Rig owns its release artifacts and version. The Homebrew tap owns formula distribution, while the Knowledge Islands website owns the public tool registry and stable routes that recommend one released version:

- `https://knowledgeislands.info/tooling/rig/` for people;
- `https://knowledgeislands.info/install/rig` for installers.

Those downstream surfaces are not release authority. They consume an already published exact Rig version and its immutable installer URL.

## Pre-release checklist

- [ ] Complete the [definition of done](definition-of-done.md).
- [ ] Compare the public surface across `bin/rig` top-level and command-local help, README, user guides, `man/rig.1`, generated Bash and Zsh completions, `CHANGELOG.md`, Specifications, and Decision Records.
- [ ] Confirm examples and reference material agree on the declarative schema, implicit built-in providers, native apply, bootstrap, update, maintenance, capture, and clean lifecycles, managed-resource kinds, external-provider boundary, and every changed command synopsis.
- [ ] Confirm the `bin/rig` version source, `rig --version`, changelog release entry, intended `vX.Y.Z` tag, installer examples, and companion Homebrew formula handoff agree.
- [ ] Run the complete verification gate in the [developer guide](README.md), including the public command-inventory alignment test and manual rendering check.
- [ ] Inspect the committed release diff and candidate. Exclude unrelated working-tree changes and record anything deliberately deferred.
- [ ] Obtain explicit authority for every external mutation: tag creation, push, GitHub release publication, formula update, and any manual consumer handoff.

## Publish the release

1. Create the annotated `vX.Y.Z` tag and GitHub release from the verified commit according to the repository release workflow.
2. Verify immutable artifacts before changing any recommendation:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh | bash -s -- vX.Y.Z
   rig --version
   man rig
   ```

3. Confirm a fresh released installation reports the tagged version and exposes the shipped manual and completion command.

## Complete downstream distribution

After the release is published, hand the exact tag to `knowledgeislands/homebrew-tap`. The tap owns the Rig formula, source checksum, installation checks, and formula tests; this repository neither edits nor decides the formula.

When the validated formula reaches the tap's default branch, the tap dispatches a verified tool-release event to explicitly enrolled consumers. An existing KI Website entry advances through the website's ordinary pull-request review. Rig stores no shared release-app credentials and does not duplicate tap or website verification.

A first-time website entry, maturity change, or consumer not enrolled in automation remains an explicit receiver-owned handoff. Carry:

- the exact `vX.Y.Z` version;
- `https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh` as the immutable installer target;
- the expected `/tooling/rig/` and `/install/rig` routes.
