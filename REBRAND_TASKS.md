# Downlink Rebrand and Launch Task List

This document tracks the technical work required to rebrand the project as
Downlink and prepare it as an open source product and Geonode Labs backlink
asset.

For a coverage map against Jack Fitzgerald’s marketing plan (done / partial /
not started), see [`JACK_MARKETING_COVERAGE.md`](JACK_MARKETING_COVERAGE.md).

Status: `[x]` completed, `[ ]` pending.

## 1. Downlink rename

### Repository and package

- [x] Rename the GitHub repository to `geonodecom/downlink`.
- [x] Rename the local project directory to `downlink`.
- [x] Update the local Git remote to `geonodecom/downlink`.
- [x] Create the `rename/downlink` implementation branch.
- [x] Rename the Dart package from `geonode_download_manager` to `downlink`.
- [x] Update Dart package imports and generated Drift code.
- [x] Rename the native host entry point to `bin/downlink_host.dart`.

### Application branding

- [x] Change visible application names and messages to Downlink.
- [x] Rename Dart application, settings, and diagnostics symbols.
- [x] Change application log prefixes to `[downlink]`.
- [x] Rename the Drift database to `downlink`.
- [x] Add “Built by Geonode Labs” to Settings with a link to `https://geonode.com`.
- [ ] Replace the existing icon artwork with final Downlink branding.

### Android

- [x] Change the namespace and application ID to `com.geonode.downlink`.
- [x] Move Kotlin sources to the new package path.
- [x] Rename Android method and event channels.
- [x] Change the launcher label and notification title to Downlink.
- [x] Rename Android internal preference and notification channel IDs.

### Windows

- [x] Rename the Windows binary to `downlink.exe`.
- [x] Update CMake project and binary names.
- [x] Update executable metadata and window title.
- [x] Set the company name and copyright to Geonode Labs.
- [x] Rename the installation directory and Start Menu shortcut.
- [x] Rename the Windows native host to `downlink-host.exe`.
- [x] Update install, uninstall, build, and self-update scripts.

### Linux

- [x] Rename the Linux binary to `downlink`.
- [x] Change the application ID to `com.geonode.downlink`.
- [x] Update the window and header-bar titles.
- [x] Rename and update the desktop entry to `packaging/downlink.desktop`.
- [x] Update Makefile installation and native-host paths.

### Browser extension

- [x] Change the extension name and description to Downlink.
- [x] Rename “Download with Geonode” to “Download with Downlink.”
- [x] Update extension notifications, status messages, and log prefixes.
- [x] Rename the native messaging host to `com.geonode.downlink`.
- [x] Keep the extension key and extension ID stable.

### Updates and release naming

- [x] Point the in-app updater to `geonodecom/downlink`.
- [x] Rename expected release assets to `downlink-*`.
- [x] Update release workflow artifact names.
- [x] Update updater tests for the new repository and filenames.
- [ ] Publish the first release containing the renamed application.

### Documentation and verification

- [x] Rename the Windows screenshot to `downlink-windows.png`.
- [x] Replace old application names and paths in the README.
- [x] Update `AGENTS.md` and third-party notices.
- [x] Run Drift code generation successfully.
- [x] Run `flutter analyze` with no issues.
- [x] Run the full automated test suite successfully.
- [x] Confirm no old `geonode_download_manager`, `geonode-download-manager`,
      or “Geonode Download Manager” identifiers remain in tracked source files.
- [x] Build `Downlink-Setup-0.1.0.exe` locally and verify it installs without
      elevation and creates an Apps / Control Panel uninstall entry.
- [ ] Build and smoke-test a clean Windows install.
- [ ] Build and smoke-test a clean Linux install.
- [ ] Build and smoke-test a clean Android install.
- [ ] Reinstall and verify Chromium native messaging on Windows and Linux.

The rename intentionally uses new internal identifiers without migrating
existing v0.0.x installations. Existing databases, settings, cookies, queues,
installation directories, and native-host registrations are not migrated.

## 2. GitHub repository launch readiness

- [x] Merge the Downlink rename into `main`.
- [x] Add the GitHub repository description: “Fast, open source download manager
      for Windows, Linux & Android. Pause/resume, queueing, browser integration,
      video downloads.”
- [ ] Add the project website to the GitHub repository settings when live.
- [ ] Add repository topics: `download-manager`, `downloader`, `flutter`, `dart`,
      `aria2`, `yt-dlp`, `windows`, `linux`, `android`, and `open-source`.
- [x] Rewrite the README for product-focused skimming:
  - [x] Hero and short pitch.
  - [x] Platform download buttons.
  - [x] Core feature overview.
  - [x] Screenshots.
  - [x] Installation instructions.
  - [x] Geonode Labs attribution.
  - [x] Development documentation last (`docs/development.md`).
- [x] Add Windows, Linux, and Android screenshot assets.
- [ ] Replace the generated `downlink-linux.png` stand-in with a real Linux VM
      capture.
- [x] Add license, release, downloads, CI, and stars badges.
- [x] Create `.github/social-preview.png` at 1280×640.
- [ ] Upload `.github/social-preview.png` in GitHub Settings → General →
      Social preview.
- [x] Add `CONTRIBUTING.md`.
- [x] Add `SECURITY.md`.
- [x] Add `CODE_OF_CONDUCT.md`.
- [x] Add bug-report and feature-request issue templates.
- [x] Add a pull-request template.
- [ ] Enable GitHub private vulnerability reporting in repository settings.
- [ ] Create and label 3–5 meaningful `good first issue` tasks.
- [ ] Pin Downlink on the Geonode organization profile.
- [ ] Add a Geonode Labs organization profile README.

## 3. Release engineering

- [ ] Decide the public launch version.
- [ ] Prefer tag-triggered releases over special release commit messages.
- [x] Produce renamed Windows and Android artifact names in CI.
- [x] Add CI packaging for `Downlink-Setup-<version>.exe` as the primary Windows
      download.
- [x] Add CI packaging for `downlink-<version>-windows-x64-portable.zip` as the
      optional portable Windows download and updater payload.
- [x] Point the Windows updater asset regex at the portable zip name.
- [ ] Add an automated Linux release job.
- [ ] Package a Linux archive, AppImage, or both.
- [ ] Generate SHA-256 checksums for release files.
- [ ] Verify bundled aria2, yt-dlp, ffmpeg, notices, and native host files.
- [ ] Configure production Android signing.
- [ ] Evaluate Windows code signing.
- [ ] Test clean installation, update, uninstall, and rollback paths.
- [ ] Publish a GitHub release with Windows, Linux, and Android downloads.
- [ ] Add clear release notes and installation instructions.

## 4. Standalone website

- [ ] Verify and register the primary domain.
- [ ] Configure a secondary redirect domain if purchased.
- [ ] Build a landing page with a hero screenshot and per-OS downloads.
- [ ] Resolve current download URLs from GitHub Releases.
- [ ] Add Windows, Linux, and Android download pages.
- [ ] Add `/docs`.
- [ ] Add `/vs/idm`.
- [ ] Add `/vs/jdownloader`.
- [ ] Add release notes or a changelog section.
- [ ] Add Open Graph metadata and social preview images.
- [ ] Add canonical URLs, sitemap, and structured data.
- [ ] Add a sitewide “Built by Geonode Labs” link.
- [ ] Configure HTTPS and redirects.
- [ ] Add privacy-conscious traffic and download analytics.

## 5. Distribution

- [ ] Publish a WinGet package.
- [ ] Publish a Chocolatey package.
- [ ] Publish a Scoop manifest.
- [ ] Publish a Flathub package.
- [ ] Create an F-Droid-compatible Android build flavor.
- [ ] Evaluate a clean store build without private social login/extraction.
- [ ] Verify bundled dependencies against store and registry policies.
- [ ] Document dependency sources and reproducible build steps.
- [ ] Create an AlternativeTo listing.
- [ ] Prepare a Product Hunt launch.
- [ ] Submit Downlink to relevant Flutter and open source lists.

## 6. Launch and ongoing marketing

- [ ] Prepare a technical Show HN post.
- [ ] Prepare launch posts for open source and Flutter communities.
- [ ] Prepare a Lobsters submission.
- [ ] Publish architecture documentation covering Flutter desktop, aria2,
      Android native services, and Chromium native messaging.
- [ ] Publish monthly release notes.
- [ ] Prepare outreach for Linux and productivity publications.
- [ ] Add a Geonode Labs open source page to `geonode.com`.
- [ ] Publish useful documentation such as downloading through a proxy, with
      contextual Geonode attribution.
- [ ] Consider an optional residential-proxy integration only after Downlink
      has established user trust and adoption.

