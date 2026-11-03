# Contributing

Thanks for helping improve EscClose.

## Development setup

Requirements:

- macOS 12+
- Xcode Command Line Tools (`xcode-select --install`)

Build the app:

```bash
make build
open dist/EscClose.app
```

Clean build artifacts:

```bash
make clean
```

## Architecture

- `Sources/EscClose/EscClose.swift` contains the menu bar app, event tap, permission handling, diagnostics, and Accessibility actions.
- `Resources/Info.plist` defines the app bundle and minimum OS version.
- `scripts/build.sh` produces a universal Intel + Apple Silicon app.
- `scripts/make_icon.swift` generates the app icon.

EscClose intentionally uses public macOS APIs only. Do not add dynamic library injection, private WeChat APIs, or code-signing bypasses.

## Testing

Because the app depends on macOS permissions and another GUI application, testing is currently manual:

1. Build and launch the app.
2. Grant Accessibility permission.
3. Open WeChat and make it frontmost.
4. Press `Esc`; the current window should close and WeChat should stay running.
5. Verify that `Esc` still works normally in other apps.
6. Use “打开诊断日志” if the behavior is different from expected.

Please report the macOS version, WeChat version, and Mac architecture when submitting compatibility fixes.

## Pull requests

- Keep changes focused and explain the user-facing behavior.
- Update `CHANGELOG.md` for meaningful changes.
- Update the compatibility table in the README when testing a new version.
- Avoid adding network access or telemetry.
- Include reproduction steps and test evidence for window-control changes.

## Commit messages

Conventional commit prefixes are welcome but not required, for example:

```text
fix: keep Esc working when WeChat has no focused window
docs: add macOS 14 compatibility result
feat: allow selecting another target application
```
