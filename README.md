# NC Mobiles — Product Image Studio Pro

Premium bulk product-image editor for phone LCD/parts photography.
Light theme, per approved Design Preview v2.

This drop turns Background Remove into an explicit "coming soon"
state instead of a hard dependency, per your request — the app now
checks for the model at launch and degrades gracefully if it's
absent, which is the default in this build. Nothing else changed
functionally from the last drop; see §3 for exactly how this works
and how to flip it on later.

**What I could and couldn't verify myself:** I have no Android SDK,
no Flutter toolchain, and no network access in the environment I
write this code in — so I cannot run `flutter pub get`, `flutter
analyze`, or `flutter build apk` myself, and nothing here has been
compiled. What I *did* do is a manual pass for the errors that
tooling would normally catch: matched every provider method a widget
calls against its definition, checked brace/paren balance file by
file, fixed two real bugs this pass turned up (a `DropdownButtonFormField`
using the wrong parameter name, a `Switch` color parameter that
wouldn't exist on the Flutter version this pins), and — importantly —
found and fixed three things that would have failed the build
outright: the pubspec referenced font files and a model file that
don't physically exist in this drop, and the Android manifest pointed
at launcher icons that didn't exist either. Fonts/model are now
optional directories instead of required files, and I generated a
real (simple) app icon at every density with Pillow so that reference
resolves. All of that said: the very first CI run is still the actual
proof. Expect to spend one debug cycle on whatever it turns up — that's
normal for a first build, not a sign something is fundamentally wrong.

---

## 1. What's new in this drop

- **Background Remove is now an explicit optional feature**, not a
  silent failure mode — see §3.
- **Crop** — real screen: draggable/resizable rectangle over the
  photo, aspect-ratio presets (Free / 1:1 / 4:5 / 16:9), applies a
  fractional crop that survives image replacement.
- **Resize** — width/height fields with aspect-lock and quick presets.
- **Rotate** — free-angle slider plus quick ±90° buttons.
- **Erase** — finger-paint eraser with adjustable brush size, for
  manual cleanup after Background Remove.
- **Text** — unchanged from last drop, already fully wired (font,
  size, weight, color, spacing, shadow, drag-to-position).
- **Layers** — hide / lock / duplicate / delete now actually mutate
  the project (previously these buttons were visual only).
- **Android platform files** — manifest with every permission the
  app needs, Gradle build files with a real release-signing config,
  ProGuard rules so minification doesn't strip TFLite at runtime, and
  a generated launcher icon.
- **CI pipeline** (`.github/workflows/build-release.yml`) — builds and
  signs a release APK + AAB automatically on GitHub Actions.

## 2. Get a real APK via GitHub Actions (no local install needed)

### Step 1 — Push this project to a GitHub repo
```
cd nc_studio_pro
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

### Step 2 — Generate a release keystore (one-time, do this locally)
You need a Java JDK installed for this one command (most machines
already have one; if not, any JDK 17 install works):
```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
It'll ask for passwords and identity details — keep the passwords
somewhere safe, you'll need them below. **Do not commit this file.**

### Step 3 — Base64-encode the keystore
```
# macOS / Linux
base64 -i upload-keystore.jks | tr -d '\n' > keystore_base64.txt

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Out-File keystore_base64.txt
```

### Step 4 — Add repository secrets
On GitHub: **Settings → Secrets and variables → Actions → New repository secret**.
Add these four:

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | contents of `keystore_base64.txt` |
| `KEYSTORE_PASSWORD` | the store password you set in Step 2 |
| `KEY_PASSWORD` | the key password you set in Step 2 |
| `KEY_ALIAS` | `upload` (or whatever alias you used) |

Optional fifth secret, for background removal:

| Secret name | Value |
|---|---|
| `MODEL_URL` | a direct HTTPS link to `u2netp.tflite` — see §3 |

If you skip `MODEL_URL`, the app still builds and runs fine — every
other tool works, and Background Remove shows a clear on-screen error
instead of crashing (see `BackgroundRemovalService`).

### Step 5 — Run the build
The workflow runs automatically on every push to `main`. To trigger it
by hand: **Actions tab → Build & Sign Release APK → Run workflow**.

### Step 6 — Get the APK
- **Quick download:** open the finished run under the **Actions** tab
  → scroll to **Artifacts** → download `nc-studio-pro-release-apk`.
- **Permanent link:** tag a version to also get a GitHub Release with
  the APK attached:
  ```
  git tag v1.0.0
  git push --tags
  ```

That's the whole pipeline — every future push to `main` produces a
freshly signed APK automatically.

## 3. Background removal — optional in this build

This build ships with **Background Remove intentionally deferred** —
you asked not to hunt down and add the model file right now, so the
app is set up to work fully without it:

- At launch, the app checks whether `assets/models/u2netp.tflite`
  is actually present (a cheap existence check, not a full model
  load).
- If it isn't there — the default in this build — the **BG Remove**
  tool shows a small "SOON" badge, and tapping it opens a short,
  friendly explanation instead of attempting (and failing) real
  removal. Nothing crashes, nothing silently does the wrong thing.
- Every other tool (Crop, Resize, Rotate, Flip, Upscale, Erase,
  Duplicate, Replace, Delete, Text, Layers, Export) works exactly the
  same either way.
- The pubspec only declares the `assets/models/` *directory*, not the
  exact file — so `flutter build` succeeds with or without the model
  present. Nothing about this build depends on it.

**To enable it later** (no rush): drop a free, offline `u2netp.tflite`
into `assets/models/`, or set it up via CI as described below, and
rebuild — no code changes needed, the app will detect it automatically
on next launch.

<details>
<summary>CI option — fetch the model at build time instead of committing it</summary>

Host `u2netp.tflite` anywhere with a stable HTTPS link (a GitHub
Release asset on this same repo works well) and set it as the
`MODEL_URL` repository secret. The workflow downloads it fresh on
every build if the secret is set, and simply skips that step
(building without the model) if it isn't — which is the default,
matching this drop.
</details>


## 4. Manual test-flow checklist (Upload → Apply → Edit → Export)

Once you have the APK installed, this is the exact flow the spec
asked for, with what to check at each step:

1. **Upload** — Home tab → "Upload product image" → pick a photo.
   The advanced-options sheet should appear immediately.
2. **Apply to all frames** — tap it. Return to Home: all four
   template cards should now show the same photo as a thumbnail.
3. **Edit independently** — go to the Edit tab. All four frames are
   visible in a 2×2 grid. Tap Gallery 1 to select it (blue outline),
   then Crop → drag the rectangle → Apply. Confirm Feature and Gallery
   2/3 are untouched — this is the "independent editing" requirement.
4. **Background Remove (coming soon in this build)** — with a frame
   selected and its image present, tap BG Remove in the toolbar.
   Expect a "Coming soon" dialog, not an error — this is the correct,
   intended behavior for this build (see §3). Everything else in the
   toolbar (Crop, Resize, Rotate, Flip, Upscale, Erase, Duplicate,
   Replace, Delete) should work normally on the same frame.
5. **Text** — tap the text icon in the Edit app bar, edit the sample
   text, change font size/color, drag it on the canvas, Done.
6. **Layers** — Layers tab: confirm the text layer, Frame, Product
   Image, and Background rows appear; toggle visibility on one and
   confirm it disappears from the Edit canvas.
7. **Export** — Export tab → confirm each row shows the right
   `N.webp` name (0=Feature, 1–3=Gallery) → "Change" to pick a folder
   → Export all → confirm the snackbar reports success and the files
   land in the chosen folder as WebP.

If any step doesn't behave as described, that's the fastest way to
localize which file to look at — each step above maps to one
screen/provider method named in the code.

## 5. Standard local build (if you'd rather not use CI)

```
flutter pub get
flutter build apk --release
```
Without `android/app/key.properties` present locally, this falls back
to a debug-signed APK (fine for sideloading/testing, not for Play
Store). To produce a properly signed local build, copy
`android/app/key.properties.example` to `android/app/key.properties`
and fill in your keystore details from §2.

Minimum SDK is 24 (required by `tflite_flutter`); already set in
`android/app/build.gradle.kts`.

## 6. Performance notes (unchanged from last drop)
- Live editing works on a downsampled copy of large photos (capped at
  1600px); full resolution is only touched once, at export.
- Background removal runs at a fixed 320×320 model input regardless
  of source photo size, so inference time stays roughly constant.
- The TFLite interpreter warms up at app launch, not on first tap.
- Export renders each frame off-screen at full resolution only at the
  moment of export.

## 7. Still open / next steps
- The generated app icon (`android/app/src/main/res/mipmap-*/ic_launcher.png`)
  is a simple placeholder mark in the approved blue — swap in real
  brand artwork whenever you have it, at the same five sizes.
- Custom frame template art (`assets/templates/`) is empty; frames
  render fine without it, but drop PNGs in there via Template Manager
  → Import for real border/frame overlays.
- iOS was out of scope for this request (Android-only per the
  original brief) — the Dart/Flutter code is cross-platform, but the
  `android/` platform files here obviously don't cover iOS signing.
