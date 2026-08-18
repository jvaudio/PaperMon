# PaperMon Hardware Acceptance Checklist

Use this checklist before promoting a build to beta or release. Run every applicable scenario with a fresh PaperMon build installed in `/Applications` rather than from Xcode or an external development volume.

## Test record

- PaperMon version/build:
- macOS version:
- Mac model and processor:
- Tester:
- Date:
- Display and dock inventory:

Record each result as **Pass**, **Fail**, or **Not applicable**. Attach a screenshot and the exact display/dock configuration to every failure.

## Baseline profile workflow

- [ ] PaperMon discovers every connected display exactly once.
- [ ] Portrait and landscape displays appear with the correct orientation.
- [ ] The arrangement is centered and no monitor cards overlap.
- [ ] A new profile contains one assignment for each connected display.
- [ ] Finder drag-and-drop assigns an image to the intended display.
- [ ] The Change button assigns an image through the file picker.
- [ ] Fill, Fit, Stretch, and Center visibly produce the expected macOS wallpaper treatment.
- [ ] Renaming a profile and monitor persists after quitting and reopening PaperMon.
- [ ] Duplicating and deleting profiles preserve the remaining profiles.
- [ ] Applying a profile updates every connected display and marks that profile active.
- [ ] Switching profiles from the menu bar changes the complete wallpaper set.

## Restart and lifecycle

- [ ] Enable **Open PaperMon at login** and approve it in System Settings if requested.
- [ ] Restart the Mac and confirm PaperMon launches without manual intervention.
- [ ] Confirm the active profile is restored after login.
- [ ] Put the Mac to sleep for at least one minute, wake it, and confirm the profile remains correct.
- [ ] Log out and back in, then confirm the profile remains correct.
- [ ] Disable **Open PaperMon at login**, restart, and confirm PaperMon does not launch.

## Display topology changes

- [ ] Disconnect one external display while PaperMon is running; remaining wallpapers stay correct.
- [ ] Reconnect that display; its prior wallpaper is restored.
- [ ] Reorder displays in System Settings; PaperMon continues matching each physical display correctly.
- [ ] Rotate a supported display in System Settings; PaperMon reflects the orientation without attempting to change it.
- [ ] Move a display to another port on the same Mac or dock; its assignment remains stable.
- [ ] Disconnect and reconnect the entire dock; all displays recover their assignments.
- [ ] Apply a profile while one saved display is absent; PaperMon reports the unavailable display without corrupting the profile.
- [ ] Add a new display and use Sync Displays; only the new assignment is added.

## Hardware matrix

Complete the applicable rows on at least one machine for each release candidate.

| Configuration | Result | Notes |
| --- | --- | --- |
| Built-in display only |  |  |
| Built-in plus one external display |  |  |
| Two or more native external displays |  |  |
| Identical monitor models |  |  |
| Mixed portrait and landscape displays |  |  |
| Thunderbolt or USB-C dock |  |  |
| DisplayLink dock |  |  |
| Sidecar display |  |  |
| Clamshell mode |  |  |

## Image persistence and permissions

- [ ] Managed-copy image still works after the original is moved or deleted.
- [ ] Referenced-original image still works after PaperMon quits and relaunches.
- [ ] Moving or deleting a referenced original produces a clear repair error.
- [ ] Images on a removable drive work after reconnecting the drive.
- [ ] Cancelling the file picker leaves the existing assignment unchanged.
- [ ] An unsupported or unreadable file produces a useful error without changing the profile.

## Failure recovery

- [ ] Disconnect a display during Apply; PaperMon reports the failure and preserves the prior active profile state.
- [ ] Reconnect the display and reapply successfully.
- [ ] Force quit PaperMon while idle, reopen it, and confirm profile data is intact.
- [ ] Confirm a corrupted or inaccessible referenced image affects only its assignment.

## Release sign-off

- [ ] All applicable checklist items pass.
- [ ] `swift test` passes on the release commit.
- [ ] The release app passes strict code-signature verification.
- [ ] The notarization submission is accepted.
- [ ] The stapled DMG passes Gatekeeper assessment on a different Mac or a clean macOS user account.
- [ ] The installed app completes the restart and login-item checks from `/Applications`.

Unresolved failures:

1. 

Release decision: **Approved / Blocked**
