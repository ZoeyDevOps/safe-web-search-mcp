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
