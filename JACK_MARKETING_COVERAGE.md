# Jack Marketing Plan — Coverage Report

Coverage of Jack Fitzgerald’s **Downlink — Marketing Plan** against the
current `geonodecom/downlink` codebase and launch work.

Last updated: 2026-08-02

Status key:

| Mark | Meaning |
| --- | --- |
| Done | Implemented and present in the repo / verified locally |
| Partial | Started or assets exist, but a manual or follow-up step remains |
| Not started | Not begun |

Related tracker: [`REBRAND_TASKS.md`](REBRAND_TASKS.md)

---

## Snapshot

| Jack section | Done | Partial | Not started |
| --- | ---: | ---: | ---: |
| 1. Brand | Most rename + attribution | Icon artwork; domain registration | — |
| 2. Repo optimization | README, badges, templates, screenshots assets, installer CI | Topics, social-preview upload, real Linux shot, first public release, good-first-issues, org pin | — |
| 3. Standalone website | — | — | Entire section |
| 4. Backlink engine | — | — | Entire section |
| 5. Geonode value capture | In-app + README attribution | — | Labs page on geonode.com; proxy integration |

**Bottom line:** Engineering rebrand and GitHub-facing docs are largely done.
Public launch (release, website, directories, and marketing posts) is still open.

---

## Positioning

| Jack item | Status | Notes |
| --- | --- | --- |
| “Modern, open source download manager” / free, MIT, cross-platform | Done | README pitch + MIT `LICENSE`; Windows / Linux / Android targets |
| No ads, no bundleware | Done | Product positioning; no ads/bundleware in packaging |
| Built by Geonode Labs | Done | Settings About + README attribution → `https://geonode.com` |
| Wedge vs IDM / JDownloader | Not started | No `/vs/idm` or `/vs/jdownloader` pages yet (website section) |

---

## 1. Brand

| Jack item | Status | Evidence / gap |
| --- | --- | --- |
| Name: Downlink; repo `geonodecom/downlink` | Done | Package, binaries, remote, GitHub repo rename |
| Tagline: “The open source download manager” | Partial | README uses “Fast, open source download manager…” — close, not Jack’s exact phrase |
| Attribution in footer / README / About; headline nowhere | Partial | README + Settings About done; no website footer yet |
| Domains: verify / register (`downlink.download` + `getdownlink.com` redirect) | Not started | Website section; avoid `.zip` TLDs still applies |
| Avoid “Geonode Download Manager” naming | Done | User-facing strings and package renamed to Downlink |

Still open under brand:

- [ ] Final Downlink icon artwork (launcher / tray still use existing assets)
- [ ] Domain registration and DNS

---

## 2. Repo optimization (GitHub as traffic channel)

| Jack item | Status | Evidence / gap |
| --- | --- | --- |
| GitHub description field | Done | Matches Jack’s suggested copy |
| Website field on GitHub | Not started | Needs live site URL first |
| ~10 topics | Not started | Manual: `download-manager`, `downloader`, `flutter`, `dart`, `aria2`, `yt-dlp`, `windows`, `linux`, `android`, `open-source` |
| README rewrite (pitch → downloads → features → screenshots → install → attribution → dev last) | Done | [`README.md`](README.md); deep build notes in [`docs/development.md`](docs/development.md) |
| Badges (license, release, downloads, CI, stars) | Done | Shields in README |
| Fix screenshot typo; Windows / Linux / Android shots | Partial | `downlink-windows.png`, `downlink-android.png`, `downlink-linux.png` present; Linux image is a **generated stand-in** |
| Tag release with Windows + Linux + APK | Partial | CI ships Windows installer + portable zip + APK; **no published renamed release yet**; **no Linux artifact job** |
| Custom social / OG image | Partial | [`.github/social-preview.png`](.github/social-preview.png) at 1280×640; **must upload** in GitHub Settings → Social preview |
| CONTRIBUTING.md | Done | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| Issue templates | Done | Bug + feature forms; blank issues disabled |
| 3–5 `good first issue` labels / issues | Not started | Manual GitHub work |
| Pin repo on org profile | Not started | Org settings |
| Org README presenting Geonode Labs | Not started | `geonodecom/.github` profile README |
| Polish timed before launch / trending | Not started | Process / calendar, not code |

Extra repo hygiene Jack did not list but we shipped:

- [x] `SECURITY.md`, `CODE_OF_CONDUCT.md`, PR template
- [x] Windows installer (`Downlink-Setup-*.exe`) + portable zip naming + updater regex

Manual GitHub follow-ups still required:

- [ ] Upload social preview image
- [ ] Enable private vulnerability reporting
- [ ] Add topics; set website URL when live
- [ ] Create/label good-first-issue tasks
- [ ] Pin repo + org Labs README

---

## 3. Standalone website

| Jack item | Status |
| --- | --- |
| Hero screenshot + per-OS download buttons | Not started |
| Feature grid, GitHub stars badge, changelog / blog | Not started |
| SEO: `/download` per platform, `/vs/idm`, `/vs/jdownloader`, `/docs` | Not started |
| How-to content (incl. “download through a proxy” → Geonode) | Not started |
| Sitewide footer “Built by Geonode Labs” → geonode.com | Not started |
| HTTPS, redirects, analytics, sitemap / structured data | Not started |

No marketing site exists in this repo yet. Tracked under `REBRAND_TASKS.md` §4.

---

## 4. Backlink engine

| Jack item | Status |
| --- | --- |
| WinGet | Not started |
| Chocolatey | Not started |
| Scoop | Not started |
| Flathub | Not started |
| AlternativeTo | Not started |
| Product Hunt | Not started |
| awesome-flutter / Flutter lists | Not started |
| F-Droid (+ possible “clean” flavor without private social extractors) | Not started |
| Show HN (Flutter desktop + aria2 + native messaging angle) | Not started |
| r/opensource, r/flutterdev, lobste.rs | Not started |
| Monthly release notes; IDM-alternative threads; It’s FOSS / OMG Ubuntu / MakeUseOf | Not started |

Tracked under `REBRAND_TASKS.md` §5–6. Packaging prerequisites (Linux artifacts, signing, clean Android flavor) block several directory submissions.

---

## 5. Geonode value capture

| Jack item | Status | Notes |
| --- | --- | --- |
| Sitewide footer link → geonode.com | Partial | README + in-app About only; no website footer |
| Geonode Labs OSS page on geonode.com | Not started | Commercial site work |
| Later: optional residential-proxy acceleration | Not started | Explicitly post-adoption |

---

## What “done enough for a soft repo launch” looks like

Minimum remaining before treating GitHub as launch-ready:

1. Publish a GitHub Release with Windows installer + portable zip + APK (`RELEASE x.y.z` on `main`).
2. Upload social preview; add topics.
3. Replace Linux screenshot with a real VM capture (optional but recommended).
4. Smoke-test Windows / Android installs + Chromium native messaging.

Still **not** required for a repo-only soft launch, but required for Jack’s full plan:

- Domain + standalone website
- Linux release artifacts
- Directory listings (WinGet, Flathub, etc.)
- Show HN / community launch posts
- Geonode.com Labs page

---

## Suggested next-priority order

1. **Ship public release** (version decision + `RELEASE` commit) — unblocks downloads badges and directory listings.
2. **GitHub settings polish** — topics, social preview upload, private vulnerability reporting, good-first-issues.
3. **Linux packaging** — archive / AppImage + real screenshot.
4. **Domain + landing site** — primary SEO / backlink surface.
5. **Directories + launch posts** — after installable binaries and a real download URL exist.
6. **Geonode.com Labs page + proxy how-to** — value capture after traffic exists.

---

## Mapping to `REBRAND_TASKS.md`

| Jack section | Primary tracker section |
| --- | --- |
| Brand / rename | §1 Downlink rename |
| Repo optimization | §2 GitHub repository launch readiness + §3 Release engineering |
| Standalone website | §4 Standalone website |
| Backlink engine | §5 Distribution + §6 Launch and ongoing marketing |
| Geonode value capture | §2 attribution items + §6 Geonode Labs page / proxy docs |
