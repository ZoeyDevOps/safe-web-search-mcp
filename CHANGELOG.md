# Changelog

Notable user-visible changes are recorded here. Versions follow Semantic Versioning.

## Unreleased

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
