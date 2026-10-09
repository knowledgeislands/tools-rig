# Release Rig

The `ki-repo-tools` release-readiness checklist owns the common release review; this guide supplies Rig's exact candidate, installation, and downstream steps.

## When to release

Release timing follows the `ki-repo-tools` [release-on-demand policy](https://github.com/knowledgeislands/ki-agentic-harness/blob/main/skills/repo-structure/ki-repo-tools/references/standards-release-readiness.md#release-on-demand): hold releases by default and do not release after each change, and close delivered work without waiting for a release. The steps below apply only once a release is due under that policy.

Expected public routes are:

- `https://knowledgeislands.info/projects/rig/` for people;
- `https://knowledgeislands.info/install/rig` for installers.

## Prepare a local development candidate

Keep the authored runtime version at the latest release plus `+dev` until an exact next preview is selected. Apply the shared changelog policy to the development checkout. The development marker distinguishes the linked checkout from the latest immutable release without promising a version.

Release-facing documentation must distinguish these two paths:

- the README, getting-started guide, and manual identify the latest immutable release and use its immutable installer URL;
- a contributor links the current checkout with `./install.sh --link`, and that executable reports the matching development version.

For an explicitly selected, unpublished candidate, the examples may already name its exact tag, but must say that remote installation is available only after publication and identify the latest published release. The current candidate is `v0.5.0`; the latest published release is `v0.4.0`. Link the checkout to exercise the candidate, and do not describe it as the latest immutable release until that release exists.

Before proposing an exact version, verify a disposable linked installation, the release-installer fixture, staged apply-prerequisite tests, bounded native-provider smoke, and an offline public export alongside the complete repository gate.

After an exact preview version is explicitly selected:

1. Replace the development marker with `X.Y.Z` in `src/rig/00-runtime.bash` and assemble `bin/rig`.
2. Update `CHANGELOG.md` under the shared release-readiness checklist's version-phase policy.
3. Update immutable installer examples and downstream handoff details to that exact version. Identify the candidate as unpublished until its GitHub release is actually published.
4. Re-run the local candidate and repository checks against the exact version.

## Complete the pre-release checklist

- [ ] Complete the [definition of done](definition-of-done.md).
- [ ] Complete the shared release-readiness checklist, checking Rig's implicit provider, resource and public-export boundaries in its examples.
- [ ] While no exact release is selected, confirm the authored and assembled runtime report the same development marker and every immutable install example still names the latest released tag.
- [ ] After version selection, update `RIG_VERSION` in `src/rig/00-runtime.bash`, assemble `bin/rig`, and confirm the assembly drift check and `rig --version` against the selected version.
- [ ] Verify a disposable `./install.sh --link` installation includes working executable and manual links, then exercise the isolated release-installer fixture.
- [ ] Run staged apply-prerequisite tests, bounded native-provider smoke, and an offline public export.
- [ ] Run the complete verification gate in [Develop Rig](README.md), including public command-inventory alignment tests and rendered manual inspection.

## Publish the release

1. Commit the verified candidate on `main`, push that exact ref, and wait for its Linux, macOS, ShellCheck and manual CI jobs to pass. Do not tag a candidate whose branch checks failed.
2. Create and push the annotated `vX.Y.Z` tag at that exact commit. Wait for tag CI, including the tag/version match job, before publishing the GitHub release.
3. Publish the GitHub release with migration notes for the breaking command and configuration changes. Confirm GitHub marks that exact release immutable before using it as downstream distribution evidence.
4. Verify the immutable installer in disposable executable and manual directories before changing any recommendation:

   ```sh
   rig_release_check=$(mktemp -d)
   curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh | \
     RIG_INSTALL_DIR="$rig_release_check/bin" RIG_MAN_INSTALL_DIR="$rig_release_check/man/man1" \
     bash -s -- vX.Y.Z
   "$rig_release_check/bin/rig" --version
   MANPATH="$rig_release_check/man" man rig
   ```

5. After publication, return the development checkout to the released version plus `+dev` in a separate change; keep immutable installer examples on the published tag. Remove the unpublished-candidate notices from the README, getting-started guide and manual only after checking publication and the immutable installer.

## Complete downstream distribution

Follow the shared release-readiness checklist's tap and website handoff procedure. Rig's handoff carries:

- the exact `vX.Y.Z` version;
- `https://raw.githubusercontent.com/knowledgeislands/tools-rig/vX.Y.Z/install.sh` as the immutable installer target;
- the expected `/projects/rig/` and `/install/rig` routes.

Publishing the GitHub release triggers the `Notify Homebrew tap` workflow, which sends a `tool-release-published` dispatch to `knowledgeislands/homebrew-tap` through the `ki-tools-release-bot` GitHub App; the tap then opens the exact formula pull request and squash-merges it automatically once its required checks pass. The job is skipped until the `KI_TOOLS_RELEASE_BOT_APP_ID` variable and `KI_TOOLS_RELEASE_BOT_PRIVATE_KEY` secret are available to this repository at organisation or repository level (not as `release`-environment secrets); the tap's daily scheduled intake still picks up a published immutable release without the dispatch.
