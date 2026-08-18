# PaperMon Release Process

PaperMon supports a local packaging check and a production Developer ID workflow. Production distribution requires an Apple Developer Program account, a **Developer ID Application** certificate in the login keychain, and notarization credentials stored in a keychain profile.

## 1. Validate packaging locally

This creates an ad-hoc signed universal app and DMG. It verifies the release build, bundle structure, entitlements, strict signature validation, and disk-image creation without using release credentials.

```sh
./script/package_release.sh --ad-hoc --version 0.1.0 --build 1
```

The artifacts are written to `dist/release/`. Ad-hoc artifacts are only for local validation and must not be distributed.

## 2. Configure notarization credentials

Store credentials once using Apple's interactive keychain flow. Do not put the Apple ID password, app-specific password, API key, or private key in this repository.

```sh
xcrun notarytool store-credentials "PaperMon-Notary"
```

Follow the prompts for either App Store Connect API credentials or Apple ID credentials. The resulting keychain profile name is safe to pass to the release script; the underlying secrets remain in Keychain.

## 3. Build the distributable release

Use the exact identity name reported by `security find-identity -v -p codesigning`.

```sh
./script/package_release.sh \
  --identity "Developer ID Application: Example Company (TEAMID)" \
  --notary-profile "PaperMon-Notary" \
  --version 1.0.0 \
  --build 1
```

The script performs these gates in order:

1. Builds a Release app for Apple Silicon and Intel.
2. Applies the App Sandbox entitlements and hardened runtime.
3. Performs strict signature validation.
4. Submits the app for notarization and staples its ticket.
5. Creates and signs a DMG containing PaperMon and an Applications shortcut.
6. Notarizes and staples the DMG.
7. Runs Gatekeeper assessment and prints the DMG SHA-256 checksum.

## 4. Inspect the artifacts

```sh
codesign -dvvv --entitlements :- "dist/release/PaperMon-1.0.0.app"
codesign --verify --deep --strict --verbose=2 "dist/release/PaperMon-1.0.0.app"
xcrun stapler validate "dist/release/PaperMon-1.0.0.dmg"
spctl --assess --type open --context context:primary-signature --verbose=4 "dist/release/PaperMon-1.0.0.dmg"
```

Install the app from the DMG into `/Applications` on a second Mac or a clean macOS user account, then complete the release sign-off section of the [hardware acceptance checklist](HardwareAcceptanceChecklist.md).
