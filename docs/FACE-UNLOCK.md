# Face Unlock (Glance integration, beta)

This fork integrates Glance's local face recognition into Vorssaint's existing
feature catalog, settings, permissions and lock-screen rendering. It needs no
second app, login item, updater or menu bar icon. Update checks point to this
fork and start disabled, so an upstream release cannot replace the integration. The host remains macOS 14+
on Apple Silicon; its older deployment target is preserved. Testing on macOS
14/15 and actual camera/lock-screen testing are still required before release.

## Build and set up

Build with `./build.sh` or `./build.sh --dev`. The existing Command Line Tools
workflow compiles the bundled ArcFace model with Core ML; full Xcode is not
required. Build failure is explicit if the model cannot compile, and runtime
model errors never fall back to a weaker recognizer.

1. In **Settings → Features**, install **Face Unlock**. Installing does not enable it.
2. Open its settings, read the webcam limitations and accept them.
3. Choose **Authorize this session** and authenticate with macOS.
4. Enter your Mac login password and choose **Verify and save**. Open Directory
   verifies it locally before the app encrypts and saves it in Keychain.
5. Allow Camera and Accessibility when requested. Choose a camera, then
   **Enroll your face** and capture the five guided poses in good light.
6. Turn on **Enable face unlock**. On the next lock or wake, look at the camera
   and blink. Heavy liveness checks are always required.

The camera runs only during enrollment or a bounded, ten-second unlock attempt.
The lock-screen indicator is optional and never takes keyboard focus. After an
unsuccessful face scan, use the password normally or wake the display to retry.
Once a password is submitted, no further password is submitted for that lock.

## Dynamic Island

With the island's lock-screen surface enabled, scanning replaces its padlock
with a gently pulsing face symbol. Password submission shows a key; only the
macOS unlock notification opens the padlock using the host's existing animation.
An unsuccessful scan briefly shows an amber lock before returning to idle.
Reduce Motion disables the pulse and symbol transitions. Music bars, playback
controls, timers, downloads and the other lock-screen activities keep their
existing owners and layout.

If the lock-screen island is unavailable, a temporary indicator uses the
island's fitted camera geometry or its floating position on a display without
a notch. With Dynamic Island off, a compact capsule appears at the upper right.
This does not enable the island or start any of its activity sources. Display
changes reconnect the indicator to the host surface without duplicate windows.
Cancelling, sleeping or unlocking removes the scan indicator immediately.
Turn off **Show lock-screen indicator** to hide both presentations.

You must authorize the credential session after every app launch. **Pause
session**, uninstalling the feature, switching to another user or quitting
clears the session key and in-memory templates. Disabling the feature cancels
scanning immediately. **Forget face and password** removes this app's local
credentials and face enrollment. It does not touch standalone Glance data.

## Security and privacy boundaries

A webcam is not Apple's Face ID or Touch ID. Printed images, replayed video or
other spoofs remain a risk despite Glance's liveness cues. This is a convenience
feature, not a security upgrade. It cannot unlock FileVault before login after
a restart, replace the system login process, or unlock another user account.

The native integration requires the active user's session to be locked according
to Core Graphics, both before decrypting the password and before each keyboard
batch. Notification messages merely trigger checks. Cancellation revokes the
scan's permit. There is still an unavoidable race between checking lock state
and posting a keyboard event; macOS supplies no atomic third-party unlock API.
Do not treat this mechanism as equivalent to Apple's secure biometric hardware.

Passwords and face templates use Glance's AES-GCM design with a Keychain session
key gated by system user presence. The decrypted key stays in memory only for
the authorized app session. Plaintext buffers are cleared after use where
possible; Swift and system APIs can still create temporary copies. Camera
frames are never recorded, and no biometric data or password leaves the Mac.

Storage uses the running app's bundle identifier plus `.face-unlock` for
Keychain, and `Application Support/<bundle id>/FaceUnlock` for encrypted
face templates. The directory is owner-only. No Glance storage is migrated.
Settings backups omit authorization, enablement, consent and camera identity;
only the ordinary appearance preference and feature installation are portable.

The overlay uses Vorssaint's existing private window-server bridge. If macOS
removes that API, the indicator may be unavailable; normal password login is
always available. This integration does not request Input Monitoring.

## Model and source terms

Glance code is MIT, Vorssaint code is GPL-3.0-or-later, and the bundled pretrained
InsightFace weights have separate **non-commercial research-only** terms.
This is an experimental evaluation fork, not a general-purpose release.
See [source attribution](../ThirdParty/Glance/README.md) and
[model notice](../ThirdParty/Glance/MODEL-NOTICE.md). A distributable product
needs appropriately licensed weights and validation; the source licenses do
not relicense the weights. No official Vorssaint release is produced here.

## Validation

Automated gates cover default-off installation, all scan prerequisites, revoked
permits, current-user session checks, indicator routing, stale and switched face tracks, five-pose
acceptance, matching thresholds, translation coverage and settings backup
exclusions. The upstream Glance liveness tests can run offline through
`./Tools/test-glance-liveness.sh`. Build and run the existing selftest and full
suite as described in [CONTRIBUTING](../CONTRIBUTING.md).

Local validation on 8 October 2026, MacBook Pro (Apple M5), macOS 27.0.1:

- `./build.sh`: optimized app bundle built without compiler warnings.
- `./build/stage/Vorssaint.app/Contents/MacOS/Vorssaint --selftest`: `SELFTEST OK`,
  including a real Core ML prediction on a synthetic image using the bundled model.
- `./build.sh --test`: 114,975 checks passed, including the new Face Unlock suite;
  preference cleanup, uninstall and developer-install isolation checks also passed.
- `./Tools/test-glance-liveness.sh`: all imported synthetic liveness tests passed.
- `codesign --verify --deep --strict build/stage/Vorssaint.app`: passed for the
  local ad-hoc signature. The executable retains a macOS 14.0 deployment target.
- Native settings inspected in a separate preview bundle with all other features
  disabled: setup layout, permission guidance and disabled authorization gates
  checked. No credential was entered, permission granted or face enrolled.

These are local results, not a claim of CI, older-OS or real-camera validation.
The Dynamic Island routing and existing geometry are covered by unit tests;
actual lock-screen presentation and unlock behavior remain hardware checks.

Manual checks for the owner (not automated): enroll and unlock with the built-in
and an external camera; deny each permission; disconnect the chosen camera;
cancel setup and verify the camera indicator stops; disable/uninstall during a
scan; unlock with Touch ID/password while scanning; switch users; change the Mac
password; test sleep/wake, displays with and without a notch, multi-monitor
placement, dark/light appearance, VoiceOver and every supported OS. Never use
real credentials in fixtures or attach face images/passwords to bug reports.
