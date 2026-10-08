# Glance attribution and integration

Adapted from [jonnyoo/glance](https://github.com/jonnyoo/glance) at
`b97f521397ec1197ba17768ba797cae1e628848d` (MIT, © 2026 Jonathan Zhou).
The MIT notice is retained in [LICENSE](LICENSE) and packaged with the app.

`Sources/Vorssaint/Services/FaceUnlock/Glance` contains the face detector,
aligner, ArcFace embedder, scoring, encrypted enrollment/credentials and
liveness cues. All imported types have a `Glance` prefix. The keystroke
adapter is also derived from Glance and retains its notice.

Integration changes: no generic Vision feature-print fallback; independent
Keychain and private file namespaces; strict encrypted-store read failures;
clear in-memory templates on session lock; capture and recognition managed
by Vorssaint; heavy liveness required; only the active user's lock screen can
receive a password; every keyboard batch checks a revocable permit. Native
settings and lock-screen rendering use Vorssaint's existing components.

Glance's updater, telemetry-free standalone lifecycle, branding, onboarding
windows, Face Lab and input-monitoring keyboard hook are not imported.

The model weights are covered separately: see [MODEL-NOTICE.md](MODEL-NOTICE.md).
