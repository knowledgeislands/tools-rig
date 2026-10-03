# Release Rig

Rig owns its release artifacts and version. The Homebrew tap owns formula distribution, while the Knowledge Islands website owns the public tool-registry and stable installer routes. Those downstream systems consume an already published exact Rig version; they are not release authority.

The `ki-repo-tools` release-readiness checklist owns the common release review; this guide supplies Rig's exact candidate, installation, and downstream steps.

Expected public routes are:

- `https://knowledgeislands.info/projects/rig/` for people;
- `https://knowledgeislands.info/install/rig` for installers.

## Prepare a local development candidate

Keep the authored runtime version at the latest release plus `+dev` until an exact next preview is explicitly selected. Keep the changelog's consolidated Pre-1.0 baseline current with the development checkout; do not add a dated 0.x section. The development marker distinguishes the linked checkout from the latest immutable release without promising a version.

Release-facing documentation must distinguish these two paths:

- the README, getting-started guide, and manual identify the latest immutable release and use its immutable installer URL;
- a contributor links the current checkout with `./install.sh --link`, and that executable reports the matching development version.

Before proposing an exact version, review the complete diff from the latest immutable tag and run the complete repository gate. Verify a disposable linked installation, the release-installer fixture, staged apply-prerequisite tests, bounded native-provider smoke, and an offline public export. This produces local evidence only: it does not select a version or authorise a tag, push, GitHub release, tap update, website deployment, personal apply, or any other external mutation.

After an exact preview version is explicitly selected:

1. Replace the development marker with `X.Y.Z` in `src/rig/00-runtime.bash` and assemble `bin/rig`.
2. Refresh the consolidated Pre-1.0 command and behaviour baseline in `CHANGELOG.md` against the exact candidate. The tag and GitHub release retain the per-preview record; from 1.0 onward, use dated changelog entries.
3. Update immutable installer examples and downstream handoff details to that exact version.
4. Re-run every local candidate and repository check before requesting publication authority.

## Complete the pre-release checklist

- [ ] Complete the [definition of done](definition-of-done.md).
- [ ] Compare `bin/rig`, top-level and command-local help, README orientation, user guides, `man/rig.1`, generated Bash and Zsh completions, `CHANGELOG.md`, Specifications, and Decision Records.
- [ ] Read the affected guidance as a user: confirm the journey has a recognisable outcome, introduces concepts incrementally, uses copyable examples, and remains clear with realistic configuration.
- [ ] Confirm examples agree on the declarative schema, implicit built-in providers, init, show, status, capture, apply, upgrade, doctor and export boundaries, managed-resource kinds, extension boundary, and changed command synopsis.
- [ ] While no exact release is selected, confirm the authored and assembled runtime report the same development marker and every immutable install example still names the latest released tag.
- [ ] After explicit version selection, update `RIG_VERSION` in `src/rig/00-runtime.bash`, assemble `bin/rig`, and confirm the drift check, `rig --version`, consolidated Pre-1.0 baseline, intended `vX.Y.Z` tag, installer examples, and Homebrew formula handoff all agree. From 1.0 onward, also confirm the dated changelog entry.
- [ ] Verify a disposable `./install.sh --link` installation includes working executable and manual links, then exercise the isolated release-installer fixture.
- [ ] Run staged apply-prerequisite tests, bounded native-provider smoke, and an offline public export.
- [ ] Run the complete verification gate in [Develop Rig](README.md), including public command-inventory alignment tests and rendered manual inspection.
- [ ] Inspect the committed release-candidate diff, exclude unrelated working-tree changes, and record anything deliberately deferred.
- [ ] Obtain explicit authority before any external mutation by the local agent: tag creation, push, GitHub release publication, manual formula update, or manual consumer handoff. Authorised release-event automation follows the receiving repository's own checks.

## Publish the release

Confirm GitHub release immutability is enabled for this repository before publication. The setting protects only newly created releases; it does not retroactively make older releases immutable. Verify GitHub reports this exact new release as immutable before handing it to an immutable-only receiver.

1. Commit the verified candidate on `main`, push that exact ref, and wait for its Linux, macOS, ShellCheck and manual CI jobs to pass. Do not tag a candidate whose branch checks failed.
2. Create and push the annotated `vX.Y.Z` tag at that exact commit. Wait for tag CI, including the tag/version match job, before publishing the GitHub release. Never move a published tag to repair a failed candidate.
3. Publish the GitHub release with migration notes for the breaking command and configuration changes.
4. Verify the immutable installer in disposable executable and manual directories before changing any recommendation:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh | bash -s -- vX.Y.Z
   ```

5. Confirm `rig --version` and `man rig` from the disposable installed release. After publication, return the development checkout to the released version plus `+dev` in a separate change; keep immutable installer examples on the published tag.

Do not repair a published release in place. Correct the repository, verify another candidate, and publish a new version.

## Complete downstream distribution

Hand the exact released version and immutable installer URL to `knowledgeislands/homebrew-tap` through the enrolled release-event path. The tap validates and advances its formula, then dispatches its verified update to enrolled consumers. Confirm the formula reaches the tap's default branch and the website pull request passes its checks and reaches its intended disposition; dispatch alone does not prove the public entry advanced.

A first-time website entry, maturity change, or consumer not enrolled in automation remains an explicit receiver-owned handoff. Carry:

- the exact `vX.Y.Z` version;
- `https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh` as the immutable installer target;
- the expected `/projects/rig/` and `/install/rig` routes.

Rig stores no shared release credentials and does not duplicate the tap or website's own verification.
