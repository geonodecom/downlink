# Security Policy

## Supported versions

Security fixes are prioritized for the **latest published GitHub Release** of
Downlink. Older releases may not receive patches.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Report privately through GitHub Security Advisories:

https://github.com/geonodecom/downlink/security/advisories/new

If private vulnerability reporting is not yet enabled on the repository, use a
private channel with a maintainer until it is available, and still avoid posting
exploit details publicly.

### What to include

- A clear description of the issue and its impact
- Steps to reproduce, or a minimal proof of concept
- Affected platforms (Windows, Linux, Android) and Downlink version
- Whether the issue involves remote code execution, local privilege abuse,
  credential leakage, path traversal, or unsafe unpacking of updates/downloads
- Any suggested remediation if you have one

Remove cookies, session tokens, private URLs, and personal data from reports
whenever possible. Include redacted samples instead.

## Response expectations

Maintainers will acknowledge private reports when they can and work toward a fix
or mitigation for confirmed issues. Timing depends on severity and available
bandwidth; this policy does not promise a fixed SLA.

We may request more detail, ask for coordinated disclosure timing, and credit
reporters in release notes when appropriate and agreed.

## Non-security bugs

For crashes, download failures, and other non-security defects, please use the
[bug report form](https://github.com/geonodecom/downlink/issues/new?template=bug_report.yml).
