# Privacy

EscClose is designed to be a local-only utility.

## Data collection

EscClose does not collect, transmit, sell, or share personal data. It contains no analytics, telemetry, advertising, crash reporting, or network request code.

## Permissions

EscClose requests macOS Accessibility permission because it needs to:

- observe the global `Esc` key event;
- identify the frontmost application;
- invoke the close action on the WeChat window.

The event tap ignores every key except `Esc`. It does not record typed characters, clipboard data, chat messages, contacts, files, or screen contents.

## Local diagnostics

EscClose writes a local diagnostics log to:

```text
~/Library/Logs/EscClose.log
```

The log can contain:

- app launch and shutdown events;
- whether Accessibility permission is available;
- whether the keyboard event tap was installed;
- whether an `Esc` press was accepted and which app was frontmost;
- whether the Accessibility close action or Command-W fallback completed.

The log does not contain typed text or chat content. It is stored only on the local Mac, is capped at approximately 512 KB, and is cleared when it exceeds that size.

## Third parties

EscClose does not use third-party SDKs, libraries, or services.

## Contact

For privacy questions, open an issue in this repository.
