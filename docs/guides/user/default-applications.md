# Declare default applications

Default applications are private macOS resources that say which catalogue application opens a content type or URL scheme. Declare the owning tool and its application artifact first; this fictional example documents an app installed through its own chosen native provider:

```toml
[tool.editor]
name = "Editor"
category = "applications"
purpose = "Edit notes"
rationale = "Use one editor for this context"
platforms = ["macos"]
artifacts = ["~/Applications/Editor.app"]

[default-application.notes]
name = "Notes handler"
purpose = "Open notes in the chosen editor"
rationale = "Keep the profile's choice consistent"
provider = "macos-handlers"
tool = "editor"
bundle-id = "org.example.Editor"
kind = "extension"
value = ".note"
platforms = ["macos"]
profiles = ["default"]
```

Declare the referenced category and profile normally. Replace the fictional path, bundle identifier and selector with the application you chose; add its installation metadata when Rig should install it. The first selected declared `.app` artifact must be healthy and its Info.plist bundle identifier must match. A catalogue-only app can satisfy this through the artifact without an installer. A failed declared installer blocks its handler.

Use `kind = "uti"` with a content-type identifier, `kind = "extension"` with a lowercase extension and optional leading dot, or `kind = "scheme"` with a lowercase URL scheme without its colon. File types use all roles. Declare a native type once through its UTI or extension; these can name the same underlying native type. Duplicate selected kind/value targets, including `.note` and `note`, are rejected. Per-file Finder overrides are outside this declaration.

The example uses item profile membership. In a configuration using central profile members, omit item `profiles` and select `default-applications = ["notes"]` in the profile. Rig includes the application tool prerequisite automatically. Existing inheritance rules apply; never mix the two membership styles.

## Inspect before assigning

`rig show default-application:notes` describes intent offline. `rig doctor` and `rig status` check the selected app and current handler without registering or assigning it. Absence, damage, bundle mismatch, unavailable native tools and handler drift remain visible. A declaration selected on Linux is unsupported and invokes no native handler operation.

Preview with `rig apply --dry-run`. Apply the selected resource with `rig apply --target default-application:notes`, or use normal apply. Tools run first. A correct handler is a no-op; a changed handler registers the verified app, makes the native assignment and checks the effective result. An error or an ineffective assignment fails the resource. macOS may require confirmation for some schemes; Rig does not bypass it or falsely claim success while the observed choice still differs.

## Keep native ownership

The built-in adapter uses existing macOS osascript/plutil and Launch Services. It needs no duti installation or runtime SDK. Native permissions and consent policies remain in force. `RIG_OSASCRIPT` and `RIG_PLUTIL` select adapter executables for controlled fixtures or an explicitly chosen native executable.

Handler choices stay private in exported views, even when their tool is public. Deselection does not reset a handler, retire the resource or remove either application. Rig adds no automatic restoration of previous handlers. The previous application's removal and retained data are separate explicit decisions.
