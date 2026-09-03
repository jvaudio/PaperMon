# PaperMon Release Process

PaperMon supports a local packaging check and a production Developer ID workflow. Production distribution requires an Apple Developer Program account, a **Developer ID Application** certificate in the login keychain, notarization credentials stored in a keychain profile, and the PaperMon Sparkle signing key in the login keychain.

PaperMon uses Sparkle 2 for updates. Installed copies check the public appcast once per day, download verified updates in the background, and install them when Sparkle determines it is safe. Users can also check immediately from Settings or the application menu.

## 1. Validate packaging locally

This creates an ad-hoc signed universal app and DMG. It verifies the release build, bundle structure, entitlements, strict signature validation, and disk-image creation without using release credentials.

```sh
./script/package_release.sh --ad-hoc --version 0.1.0 --build 1
```

The artifacts are written to `dist/release/`. Ad-hoc artifacts are only for local validation and must not be distributed.

The ad-hoc build embeds and signs Sparkle locally, but it intentionally does not replace the production `appcast.xml`.

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
2. Embeds the app icon and Sparkle framework, then signs Sparkle's helpers from the inside out.
3. Applies PaperMon's minimal entitlements and the hardened runtime. Direct distribution intentionally does not use App Sandbox because macOS's wallpaper helper must open each managed image independently.
4. Performs strict signature validation.
5. Submits the app for notarization and staples its ticket.
6. Creates and signs a DMG containing PaperMon and an Applications shortcut.
7. Notarizes and staples the DMG.
8. Runs Gatekeeper assessment and prints the DMG SHA-256 checksum.
9. Signs the update archive with PaperMon's Sparkle key and replaces `appcast.xml` with the new release entry.

Do not run Sparkle's `generate_keys` again for routine releases. The existing private key is stored in the login Keychain; back it up securely and never commit an exported private key.

## 4. Publish the release and update feed

The updater expects a GitHub release tagged `v<version>` and the exact DMG name produced by the script. For version `1.2.0`, publish:

```text
Tag: v1.2.0
Asset: PaperMon-1.2.0.dmg
```

Upload the DMG to that release first. Then commit and push the generated `appcast.xml` to `main`. Publishing the feed last prevents installed copies from seeing an update before its download is available.

## 5. Inspect the artifacts

```sh
codesign -dvvv --entitlements :- "dist/release/PaperMon-1.0.0.app"
codesign --verify --deep --strict --verbose=2 "dist/release/PaperMon-1.0.0.app"
xcrun stapler validate "dist/release/PaperMon-1.0.0.dmg"
spctl --assess --type open --context context:primary-signature --verbose=4 "dist/release/PaperMon-1.0.0.dmg"
plutil -p "dist/release/PaperMon-1.0.0.app/Contents/Info.plist" | grep -E 'SUFeedURL|SUPublicEDKey'
codesign --verify --deep --strict --verbose=2 "dist/release/PaperMon-1.0.0.app/Contents/Frameworks/Sparkle.framework"
```

Install the app from the DMG into `/Applications` on a second Mac or a clean macOS user account, then complete the release sign-off section of the [hardware acceptance checklist](HardwareAcceptanceChecklist.md).
