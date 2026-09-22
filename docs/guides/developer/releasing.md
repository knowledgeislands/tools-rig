# Release Rig

Rig owns its release artifacts and version. The Homebrew tap owns formula distribution, while the Knowledge Islands website owns the public tool-registry and stable installer routes. Those downstream systems consume an already published exact Rig version; they are not release authority.

Expected public routes are:

- `https://knowledgeislands.info/tooling/rig/` for people;
- `https://knowledgeislands.info/install/rig` for installers.

## Complete the pre-release checklist

- [ ] Complete the [definition of done](definition-of-done.md).
- [ ] Compare `bin/rig`, top-level and command-local help, README orientation, user guides, `man/rig.1`, generated Bash and Zsh completions, `CHANGELOG.md`, Specifications, and Decision Records.
- [ ] Confirm examples agree on the declarative schema, implicit built-in providers, native apply, bootstrap, update, maintenance, capture, and cleanup lifecycles, managed-resource kinds, extension boundary, and changed command synopsis.
- [ ] Update `RIG_VERSION` in `src/rig/00-runtime.bash`, assemble `bin/rig`, and confirm the drift check, `rig --version`, changelog release entry, intended `vX.Y.Z` tag, installer examples, and Homebrew formula handoff all agree.
- [ ] Run the complete verification gate in [Develop Rig](README.md), including public command-inventory alignment tests and rendered manual inspection.
- [ ] Inspect the committed release-candidate diff, exclude unrelated working-tree changes, and record anything deliberately deferred.
- [ ] Obtain explicit authority before any external mutation: tag creation, push, GitHub release publication, formula update, or manual consumer handoff.

## Publish the release

1. Create the annotated `vX.Y.Z` tag and GitHub release for the verified commit according to the repository release workflow.
2. Verify the immutable installer before changing any recommendation:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh | bash -s -- vX.Y.Z
   ```

3. Confirm `rig --version` and `man rig` from the installed release.

Do not repair a published release in place. Correct the repository, verify another candidate, and publish a new version.

## Complete downstream distribution

Send the exact released version and immutable installer URL to `knowledgeislands/homebrew-tap`. Release-event automation can update explicitly enrolled consumers. The Knowledge Islands website advances its existing Rig entry through the website's normal reviewed workflow.

A first-time website entry, maturity change, or consumer not enrolled in automation remains an explicit receiver-owned handoff. Carry:

- the exact `vX.Y.Z` version;
- `https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh` as the immutable installer target;
- the expected `/tooling/rig/` and `/install/rig` routes.

Rig stores no shared release credentials and does not duplicate the tap or website's own verification.
