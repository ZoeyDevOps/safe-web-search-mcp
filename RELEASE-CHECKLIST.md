# Pre-publication release checklist

Do not publish merely because the code passes its tests. Provider authorization,
source rights, security documentation, and a clean release artifact are separate
release gates.

## 1. Resolve the provider gate

- [ ] Read the current provider Terms of Service, Acceptable Use Policy, and
      partnership or developer guidance from their official pages.
- [ ] Record the review date and the exact provider endpoint or API being used.
- [ ] Obtain written permission covering the intended retrieval and
      re-presentation of results, **or** replace the HTML adapter with an API or
      provider whose terms expressly allow that use.
- [ ] If neither condition is met, do not publish a ready-to-run,
      provider-enabled release or describe the integration as authorized.
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
- [ ] After the provider gate is resolved, run a low-volume live smoke test and
      stop if the provider rejects or throttles access.

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
- [ ] Verify that the archive contains only intended source, documentation,
      configuration examples, tests, and license files.
- [ ] On a clean standard-user Windows account, extract the archive and test
      `Install for LM Studio.cmd`; confirm the command shown by LM Studio exactly
      matches the reviewed executable, arguments, timeout, and installed path.
- [ ] Publish a SHA-256 checksum or a signed release, and verify it after
      download on a clean Windows account.
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
