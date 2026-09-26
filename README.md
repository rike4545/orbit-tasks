# Orbit Tasks

Orbit Tasks is a SwiftUI productivity app focused on fast task capture, planning, review, smart lists, natural-language date parsing, reminders, attachments, localization, and focused execution.

## Project shape

- **Platform:** iPhone / iOS
- **UI:** SwiftUI
- **Dependency management:** Swift Package Manager through the Xcode project
- **Current external package:** Google Mobile Ads
- **Tests:** Swift Testing unit tests plus an XCUITest target
- **Localization:** English, German, Spanish, French, Dutch, Brazilian Portuguese, Japanese, Simplified Chinese, and Traditional Chinese

## Local development

Open `Orbit Tasks.xcodeproj` in Xcode and use the shared **Orbit Tasks** scheme.

From Terminal:

```bash
xcodebuild   -project "Orbit Tasks.xcodeproj"   -scheme "Orbit Tasks"   -sdk iphonesimulator   -destination "generic/platform=iOS Simulator"   CODE_SIGNING_ALLOWED=NO   build
```

## Automated quality loop

This repository is configured to maintain itself conservatively:

1. **CI** builds the app and runs the unit tests for every pull request and every push to `main`.
2. **Dependabot** checks SwiftPM and GitHub Actions dependencies weekly.
3. Dependency automation is intentionally limited to **patch releases**.
4. A Dependabot patch PR is merged automatically only after CI succeeds and only when its changed files are limited to known dependency/workflow files.
5. **Autonomous Maintenance** runs weekly, applies `swift-format` to tracked Swift source, rebuilds the project, runs unit tests, and automatically opens and merges the formatting PR only after validation succeeds.

The automation is deliberately conservative: semantic feature work, major/minor dependency upgrades, and unexpected dependency-file changes are not auto-merged.

## Improvement priorities

The next high-value engineering areas are:

- Expand unit coverage beyond natural-language date parsing into task completion, recurrence, planning, and date-boundary behavior.
- Add deterministic UI smoke tests for launch, inbox capture, completion, search, and settings.
- Move large feature files toward smaller feature-focused views/models to reduce change risk.
- Add accessibility assertions and localization coverage to CI.
- Add performance baselines for task-list rendering and attachment indexing.
- Introduce release validation for privacy strings, entitlements, App Store metadata, and dependency license changes.
