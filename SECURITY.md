# Security policy

This project is a small local MCP server that sends search queries to an
external provider and returns untrusted web content. Its narrow tool surface is
intentional, but "read-only" does not mean "no risk": queries leave the device,
provider output can contain prompt injection, and the server runs with the same
operating-system rights as its MCP host.

## Supported versions

Only the latest tagged release is intended to receive security fixes. If there
is no tagged release, the repository is pre-release and no stable version is
supported. Installed copies and older snapshots do not update automatically.

## Reporting a vulnerability

GitHub Private Vulnerability Reporting is enabled for this repository. Open the
repository's **Security** page, choose **Report a vulnerability**, and describe
the issue there. That route is private between you and the maintainer.

Do not report a suspected vulnerability in a public issue, and do not put
exploit details, private data, or secrets in one. This project does not publish
a security email address, so this file does not invent one. If you cannot reach
the Security page at all, open a public issue that asks for a private reporting
route and includes no vulnerability details.

Please include, when safe to do so:

- the affected version, commit, or file hash;
- the Windows, PowerShell, and MCP-host versions;
- a minimal reproduction using non-sensitive data;
- the expected and observed behavior;
- the likely impact and any suggested mitigation; and
- logs with queries, usernames, paths, tokens, and other private data removed.

There is no guaranteed response-time service level. Maintainers should handle a
credible report privately, avoid premature disclosure, prepare and test a fix,
and publish an advisory with the affected and fixed versions when appropriate.

## Security-relevant reports

Examples include:

- making the server contact an origin other than its fixed search provider;
- following redirects, retaining cookies, or opening returned result URLs;
- unexpected filesystem, shell, browser-control, account, or credential access;
- JSON-RPC framing or standard-output injection;
- bypassing input, nesting, response-size, result-count, rate, or time limits;
- regular-expression or parser denial of service outside the documented bounds;
- unsafe handling of URLs or HTML that produces code execution; or
- disclosure of queries or other sensitive data beyond the documented network
  request and operating-system proxy behavior.

Provider availability, ranking, result accuracy, ordinary third-party web
content, and an LLM choosing to follow untrusted result text are important known
risks, but are not by themselves vulnerabilities in this server. A deterministic
path from provider text to an unauthorized tool action may still be a valid
security report and should be described carefully.

## Safe operation

- Inspect the exact server command before allowing an MCP host to run it.
- Keep per-call approval enabled and review the query before it leaves the
  device. Do not use approval-bypass or autopilot modes.
- Do not place secrets, personal data, internal hostnames, or proprietary text in
  a search query.
- Treat every title, URL, and snippet as untrusted data, never as instructions.
- Treat `search_completed_at_utc` only as the time this server finished the
  search. It does not establish when a source was published or whether a snippet
  is current, complete, accurate, or live data.
- Do not use snippets alone for medical, legal, financial, safety-critical, or
  other high-stakes decisions. The result warnings are advisory; this server
  cannot force a host or model to follow them or safely coordinate other tools.
- Use a host process timeout of at least 15 seconds and terminate a stuck child
  process. Client cancellation alone is not a security boundary.
- Remember that rate limits are in memory and per process; restarting or running
  multiple instances resets or multiplies them.
- Review the configured Windows proxy and trusted certificate authorities. A
  trusted TLS-inspecting proxy can observe queries.
- Install the script in a directory writable only by the intended user and
  administrators, and verify release hashes before replacing it.

See [PROVIDER-NOTICE.md](PROVIDER-NOTICE.md) for the separate provider, content,
terms, and trademark boundary.
