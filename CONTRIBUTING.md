# Contributing to ManotApp

Thank you for your interest in contributing!

## Before You Start

- Check [existing issues](../../issues) to avoid duplicating work
- For significant changes, open an issue first to discuss the approach
- All contributions are released under the [MIT License](LICENSE)

## Setup

Follow the [Getting Started](README.md#getting-started) steps in the README. In particular, copy `Configuration/Signing.xcconfig.template` to `Configuration/Signing.xcconfig` and add your own Team ID before building.

## Pull Requests

1. Fork the repository and create a feature branch from `main`
2. Keep changes focused — one feature or fix per PR
3. Test on macOS 14 Sonoma or later
4. Ensure the project builds without warnings (`⌘B` in Xcode)
5. Write a clear PR description explaining *what* changed and *why*

## Swift Style

- Swift 6 strict concurrency is enforced — all code must compile with `.swiftLanguageMode(.v6)`
- Prefer `@MainActor` for UI-touching code over manually dispatching to the main queue
- Use `@Observable` (Observation framework) rather than `ObservableObject`/`@Published`
- Keep views small and focused; extract subviews rather than growing a single body

## What to Contribute

Good first areas:

- Bug fixes with a clear reproduction case
- Improved Markdown rendering edge cases
- Accessibility (VoiceOver support)
- Additional export formats

## App Store Distribution

The App Store version is published by the project author under a separate Apple Developer account. Open-source contributors do not need an Apple Developer account to build and run the app locally.
