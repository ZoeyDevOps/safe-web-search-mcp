# Provider, content, and trademark notice

## Provider authorization: an accepted, documented risk

The current adapter retrieves and re-presents titles, links, and snippets from
DuckDuckGo's non-JavaScript HTML results page. It does not use a documented
search-results API.

**No written provider authorization was sought or obtained.** None was
requested, and nothing in this repository is evidence of permission.

The author has chosen to publish anyway, accepting and documenting that risk
rather than resolving it. That decision rests on the author's own reasoning:

- that collecting publicly available search results is lawful in the author's
  jurisdiction; and
- that comparable MIT-licensed MCP servers parse the same HTML results page and
  remain publicly available, and that the author is aware of no legal action
  taken against projects of that kind.

The second point carries much less weight than it may appear to. The provider
applies technical measures to this endpoint to limit automated access. An
absence of legal challenge is therefore not evidence of acquiescence: it is
exactly what the loss-of-access consequence described below looks like in
practice. The provider enforces here by refusing traffic, not by suing, so quiet
is not consent.

Nor should that observation be generalized. It is not a claim about how many
such projects exist, and not a claim that comparable servers use HTML parsing as
a rule. At least one widely referenced alternative appears to use an official
API instead, which is a different thing and a permitted one. Reading a broad
pattern into a narrow observation would be the same error this project's own
`usage_notice` warns users about.

Both points are the author's reasoning and nothing more. Neither is a statement
by, or on behalf of, Duck Duck Go, Inc., and neither may be read as approval,
authorization, compliance, or endorsement. Do not describe this adapter as
approved, official, authorized, or compliant. A disclaimer does not override
provider terms or supply missing permission. This notice records a position
taken; it is not legal advice or a conclusion about how a court or a provider
would view the matter.

## Lawfulness and terms are separate questions

Whether collecting publicly available data is lawful is a different question
from whether doing so is consistent with a provider's terms of service. A
practice can be lawful and still conflict with terms. The reasoning above speaks
to the first question only. It does not resolve the second, and the terms
recorded below apply on their own footing regardless.

The practical consequence of a terms conflict is normally loss of access rather
than a legal proceeding: the provider throttles the client, presents a bot
check, or blocks it. That is why this project is built to stay small and
well-behaved, and why the following are requirements rather than suggestions:

- Keep request volume low. The server limits itself to 10 searches per minute
  and 60 per hour for each running process.
- Use it for occasional personal searches. Do not automate high-volume use.
- Do not evade access controls, blocks, bot checks, or rate limits.
- Stop using the adapter if the provider rejects, throttles, or blocks access.

Weakening those limits does not just increase load; it removes the main reason
the position above is tenable at all.

An MCP search server could reasonably do more than this one does. Fetching and
parsing the pages behind the results it returns is well within the design space,
as is returning far more results per query. This one does neither. It reads a
single results page, fetches no page behind any result, and returns at most 6
results, from queries of at most 300 characters, within the per-process limits
above. That restraint is part of the position taken here, not incidental to it.

## If you fork, redistribute, or use this commercially

The reasoning in the first section is the author's own, reached for one
jurisdiction and for non-commercial personal use. It is not a general clearance,
it is not advice, and it does not travel with the code.

Anyone forking, redistributing, deploying, or commercializing this project must
form their own view and take their own advice. That obligation is unconditional.
It does not depend on establishing that your situation differs from the
author's, and it is not discharged by concluding that it looks similar. The
things that decide the question are yours to assess: the law that applies to
you, the volume and pattern of your requests, whether you operate the adapter on
behalf of other people, and whether you charge for the result.

The MIT License grants rights in this project's code and documentation. It
grants nothing in respect of a provider's service or content, and it is not a
substitute for that assessment.

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
or commercial distribution raises an authorization question that this project
has accepted rather than resolved. Only the provider or qualified legal counsel
can give project-specific guidance.

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
