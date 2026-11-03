# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-11-03

### Fixed

- Capture `Esc` through a `CGEventTap` so the event can be observed even when WeChat or an input method would otherwise consume it.
- Keep a global keyboard monitor as a fallback.
- Prevent duplicate close actions when multiple monitors observe the same key.
- Close WeChat through its Accessibility close button, with `Command-W` as a fallback for custom window chrome.

### Added

- Local diagnostics log at `~/Library/Logs/EscClose.log`.
- “打开诊断日志” menu action.
- Permission recovery and event-tap re-enable handling.

## [1.0.0] - 2026-11-03

### Added

- Initial macOS menu bar app.
- Close the current WeChat window with `Esc` while WeChat is frontmost.
- Intel and Apple Silicon universal build.
- Accessibility permission onboarding.
