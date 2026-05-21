# Clipy

- This repo is a native macOS Swift app, not a Flutter project despite the parent folder name.
- Use `Clipy.xcworkspace`, not `Clipy.xcodeproj`; CocoaPods dependencies and CI are wired through the workspace.

## Setup And Verification

- Bootstrap exactly as CI does: `bundle install --path=vendor/bundle && bundle exec pod install`.
- CI test path is `bundle exec fastlane test`, which runs `scan` against workspace `Clipy.xcworkspace` and scheme `Clipy`.
- Focused test runs should use Xcode's workspace/scheme form, for example: `xcodebuild test -workspace Clipy.xcworkspace -scheme Clipy -only-testing:ClipyTests/HotKeyServiceSpec`.
- Danger lint uses the vendored binary: `./Pods/SwiftLint/swiftlint lint --config .swiftlint.yml`.

## Release Process

- Update the app version before tagging and packaging.
- Create a new git tag for the release version before packaging, for example `git tag v2.0.1`.
- Build the release app with `xcodebuild -workspace Clipy.xcworkspace -scheme Clipy -configuration Release -derivedDataPath build/DerivedData ENABLE_TESTABILITY=YES build`, then package `build/DerivedData/Build/Products/Release/Clipy.app`.
- Ensure the shared `Clipy` scheme does not build `ClipyTests` for running, and verify the packaged `Clipy.app` does not contain `ClipyTests.xctest`, `PlugIns`, or `XCTest*` frameworks before publishing.
- Sparkle is used only for update checking. After uploading the release asset, update `appcast.xml` to the new version and point its `<link>` at the exact ZIP asset URL.
- Push the `appcast.xml` update to the feed branch after the GitHub release asset is uploaded, otherwise the in-app updater will continue advertising the previous version.
- Commit the source changes and push both the branch and the tag to `origin`.
- Use `gh release create` to publish the GitHub release and upload the packaged artifact.
- After publishing, clean local outputs with `rm -rf dist build` and always remove Xcode build outputs for this project with `rm -rf ~/Library/Developer/Xcode/DerivedData/Clipy-*`.

## Generated And Scripted Files

- Do not hand-edit `Clipy/Generated/AssetsImages.swift`, `Clipy/Generated/Colors.swift`, or `Clipy/Generated/LocalizedStrings.swift`; they are generated from `swiftgen.yml`.
- Xcode has build phases for `SwiftGen`, `BartyCrouch`, and `SwiftLint`. If you change assets, `Localizable.strings`, or `Clipy/Resources/colors.txt`, regenerate via the workspace build or `./Pods/SwiftGen/bin/swiftgen`.
- `pod install` matters before opening/building: the project contains CocoaPods script phases that fail when `Pods/Manifest.lock` is out of sync with `Podfile.lock`.

## Codebase Wiring

- App startup is centered in `Clipy/Sources/AppDelegate.swift`; it initializes Realm migration, replaces `AppEnvironment.current`, binds observers, starts services, then sets up the menu manager.
- `Clipy/Sources/Environments/AppEnvironment.swift` is the service locator used across the app. Prefer threading changes through `Environment`/`AppEnvironment` instead of introducing new globals.
- Persistent model changes usually require a matching Realm schema migration in `Clipy/Sources/Extensions/Realm+Migration.swift`.

## Tests And Conventions

- Tests live in `ClipyTests` and use Quick/Nimble (`*Spec.swift`), not XCTest-style naming.
- Existing specs mutate `UserDefaults.standard`; keep tests isolated by cleaning keys they touch, following the current `beforeEach`/`afterEach` pattern.
- SwiftLint only includes `Clipy/Sources` and `ClipyTests`; changes outside those paths will not be linted by the repo config.
