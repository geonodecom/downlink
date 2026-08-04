# Development

This document covers building, installing, and extending Downlink from source.
For a product overview and end-user install steps, see the [README](../README.md).

## Prerequisites

- Flutter 3.41+
- Dart 3.11+

Before building a release locally, fetch bundled tools:

```powershell
# Windows
powershell -File tool/windows/fetch_deps.ps1

# Linux
make fetch-deps

# Android
powershell -File tool/android/fetch_deps.ps1
```

During development, `flutter run` can still use tools from PATH if bundled
`bin/` is not present yet.

### Linux build host

- Linux desktop build dependencies for Flutter
- AppIndicator/Ayatana development headers for tray support
- `lld-21` or another linker available next to `clang++`
- `python3` when using the bundled Linux yt-dlp script
- Bundled tools from `make fetch-deps` **or** system `aria2c`, `yt-dlp`, and `ffmpeg` on PATH

On Debian/Ubuntu-like systems:

```sh
sudo apt install python3 clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev libayatana-appindicator3-dev lld-21
```

### Windows build host

- [Visual Studio](https://visualstudio.microsoft.com/) with the **Desktop development with C++** workload
- Windows Developer Mode enabled (Flutter plugin symlinks), or equivalent symlink privilege
- [Inno Setup 6](https://jrsoftware.org/isinfo.php) when building `Downlink-Setup-<version>.exe`

### Android build host

- Android SDK with cmdline-tools, platform-tools, and a recent platform (API 35+)
- Accepted Android SDK licenses (`flutter doctor --android-licenses`)
- Run `tool/android/fetch_deps.ps1` before `flutter build apk` / `appbundle` so
  `libffmpeg.so` and `libc++_shared.so` are installed under
  `android/app/src/main/jniLibs/<abi>/` (requires a local Android NDK)

## Common commands

```sh
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

Regenerate Drift code after schema changes:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Run

### Linux

```sh
make run
# or
flutter run -d linux
```

Makefile helpers:

```sh
make run          # debug launch through Flutter
make run-log      # debug launch and write stdout/stderr to the user state dir
make run-verbose  # debug launch with verbose Flutter logs
make build-debug
make run-debug-bundle
```

### Windows

```powershell
powershell -File tool/windows/fetch_deps.ps1
flutter run -d windows
```

### Android

```powershell
powershell -File tool/android/fetch_deps.ps1
flutter devices
flutter run -d <android-device-id>
```

Optional smoke harness:

```powershell
flutter test integration_test/android_smoke_test.dart -d <android-device-id>
```

## Build

### Linux

```sh
make build
```

The release bundle is written to `build/linux/x64/release/bundle/`.

### Windows

```powershell
powershell -File tool/windows/build.ps1
```

The release bundle is written to `build/windows/x64/runner/Release/`.
`build/downlink-host.exe` is produced for native messaging.

To build the per-user installer (`dist/Downlink-Setup-<version>.exe`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/windows/build_installer.ps1
```

CI also packages `downlink-<version>-windows-x64-portable.zip` from the same
bundle for optional portable use and for in-app updates.

### Android

```powershell
powershell -File tool/android/fetch_deps.ps1
flutter build apk --release
flutter build appbundle --release
```

Outputs:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

Release builds currently sign with the debug keystore so local install works.
Replace `signingConfig` in `android/app/build.gradle.kts` with your Play Store
keystore before publishing.

APK size grows substantially because static ffmpeg is packaged per ABI.

## Install from a local build

### Linux

```sh
make install
```

This builds and installs the release bundle under `~/.local/share/downlink`, creates
`~/.local/bin/downlink`, installs the desktop entry and icon, and installs the
native messaging host.

If you already ran `make build`:

```sh
make install-built
```

To uninstall:

```sh
make uninstall
```

### Windows

Developer install (from a local build; no Add/Remove Programs entry):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/windows/install.ps1
```

Avoid mixing the developer script with the installer on the same machine — both
write the same registry keys, but only the installer creates an uninstall entry.

To uninstall a developer install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/windows/uninstall.ps1
```

Installer-based installs should be removed from Windows Settings → Apps.

### Android

```powershell
flutter install -d <android-device-id>
# or
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Chromium extension

Desktop only. Android uses share / view intents instead.

`make install` (Linux) or the Windows installer / `tool/windows/install.ps1`
install the app, the `downlink-host` native messaging bridge, and native host
manifests for Chrome, Chromium, Edge (Windows), and Brave.

To use the extension during development:

1. Install Downlink as above.
2. Open `chrome://extensions`, `edge://extensions`, or `brave://extensions`.
3. Enable Developer mode.
4. Choose **Load unpacked** and select `extensions/chrome`.

The extension adds a **Download with Downlink** link context-menu item. Automatic
download capture is off by default and can be enabled from the extension popup.
Manual captures can launch Downlink when needed. Automatic captures only hand off to
an already-running Downlink instance; if Downlink is unavailable, the extension falls
back to the browser download and shows a notification.

On Windows, the running app publishes a loopback TCP endpoint file at
`%LOCALAPPDATA%\downlink\extension-endpoint.json` for `downlink-host`. Linux continues
to use a Unix domain socket under `$XDG_RUNTIME_DIR`.

## Platform download engines

- **Desktop HTTP:** local aria2 process managed by the app.
- **Android HTTP:** `DownloadForegroundService` with segmented Range downloads;
  completed files are published to the system Downloads collection via MediaStore.
- **YouTube (desktop):** yt-dlp + ffmpeg.
- **YouTube (Android):** `youtube_explode_dart` for metadata/streams and bundled
  ffmpeg (`libffmpeg.so`) to merge high-resolution video+audio.
- **Facebook / Instagram / TikTok (desktop):** yt-dlp.
- **Facebook / Instagram / TikTok (Android):** progressive CDN MP4 extraction + HTTP.
  Photo posts, carousels, slideshows, live streams, and playlists are not supported.
- **Private social videos:** Android WebView session login (Settings), or desktop
  cookies.txt / `--cookies-from-browser`.
- **Torrents:** desktop uses aria2 BitTorrent; Android uses libtorrent4j. All files
  in a torrent are downloaded; seeding is controlled in Settings → Torrents.

Keep desktop **yt-dlp** on the **nightly** channel for TikTok
(`yt-dlp --update-to nightly`, or re-run `tool/windows/fetch_deps.ps1` /
`make fetch-deps`). TikTok’s JS/WAF challenges change often; stable releases lag
those fixes. The error “Unable to extract universal data for rehydration” almost
always means the bundled/PATH yt-dlp is too old for current TikTok.

YouTube downloading may conflict with Play Store policy; sideload/dev builds are
the safest Android distribution path for now.

## In-app updates

Downlink checks GitHub for new releases on Windows and Android.

- **Android:** After download, the system APK installer opens. You may need to
  allow installing updates for this app (install unknown apps).
- **Windows:** In-app updates apply to installs that include `apply_update.ps1`
  (installer and portable zip). The app downloads
  `downlink-<version>-windows-x64-portable.zip`, quits, applies files via
  `apply_update.ps1`, and restarts. Debug builds without that script must update
  manually from GitHub.
- **Linux:** No automated update yet; download new builds from GitHub releases
  when Linux artifacts are published.

## Releases

GitHub Actions publishes releases from `main` when a commit message contains
`RELEASE x.y.z` (for example `RELEASE 0.1.0`). Current Windows assets:

- `Downlink-Setup-<version>.exe` — primary per-user installer
- `downlink-<version>-windows-x64-portable.zip` — portable zip / updater payload
- `downlink-<version>.apk` — Android APK

Release packages include [`packaging/THIRD_PARTY_NOTICES.md`](../packaging/THIRD_PARTY_NOTICES.md).
