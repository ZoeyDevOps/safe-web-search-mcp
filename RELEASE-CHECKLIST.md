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
- [ ] Record the review date and the exact provider endpoint or API being used,
      in the review record under **Provider terms** in
      [PROVIDER-NOTICE.md](PROVIDER-NOTICE.md). Both are recorded there. Write
      the date the pages were actually read, never the date of the release, and
      never a date carried over from the previous one.
- [ ] Re-read those pages on the day the release is tagged, unless the tag lands
      on the same calendar day as the last reading. Recording a reading from days
      earlier as this release's review is carrying the date forward with extra
      steps, which is the practice this section exists to prevent. Re-reading is
      three page fetches, so decide this in advance rather than leaving it to
      whoever wants to tag. Any date this changes must land in the pre-tag commit
      required by section 5, not after the tag.
- [ ] Date each limb of the reasoning to the day that limb was actually tested,
      never to one date covering all of them. Re-reading the provider's pages
      does not re-test whether comparable projects still parse the same endpoint,
      so a single date spanning both claims more than was done. Two dates that
      are honest beat one that is tidy.
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
- [ ] Enable GitHub Private Vulnerability Reporting immediately after making the
      repository public, in the same sitting; verify that maintainers receive
      its notifications. It cannot be done beforehand, because the setting does
      not exist on a private repository. Until it is on, `SECURITY.md` has no
      private route to point a reporter at.
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
- [ ] Test initialization, `tools/list`, and `tools/call` in the verified MCP
      host with per-call approval enabled and a process timeout of at least 15
      seconds. LM Studio is that host, and its template is the only one that
      carries a timeout setting. Do not add a timeout key to the others to
      satisfy this line: a field the host may ignore would claim a control the
      project does not have.
- [ ] Confirm the remaining templates still name the reviewed `powershell.exe`
      path, the exact argument list, and the `REPLACE_WITH_ABSOLUTE_PATH`
      placeholder, in whichever shape their host uses - `mcpServers` for Claude
      Desktop and Cursor, `servers` with `"type": "stdio"` for VS Code. They ship
      as conventional local-stdio formats and are not host-tested. Neither this
      list nor the README may imply otherwise. Package validation asserts all of
      that, including that no template but LM Studio's carries a timeout, so this
      item is discharged by running the validator rather than by reading four
      files. Not being host-tested is the reason to check their contents by
      machine, not a reason to leave them unchecked.
- [ ] Before moving any host into the verified set, run the full test above
      against it: all three calls, per-call approval, and a timeout of at least
      15 seconds. Shipping a template is not verifying a host, and the verified
      set grows by testing only, never by assumption.
- [ ] Run the LM Studio setup preview test and confirm that it performs no
      writes, makes no network request, embeds the verified versioned path, and
      produces the expected local `lmstudio://add_mcp` confirmation link.
- [ ] Run `scripts\validate-package.ps1` with **no switches** on a non-elevated
      Windows workstation. This is mandatory, not optional. CI always passes
      `-SkipInstallerChecks`, and the hosted runner is elevated, so everything
      that drives the installer has no automated coverage anywhere. A release
      validated only by a green CI run has never had its installer exercised at
      all. That one command is the whole installer gate: with no switches it
      runs the LM Studio setup preview and the install-root ACL suite as part of
      the validation, so neither has to be remembered separately. It refuses to
      start from an elevated terminal rather than skipping them quietly.
- [ ] Confirm the ACL suite actually ran in that output rather than assuming it.
      It proves the installer refuses a pre-existing `-InstallRoot` instead of
      rewriting its permissions, and that a refused root is left byte-for-byte
      and ACL-for-ACL unchanged. A custom root must be a directory that does not
      exist yet or one this installer created; the installer never repairs
      permissions on an arbitrary existing directory, and unsafe roots fail
      closed. Seeing `SKIP: installer checks omitted` means the switch was
      passed and this gate is still open.
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
- [ ] Set the changelog heading to `## <version> - <publication date>`, record
      under it what the release was verified against, and commit both **before**
      creating the tag, then create the tag at that commit. A tag made while the
      heading still reads `## Unreleased` violates the version-consistency item
      above, because the tagged tree does not name the version it claims.
- [ ] Write that verification record only after every gate in this list has
      passed, never as each one closes. A record written early states an
      incomplete set of checks in the same voice as a complete one, and nothing
      later distinguishes them. Name the environment, the host and its version,
      and the checks that actually ran. Cite the manifest for the server hash
      rather than copying it: the version-consistency item above covers versions,
      not hashes, so a second copy of a hash has nothing checking it and a
      truncated one cannot be verified while still looking as though it could.
- [ ] In that same pre-tag commit, correct every other statement that is written
      for a repository with no release. The changelog heading is not the only
      place the tree describes its own release state, and a tag is the moment
      all of them stop being true together. `README.md` opens with a **Release
      status** paragraph asserting that no tagged release has been published and
      that `1.0.0` is only what the server reports about itself; both halves are
      false in the tree the tag points at. `PROVIDER-NOTICE.md` carries the third:
      if section 1's re-reading moved the provider review date, that new date has
      to be in this commit too, or the tag points at a tree whose review record
      shows an earlier reading than the review this release actually had.
      `SECURITY.md` states its supported-version rule conditionally and needs no
      edit here.
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
- [ ] Do not publish a checksum for the **Source code (zip)** or **Source code
      (tar.gz)** links GitHub generates on the Releases tab. GitHub does not
      guarantee those archives are byte-stable, and recommends uploading an
      archive of your own where consistent checksums matter; a change to its
      archive tooling has already invalidated published hashes across the
      ecosystem once. A checksum that can turn false while nobody touches the
      release is worse than none, because it makes a routine tooling change look
      like tampering to the one user careful enough to check. Either hash an
      archive attached to the release, or publish no archive checksum and let
      the README's in-tree manifest check stand as the only verification
      offered.
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
