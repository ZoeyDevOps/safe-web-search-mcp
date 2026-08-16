# Changelog

Notable user-visible changes are recorded here, along with what each release was
verified against. Versions follow Semantic Versioning.

## Unreleased

## 1.0.0 - 2026-08-16

Initial public release.

- One read-only `search_web` tool for MCP hosts on Windows PowerShell 5.1.
- Fixed destination, strict SafeSearch, no redirects, no cookies, no result-page
  fetching.
- Bounded input size, nesting, query length, result count, response size, parse
  time, network time, and call rate.
- Results carry UTC completion time, unknown-freshness and unverified-snippet
  markers.
- Unrecognized, blocked, or truncated provider responses fail closed.
- Script, style, and other raw-text elements are read as text wherever they
  appear, so ordinary page JavaScript cannot fail a search and their contents
  never reach visible result text.
- The installer no longer replaces the permissions of a `-InstallRoot` directory
  that already existed. Only a directory it creates itself receives the
  restricted access control; a pre-existing root must already carry that exact
  access control and be recognisably the installer's own, or the install is
  refused without any change. Unsafe roots fail closed under `-WhatIf` as well.
  UNC roots are rejected.

### Verified for this release

Validated on Windows 11 Pro 25H2, build 26200.9168, with Windows PowerShell 5.1
(Desktop), from a non-elevated standard-user account. Package validation
confirmed the server matches the hash recorded in `release-manifest.json`.

- `scripts\validate-package.ps1` with no switches: the offline protocol suite
  (53 responses), the LM Studio setup preview, and the install-root ACL suite
  (11 cases, including a real install, an idempotent re-install, and refusal of
  a pre-existing root left byte-for-byte and ACL-for-ACL unchanged).
- LM Studio 0.4.20+1, the file version reported by the installed executable and
  written as 0.4.20 Build 1 elsewhere in this project: initialization,
  `tools/list`, and `tools/call`. The command the host displayed matched the
  reviewed executable, the six reviewed arguments in order, the versioned
  installed path, and a 15000 ms timeout. Approval was per call rather than once
  per session: two searches, a prompt raised each time, each granted as a
  one-time allow. That last point is an operator observation rather than a
  measured one, and can only ever be: the host writes no approval state to disk,
  so nothing records it but a person watching the dialog.
- Three live requests were made to the provider for this release: one smoke test
  run directly against the server, and two more through the host during the LM
  Studio test. All returned results with no throttling, bot check, or block, and
  all fell well inside the process limits of 10 per minute and 60 per hour.
- Installed from an extraction of the tracked tree (`git archive`) - the same
  contents as a source download, without a Mark of the Web - into a new root on
  a non-elevated standard-user account: correct layout, inheritance disabled,
  access limited to SYSTEM, Administrators, and the installing user, and no
  reparse points beneath it. Untested: a separate account with no developer
  tooling or MCP host already present, and a browser-downloaded archive carrying
  a Mark of the Web. The installer's own path is covered above; a Mark of the Web
  governs whether Windows raises a SmartScreen prompt, which is the operating
  system's behaviour rather than this project's code.
- No archive checksum is published. GitHub's generated source archives are not
  guaranteed to be byte-stable, so a hash published for one could stop matching
  without anything here changing. Use the manifest check in the README instead,
  which states plainly what it does and does not establish.
- Provider terms re-read on 2026-08-16; the comparable-projects limb of the
  reasoning was re-tested on 2026-08-15. Both dates, and what each found, are in
  the review record in [PROVIDER-NOTICE.md](PROVIDER-NOTICE.md).
- Host configuration template contents are asserted by package validation, not by
  host testing. LM Studio is the only verified host.
