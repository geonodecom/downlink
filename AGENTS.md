# Downlink Agent Guide

Downlink is a Flutter download manager for Linux, Windows, and
Android. Desktop builds are powered by aria2; Android uses a native foreground
download service.

Keep this file limited to durable project expectations. Discover structure,
types, commands, and behavior from the code, tests, README, and manifests.

## Documentation

- Use the `$find-docs` skill and Context7 for library, framework, SDK, API, CLI,
  and cloud-service documentation.
- Do not rely on memory for current API syntax, setup, configuration, or
  version-specific behavior.

## Code Rules

- Prefer maintainable, readable, simple code over micro-optimization.
- Avoid clever control flow and defensive branches for unlikely edge cases unless
  they protect user data, security, or core download correctness.
- Follow Dart, Flutter, Riverpod, Drift, and aria2 best practices.
- Apply SOLID principles pragmatically; do not add abstractions without a clear
  responsibility boundary.
- Keep comments sparse. Add them only for non-obvious lifecycle, protocol,
  persistence, or platform behavior.
- Treat tests as part of the design. Test core behavior with deterministic
  fakes rather than timing guesses.

## Useful Commands

```sh
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter build linux --release
flutter build windows --release
flutter build apk --release
flutter build appbundle --release
make run
```
