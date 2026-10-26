# Contributing to Shapeshift

Thanks for taking an interest. Bug reports, ideas and pull requests are all welcome.

## Before you start

- For a bug, open an issue with the bug report template. Include your macOS version, the file type involved and whether ffmpeg is installed.
- For a larger change or a new feature, open an issue first so we can agree on the direction before you spend time on it.
- Small fixes (typos, docs, an obvious bug) can go straight to a pull request.

## Setting up

Requirements: an Apple Silicon Mac, macOS 13 or later, and Xcode with the Swift 6 toolchain. Building the Liquid Glass code needs the macOS 26 SDK. Audio and video conversion needs [ffmpeg](https://ffmpeg.org) (`brew install ffmpeg`).

```sh
git clone https://github.com/Jacobberggreen/Shapeshift.git
cd Shapeshift
swift build
swift test
```

To build the app bundle or the disk image, see [Build from source](README.md#build-from-source-for-developers) in the README. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) explains how the targets fit together.

## Making a change

1. Fork the repository and create a branch from `main` with a short, descriptive name (`fix-gif-size-estimate`, `docs-faq`).
2. Keep each pull request to one logical change.
3. Add or update tests. Core logic lives in `ConversionCore` and `EditCore` and should be covered by XCTest; mirror the source layout under `Tests/`.
4. Run `swift test` and make sure it passes. CI runs the same command on every pull request.
5. If your change touches windows, drag and drop, Finder or appearance, work through the matching section of [docs/manual-test-checklist.md](docs/manual-test-checklist.md), since automated tests cannot cover those.
6. Update [CHANGELOG.md](CHANGELOG.md) under *Unreleased* when the change is visible to users.
7. Open a pull request against `main` and fill in the template.

## Ground rules

- **The original file is never modified.** Output goes to a new sibling file, written to a temporary file first and moved into place on success. Nothing is overwritten.
- **Everything runs locally.** No uploads, accounts or telemetry.
- Match the style of the surrounding code: naming, comment density and idiom.
- Commit messages are short and in the imperative mood ("Fix GIF size estimate").

## Conduct

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Licence

Contributions are released under the project's [MIT licence](LICENSE).
