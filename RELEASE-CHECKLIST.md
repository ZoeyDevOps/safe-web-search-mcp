# Pre-publication release checklist

Do not publish merely because the code passes its tests. Provider authorization,
source rights, security documentation, and a clean release artifact are separate
release gates.

## 1. Re-confirm the provider position

This project publishes without provider authorization, as an accepted and
documented risk rather than a resolved question. That position is recorded in
[PROVIDER-NOTICE.md](PROVIDER-NOTICE.md) and has to be re-examined at every
release, because the facts it rests on can change without notice.

- [ ] Read the current provider Terms of Service, Acceptable Use Policy, and
      partnership or developer guidance from their official pages.
- [ ] Record the review date and the exact provider endpoint or API being used.
- [ ] Confirm `PROVIDER-NOTICE.md` still describes the position accurately: no
      written authorization sought or obtained, published as an accepted
      documented risk, on reasoning specific to the author's jurisdiction and
      non-commercial personal use.
- [ ] Re-test the reasoning rather than assuming it survived. Provider terms
      change, and comparable projects using the same endpoint can be challenged
      or shut down. If either has changed, reopen the decision instead of
      shipping on a stale rationale.
- [ ] Never describe the integration as authorized, approved, official, or
      compliant, in the repository, the release notes, or any listing.
- [ ] Keep the redistributor's notice intact and prominent; do not let a release
      imply the author's reasoning covers anyone else.
- [ ] Keep the conservative request limits and the stop-if-blocked instruction
      intact. They are the practical basis of the position, not tuning knobs.
- [ ] Keep provider attribution plain and accurate without implying endorsement.
- [ ] Confirm that the project name does not contain DuckDuckGo and that no
      DuckDuckGo logo, Dax artwork, trade dress, or misleading branding is used.
- [ ] Re-read [PROVIDER-NOTICE.md](PROVIDER-NOTICE.md); do not weaken its code,
      content, terms, or trademark boundaries.

## 2. Confirm rights and licensing

- [ ] Confirm the right to license every source and documentation contribution.
- [ ] Remove or separately license any copied material that is not compatible
      with MIT.
- [ ] Keep the complete MIT text in `LICENSE` and the accurate copyright-holder
      line.
- [ ] Keep `SPDX-License-Identifier: MIT` and the copyright notice in source
      files.
- [ ] Add third-party license and attribution notices if dependencies or copied
      material are introduced later.
- [ ] State clearly that MIT covers project-authored code and documentation only,
      not provider services, trademarks, results, or third-party content.

## 3. Finish the security boundary

- [ ] Publish `SECURITY.md` with the supported-version policy and a real private
      reporting route.
- [ ] Enable GitHub Private Vulnerability Reporting before making the repository
      public; verify that maintainers receive its notifications.
- [ ] Document the exact network destination, query and metadata egress, Windows
      proxy behavior, TLS trust, and lack of cookies and redirects.
- [ ] Document that result content is untrusted and can carry prompt injection.
- [ ] Tell users to keep per-call approval enabled, inspect every query, and
      avoid approval-bypass or autopilot modes.
- [ ] Document that rate limits are per process and reset on restart.
- [ ] Document supported Windows, PowerShell, MCP protocol, and host versions,
      plus the host process-timeout recommendation.
- [ ] Make no claim that read-only annotations, SafeSearch, TLS, or local
      execution guarantees privacy or safety.

## 4. Run release tests

- [ ] Parse every PowerShell file with Windows PowerShell 5.1 and require zero
      syntax errors.
- [ ] Run the no-network JSON-RPC regression suite, including malformed JSON,
      exact property casing, notifications, invalid IDs and arguments, input
      size, and nesting limits.
- [ ] Run adversarial HTML and regular-expression timing tests and confirm the
      shared parse deadline and bounded anchor materialization.
- [ ] Confirm response-size, query-length, result-count, scheme, redirect,
      cookie, and process-local rate limits.
- [ ] Verify that standard output contains JSON-RPC messages only and that logs
      go to standard error without exposing queries or private data.
- [ ] Test initialization, `tools/list`, and `tools/call` in each documented MCP
      host with per-call approval enabled and a process timeout of at least 15
      seconds.
- [ ] Run the LM Studio setup preview test and confirm that it performs no
      writes, makes no network request, embeds the verified versioned path, and
      produces the expected local `lmstudio://add_mcp` confirmation link.
- [ ] Run `scripts\validate-package.ps1` with **no switches** on a non-elevated
      Windows workstation. This is mandatory, not optional. CI always passes
      `-SkipInstallerDryRun`, and the hosted runner is elevated, so the
      installer dry-run path has no automated coverage anywhere. A release
      validated only by a green CI run has never had its installer exercised at
      all.
- [ ] Run a low-volume live smoke test, and stop immediately if the provider
      rejects or throttles access.

## 5. Inspect the release artifact

- [ ] Build from a clean checkout.
- [ ] Remove backups, temporary files, logs, local audit attachments, and test
      output.
- [ ] Remove usernames, absolute home paths, machine-specific comments, secrets,
      and private MCP configuration from public examples.
- [ ] Use placeholders in host configuration examples and explain where users
      must substitute an absolute local path.
- [ ] Keep the version consistent in source, User-Agent, documentation,
      changelog, tag, and archive name.
- [ ] Set the changelog heading to `## <version> - <publication date>` and commit
      that change **before** creating the tag, then create the tag at that
      commit. A tag made while the heading still reads `## Unreleased` violates
      the version-consistency item above, because the tagged tree does not name
      the version it claims.
- [ ] Delete and recreate any tag that was created against an `## Unreleased`
      heading before that tag is pushed. Such a tag records a validated
      pre-publication state, not a release; replace it with a tag on the dated
      commit.
- [ ] Verify that the archive contains only intended source, documentation,
      configuration examples, tests, and license files.
- [ ] On a clean standard-user Windows account, extract the archive and test
      `Install for LM Studio.cmd`; confirm the command shown by LM Studio exactly
      matches the reviewed executable, arguments, timeout, and installed path.
- [ ] Publish a SHA-256 checksum or a signed release, and verify it after
      download on a clean Windows account.
- [ ] If a separate installation archive is attached, run the README's
      verification command against that archive's extracted layout and confirm
      it still works, or document a separate command for it in the same README
      section. The checksum published above and the command a user is told to
      run must describe one verification, not two that can drift apart.
- [ ] Confirm the README states what that verification does not cover. The
      manifest records only the server hash, so any change to which files are
      hashed has to be reflected there.
- [ ] Confirm the install location is not writable by unexpected users and is
      not a junction or other reparse point.

## 6. Prepare maintenance

- [ ] Decide which release line receives security fixes and update
      `SECURITY.md` accordingly.
- [ ] Keep a changelog and identify security-relevant changes clearly.
- [ ] Monitor provider terms, endpoint behavior, and HTML layout for changes.
- [ ] Disable or replace the provider adapter if permission is withdrawn, access
      is rejected, or safe operation can no longer be maintained.
- [ ] Use private advisories for credible vulnerabilities and publish affected
      and fixed versions when a patch is ready.
