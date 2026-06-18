# Restart Guide

## First Commands
From `/Users/appleadmin/Apps/ClipartBrowser`:

```sh
swift test
swift build
```

## Expected Workflow
1. Finish core implementation until the current tests pass.
2. Add the SwiftUI app target files.
3. Add a packaging script that creates `ClipartBrowser.app` from the SwiftPM build output.
4. Run unit tests.
5. Build the release executable.
6. Package and launch the app for a manual smoke test.

## Current Test Coverage Intent
- `VocabularyExtractorTests` checks vocabulary heading/list detection.
- `ImageTrimmerTests` checks removal of white borders.
- `PowerPointExporterTests` checks basic `.pptx` structure and letter portrait slide size.

## Packaging Target
The app bundle should use:

```text
ClipartBrowser.app/
  Contents/
    Info.plist
    MacOS/
      ClipartBrowser
```

Optional later additions:
- `Contents/Resources/AppIcon.icns`
- app signing
- notarization

