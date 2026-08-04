# Contributing to Downlink

Thanks for helping improve Downlink. This guide covers how to set up the project,
propose changes, and get a pull request ready for review.

## Before you start

- Read the [Code of Conduct](CODE_OF_CONDUCT.md).
- Check [open issues](https://github.com/geonodecom/downlink/issues) and existing
  pull requests to avoid duplicate work.
- For security vulnerabilities, follow [SECURITY.md](SECURITY.md) instead of
  opening a public issue.
- Prefer filing an issue first for larger features or behavior changes.

## Development setup

Prerequisites and platform-specific toolchains are listed in
[docs/development.md](docs/development.md).

Typical workflow:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Useful platform commands:

```sh
make run                      # Linux
flutter run -d windows        # Windows
flutter run -d <device-id>    # Android
```

## Making changes

1. Fork the repository (if needed) and create a focused branch from `main` or
   `development`.
2. Keep the change scoped to one concern.
3. Prefer maintainable, readable code over micro-optimization.
4. Follow existing Dart, Flutter, Riverpod, Drift, and aria2 patterns in the repo.
5. Keep comments sparse — explain non-obvious lifecycle, protocol, persistence,
   or platform behavior only.
6. Treat tests as part of the design. Prefer deterministic fakes over timing
   guesses.
7. After Drift schema or table changes, regenerate code with
   `dart run build_runner build --delete-conflicting-outputs` and commit the
   generated output when the project expects it.

## Verification checklist

Before opening a PR:

- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] You exercised the affected platform(s) manually when UI, downloads,
      installers, native messaging, or Android services changed
- [ ] Screenshots or short notes are included for user-visible UI changes
- [ ] Secrets, cookies, private URLs, and personal data are not committed

## Pull requests

Use the pull request template and include:

- A clear summary of why the change exists
- Linked issue number when applicable
- Platforms tested
- Any release, packaging, or security impact

Small, reviewable PRs land faster than large multi-topic ones.

## Issue reports

Use the GitHub issue forms:

- [Bug report](https://github.com/geonodecom/downlink/issues/new?template=bug_report.yml)
- [Feature request](https://github.com/geonodecom/downlink/issues/new?template=feature_request.yml)

Remove cookies, tokens, and private download URLs from logs before posting.

## Questions

If something in the docs is unclear, open an issue describing what you tried and
where the instructions failed. Product overview lives in the
[README](README.md); deep build notes live in
[docs/development.md](docs/development.md).
