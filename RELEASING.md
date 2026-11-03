# Releasing

## Build

```bash
make clean
make build
```

The universal app and zip are written to `dist/`.

## Signing

For a public release, use an Apple Developer ID Application certificate:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make build
```

Ad-hoc signing (`codesign --sign -`) is used automatically when no identity is supplied. Ad-hoc builds work locally, but macOS may invalidate Accessibility permission after the binary changes and Gatekeeper cannot verify the app.

## Notarization

After signing, submit and staple the app:

```bash
ditto -c -k --keepParent dist/EscClose.app dist/notarization.zip
xcrun notarytool submit dist/notarization.zip \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait
xcrun stapler staple dist/EscClose.app
```

Rebuild the release zip after stapling.

## GitHub release

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Update `CHANGELOG.md`.
3. Commit the release changes.
4. Push a tag matching the workflow pattern:

```bash
git tag v1.1.0
git push origin main --tags
```

The GitHub Actions workflow builds the universal zip and publishes a GitHub Release for tags beginning with `v`.
