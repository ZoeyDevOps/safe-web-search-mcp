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

The review recorded below found a further reason the second point cannot carry
the weight its wording invites. At least one comparable MIT-licensed server,
checked in its source rather than in its description, does query this same HTML
results page, so the observation is not empty. That same source also records the
endpoint returning an empty HTTP 202, or a 403, to clients whose TLS fingerprint
it declines, and it retries such refusals through a library that impersonates a
browser's TLS handshake. Continued availability and continued function are
therefore two different facts about a project, and only the first is what the
second point claims. Function sustained by presenting a client the provider
would otherwise refuse evidences a bypass that worked, not a provider's
tolerance, so it cannot be borrowed as support here. The second point is
therefore weaker than when it was written, and weaker than the paragraph above
already allowed it to be. It is left standing because the decision was in fact
made partly on it, and striking it now would misrepresent what that decision
rested on - not because it still carries what it was offered to carry.

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

All four bind. What differs between them is only whether code can enforce them,
and it is worth being exact about which can. The third is implemented rather than
undertaken: the server identifies itself as
`SafeWebSearchMCP/1.0.0 (+local MCP server)` rather than presenting itself as a
browser, and removing that string fails the package validation. An HTTP 202, 403,
or 429 ends the request, reported as `Search provider refused or deferred the
request` and recording that `No bypass or automatic retry was attempted`, and a
blank or unrecognized page fails closed instead of being guessed at. The honest
identifier is a statement of how this client behaves, never an explanation of why
it is served. On the evidence set out in the first section, refusal here has been
observed to turn at least in part on the TLS fingerprint - which this project
neither selects nor alters - with plain 403s and challenge pages alongside it. An
honest User-Agent buys no exemption from any of that.

The first is enforced in code as well. The fourth is only partly addressed: the
server surfaces a refusal and tells the caller not to retry immediately, but it
has no cooling-off breaker that would stop it being asked again, and such a
breaker could be built, so whether use actually stops is left to the operator.
The second is out of reach of code entirely, describing as it does how a person
chooses to use the tool. Being unenforceable makes neither of those two optional.

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

At the time of the reading recorded below, the Acceptable Use Policy prohibited
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

### Review record

The release checklist requires this position to be re-examined before every
release. That is only meaningful against a fixed point, because the thing being
checked is whether the facts moved.

- Endpoint in use: `https://html.duckduckgo.com/html/`, retrieved by HTTPS GET
  with strict SafeSearch (`kp=1`), no redirects, and no cookies. No documented
  search API is used. Package validation asserts that this endpoint appears
  exactly once in the server source, so a change of destination cannot pass
  unnoticed.
- Last reading of the live pages linked above: 2026-08-15, for the 1.0.0
  release. The Terms of Service displayed `Last updated: 01-07-2025`; the
  Acceptable Use Policy and the partnership guidance displayed no date at all.
  Those strings are recorded exactly as shown, unreformatted and uninterpreted,
  so that a later reviewer can compare them against the live pages character for
  character rather than against someone's reading of them.

What that reading found, recorded so a later reviewer can tell whether the facts
moved rather than having to guess:

- Both Acceptable Use Policy clauses this notice rests on were still present and
  still in these words: users agree not to "Frame, inline link, or similarly
  display any portion of the services within another service", and not to "Sell
  or resell any portion of the services".
- The partnership guidance still asked developers not to include DuckDuckGo
  search results "in any sort of frame", and still excepted browser integration.
- Neither document addressed automated access, scraping, crawling, or request
  volume in those terms. Record that as an observation about what the pages said
  on the date above, and as nothing else. It is not a finding in this project's
  favour and must not be cited as one: an absent prohibition is not a permission,
  it narrows none of the clauses that are present, and it supplies none of the
  authorization recorded above as missing. The reason the first section gives for
  not reading silence as consent - that the provider enforces here by refusing
  traffic, not by suing - applies with equal force to silence in the terms
  themselves: enforcement that is technical rather than legal is not the kind
  that an absent written prohibition tells you much about.
- Two further Acceptable Use Policy clauses bear directly on the restraint
  described earlier in this notice: users agree not to "Interfere with or disrupt
  the integrity or performance of the services", and not to "Attempt to access,
  interfere with, or connect to the services and/or any computer without
  authorization". The low request limits and the stop-if-blocked instruction are
  the practical answer to those two. That is a further reason they are
  requirements rather than tuning knobs.

The second reason given in the first section - that comparable MIT-licensed
servers parse the same results page and remain publicly available - was re-tested
on 2026-08-15, being the limb most exposed to change. It moved, and what its
moving means for the reasoning is set out in that first section rather than
repeated here. Recorded here is only how it was checked and what that
established: one comparable project, read in its source rather than in its
description, queries this same endpoint, and that same source documents both the
refusals and the impersonating transport described there. One project verified in
source is the whole of it - not a population, and not a survey. No legal action
against projects of this kind was found, which on the enforcement pattern
described above adds nothing either way.

Each limb carries its own date above, because re-reading the provider's pages
does not re-test whether comparable projects still parse this endpoint. One date
spanning both would claim more than was done, so where the two were checked on
different days they are recorded on different days.

Re-read those pages and re-test both limbs at each release instead of carrying
these dates forward. A summary of another party's terms with no date attached
cannot be told apart from a current one, which is the failure it invites: quoting
it back years later as though it still described the live pages. Where a fact has
moved, reopen the position that rested on it rather than editing this summary to
match. A record that only ever absorbs new facts has stopped being a check on
them.

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
