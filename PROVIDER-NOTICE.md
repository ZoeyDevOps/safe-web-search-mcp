# Provider, content, and trademark notice

## Public-release gate

The current adapter retrieves and re-presents titles, links, and snippets from
DuckDuckGo's non-JavaScript HTML results page. It does not use a documented
search-results API. No written provider authorization is included in this
repository.

Do not describe this adapter as approved, official, authorized, or compliant.
Before publishing or commercializing a ready-to-run provider-enabled release,
either:

1. obtain written permission that covers the intended retrieval and
   re-presentation of results; or
2. replace the adapter with an API or provider whose terms expressly permit the
   intended use.

A disclaimer does not override provider terms or supply missing permission. This
notice records the project's release boundary; it is not legal advice or a
conclusion about how a court would interpret those terms.

## Provider terms

Use of DuckDuckGo's service is subject to its then-current official policies,
including:

- [DuckDuckGo Terms of Service](https://duckduckgo.com/terms)
- [DuckDuckGo Acceptable Use Policy](https://duckduckgo.com/acceptable-use)
- [DuckDuckGo partnership guidance](https://duckduckgo.com/duckduckgo-help-pages/company/partnerships)

At the time this notice was prepared, the Acceptable Use Policy prohibited
framing, inline linking, or similarly displaying any portion of the service
within another service, and prohibited selling or reselling any portion of the
service. The partnership guidance also asked developers not to put DuckDuckGo
results inside another application's frame except for the browser-integration
case it describes. Because policies can change, review the live pages rather
than relying on this summary.

The MCP adapter re-presents provider result fields inside an AI host, so public
or commercial distribution raises an unresolved authorization question. Only
the provider or qualified legal counsel can give project-specific guidance.

Do not evade access controls, blocks, or rate limits. Stop using the adapter if
the provider rejects access.

## License boundary

The MIT License in this repository applies only to the original source code and
associated documentation authored for this project. It does not license or
grant rights in:

- DuckDuckGo's service, pages, data, or trademarks;
- search-result titles, snippets, links, or other material retrieved at runtime;
- linked websites or content owned by third parties; or
- any provider or third-party terms that apply independently of this project.

Permission to copy, modify, or sell this project's code is not permission to use
or resell a provider's service or content.

## Independence and trademarks

This is an independent, unofficial project. It is not affiliated with, endorsed
by, sponsored by, or maintained by Duck Duck Go, Inc.

DuckDuckGo and its related names, logos, trade dress, and other brand elements
are trademarks of Duck Duck Go, Inc. This project grants no trademark rights.
Keep the project title generic, use the provider name only when needed to explain
compatibility or attribution, and do not use DuckDuckGo logos or Dax artwork.

Plain-text attribution such as `provider: DuckDuckGo HTML` does not imply
endorsement and should link to the provider's homepage where practical.

## Runtime content and privacy

Search queries and connection metadata leave the device. The provider receives
the query and can observe connection information; a configured system proxy may
also observe traffic, including through trusted TLS inspection. Do not submit
secrets, personal data, internal names, or proprietary information.

Results originate from external services and third-party websites. They may be
inaccurate, incomplete, harmful, unavailable, or subject to others' rights.
SafeSearch reduces some explicit content but is not a guarantee. Treat all
titles, URLs, and snippets as untrusted data and never as instructions.
