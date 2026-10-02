# Review a retired application's traces

Use this report after you have deliberately retired a macOS application and want to review what remains. It observes evidence; it neither uninstalls the application nor decides whether retained data should be deleted.

## Declare the identity and known locations

Add a separate retired declaration to `rig.toml` or a `conf.d/*.toml` fragment. For example, using a synthetic application:

```toml
[retired-application.old-notes]
name = "Old Notes"
bundle-id = "org.example.old-notes"
application-paths = ["/Applications/Old Notes.app"]
data-paths = ["~/Library/Application Support/Old Notes"]
package-paths = ["/opt/homebrew/Caskroom/old-notes"]
```

Replace the example with an exact bundle identifier and locations you have evidence for. `name`, `bundle-id` and a non-empty `application-paths` array are required. The data and package arrays are optional. Declaring a package path records your association, not proof that a package manager currently owns it. Do not classify a directory as application-owned merely because its name looks similar.

Paths are literal absolute paths or begin with `~/` or `$HOME/`. They are not shell expressions or glob patterns. Dot and parent traversal components are rejected. Observation does not follow symlinks, even in parent directories or the bundle's metadata path. Use a physical path when an alias such as `/tmp` would otherwise cross a link.

A retired declaration is not a tool, installation or profile member. Remove any obsolete active installation intent separately through your normal configuration review: adding this declaration does not override an existing tool declaration or prevent an independently declared tool from being installed.

## Inspect the evidence

```sh
rig status --retired
rig status --retired --format json
```

Retired evidence covers all retired declarations in the loaded configuration. `--profile` still selects the ordinary machine comparison; it does not filter the retired section. `--problems` does not suppress the retired evidence you explicitly requested. Without `--retired`, status neither probes these locations nor adds the report.

For each declared application path, Rig reads only the bundle identity needed for an exact match. A different bundle at that location is reported as mismatched. Missing, inaccessible, symbolic-link and unavailable evidence are distinct. The permission check catches ordinary unsearchable directories, but macOS privacy controls, unusual access rules or a concurrent path change can make a failed existence check look like a missing path; review uncertain cases directly before drawing a conclusion. On other platforms, observation is unavailable and no macOS probe runs.

Alongside your explicit data paths, Rig checks exact bundle-ID candidates beneath your Library: Application Support, Caches, Preferences (`ID.plist`), Saved Application State (`ID.savedState`) and Containers. These are conventional candidate associations, not verified ownership and not an exhaustive search. Display-name guesses, group containers, shared stores and recursive directory contents are not scanned. Declared package paths stay separate from user-data candidates.

An exact matched bundle may have a last-used date from Spotlight. Apple's [last-used metadata documentation](https://developer.apple.com/documentation/coreservices/kmditemlastuseddate) describes LaunchServices openings, not a complete execution history. Treat the date as partial evidence. Missing, malformed or unavailable metadata does not mean never used; absence of an app also makes its bundle metadata unavailable. Rig never substitutes filesystem modification time for usage.

## Review without automatic cleanup

Retained files and incomplete retirement evidence do not change machine-health counts, doctor findings or status exit codes. An ordinary active-tool finding can still make the combined status command fail. Neither apply nor upgrade uses retired declarations, and public export excludes them entirely.

The JSON `retired_applications` array exists only when requested. Each entry identifies the retired declaration and contains evidence rows. Rows carry `kind`, `source`, `state`, the complete path in `detail`, and a fixed explanation in `reason`; application rows also carry `last_used` with its source and caveat. Local paths remain in the existing redaction fields rather than a new structured path field. The report is private evidence: review it before sharing.

Before any manual cleanup, establish actual ownership, whether another application shares the location, and whether you need a backup. No observation in this report is deletion approval. Keeping useful old data is a valid outcome. You may remove the retired declaration once you no longer need to observe it; that changes reporting only and leaves the files untouched.
