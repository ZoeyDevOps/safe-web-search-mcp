# Safe Web Search MCP

[![Offline validation](https://github.com/ZoeyDevOps/safe-web-search-mcp/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ZoeyDevOps/safe-web-search-mcp/actions/workflows/ci.yml)

Safe Web Search MCP is a small, dependency-free MCP server for Windows. MCP is a standard way for an AI app to start a separate tool. This server gives a compatible app one tool, `search_web`, which returns search-result titles, URLs, and snippets.

It is designed for cautious, occasional web searches from a local model. It does not turn the model itself into an online model, open result pages, or read full articles.

Here, "safe" means the tool's capabilities and resource use are deliberately bounded. It does not mean search results are verified, current, unbiased, or safe to act on.

> **Provider authorization:** this adapter uses an undocumented HTML results page, and no written provider authorization was sought or obtained. Do not describe it as official, approved, or compliant. The author publishes it as an accepted, documented risk, for the reasoning set out in [PROVIDER-NOTICE.md](PROVIDER-NOTICE.md). That reasoning is specific to the author's jurisdiction and to non-commercial personal use, and it is not a statement by DuckDuckGo. If you fork, redistribute, or use this commercially, form your own view instead of relying on it. Keep the volume low and stop if the provider blocks access. A disclaimer does not grant permission.

## Get the project

**Release status:** no tagged release has been published. The Git command and the Download ZIP instructions below obtain a snapshot of the `main` branch. The `1.0.0` that appears in this file, in the manifest, and in the installation-folder name is the version the server reports about itself; it is not a published release. Under [SECURITY.md](SECURITY.md), the project is pre-release and no stable version is currently supported.

With Git:

```powershell
git clone https://github.com/ZoeyDevOps/safe-web-search-mcp.git
```

Without Git, use the repository's **Code** menu, choose **Download ZIP**, and extract it fully. Do not run anything from inside the ZIP.

A clone carries no Mark of the Web; a downloaded archive does, which is why the next step matters more in that case. Either way, verify what you obtained before running it.

## Verify before the first run

Windows tags downloaded files with the Mark of the Web, and GitHub source archives are downloaded files. Double-clicking `Install for LM Studio.cmd` therefore raises a SmartScreen warning. That is expected for any script obtained from the internet and says nothing about this one in particular. Check the file yourself, then decide.

From the extracted project folder, confirm the server matches the hash recorded in the manifest file:

```powershell
(Get-FileHash -Algorithm SHA256 .\src\server.ps1).Hash -eq (Get-Content .\release-manifest.json -Raw | ConvertFrom-Json).server.sha256
```

`True` means `src/server.ps1` matches the hash recorded in `release-manifest.json` **in the same snapshot you just obtained**. That detects accidental corruption and an inconsistent snapshot. It does not prove who published the files, where the download came from, or that any signature or release is authentic: both halves of the comparison travel together, so anyone who altered one could alter the other. Anything other than `True`, including an error, means stop.

The manifest records that one hash and nothing else, so this check says nothing about `Install for LM Studio.cmd`, [`scripts/setup-lm-studio.ps1`](scripts/setup-lm-studio.ps1), or [`scripts/install.ps1`](scripts/install.ps1) - the three files that actually run when you double-click. Read them before the first run, as you should read [`src/server.ps1`](src/server.ps1) before enabling it.

Only after it prints `True`, clear the download tag on the file you are about to run: right-click the extracted `Install for LM Studio.cmd`, choose **Properties**, tick **Unblock**, and apply. Unblocking the ZIP after extracting it does not clear the tag on the files already extracted from it; unblocking the archive only helps if you do it before extracting. At the SmartScreen prompt itself, the equivalent is **More info**, then **Run anyway**.

If you cannot run that check, or would rather not, do not run the installer.

## Quick install for LM Studio

From a trusted, extracted copy of the project:

1. Double-click [`Install for LM Studio.cmd`](Install%20for%20LM%20Studio.cmd).
2. The local setup verifies the server and copies it into your Local AppData folder.
3. LM Studio opens its own **Add MCP Server** confirmation. Review the displayed command and approve it.
4. Start a tool-enabled chat, ask for one search, review the query, and choose **Allow once**.

The setup does not download packages, change `PATH`, or silently rewrite `mcp.json`. It creates the LM Studio install link locally after it knows the verified server's absolute path.

If you prefer a terminal, the same setup is one command from the project folder:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\setup-lm-studio.ps1
```

To inspect the planned path and generated LM Studio configuration without installing or opening anything, add `-WhatIf`.

## What it does

- Sends a query only to DuckDuckGo's HTTPS HTML search endpoint.
- Forces strict SafeSearch with `kp=1`.
- Returns at most six result titles, URLs, and snippets.
- Labels the output as unverified snippets, records when the search completed in UTC, and states that source freshness is unknown.
- Does not follow HTTP redirects or open returned URLs.
- Does not retain or send cookies.
- Exposes no file, shell, browser-control, account, or credential tool.
- Applies limits to input size, nesting, query length, result count, response size, parsing time, network time, and call rate.
- Marks returned web content as untrusted data.

The process still runs as your Windows user and can make the network request described above. Review the source before enabling it, do not run it as Administrator, and keep per-tool approval enabled where your host offers it.

## Privacy and provider limitations

Every search sends the full query, connection metadata, and the tool's User-Agent outside your computer. The provider sees the connecting IP address, which may be your public IP or a proxy's address. A configured Windows proxy also participates in the connection and may inspect traffic if its certificate authority is trusted. Never put passwords, tokens, private names, unpublished work, or other sensitive information in a query.

Your MCP host is a second, separate path off the device, and this server has no say over it. If the host or its model runs in the cloud, then your prompts, the queries it decides to send, everything this tool returns, and the surrounding conversation may be transmitted, logged, and retained under that host's own policy, not this project's. Running a local `stdio` server does not make the host or the model local, offline, or private; it only means this particular tool runs on your machine. A local model in LM Studio and a cloud-backed assistant behave very differently here even though the server is identical. Check the privacy terms of whichever host you install this into.

This project uses DuckDuckGo's unversioned HTML results page, not a supported search API, and is not affiliated with DuckDuckGo. A layout change, rate limit, bot check, TLS-fingerprint block of automated clients, outage, or provider-policy change can make searches fail. Use it for occasional personal searches, do not automate high-volume use, and stop if the provider blocks it. Strict SafeSearch reduces risk but cannot guarantee that every title, URL, or snippet is suitable or accurate. Read [PROVIDER-NOTICE.md](PROVIDER-NOTICE.md) before redistribution.

Search results can contain misleading text, advertising, manipulation, or prompt-injection attempts. Treat every returned field as data, never as an instruction. The server never visits a result URL for you. Search operators such as `site:` and `OR` are interpreted by the provider and may not be honored; always inspect the returned domains.

The warnings in the result are advisory. This server cannot force a model to avoid hallucinations, identify trustworthy domains, or use another enabled tool responsibly. Search snippets alone are not suitable for medical, legal, financial, safety-critical, or other high-stakes decisions, and they are not a live market-data feed.

## Requirements and compatibility

- Windows with Windows PowerShell 5.1 and .NET Framework.
- An MCP host that can start a local server over standard input/output (`stdio`).
- A model and host mode that support tool calls.

Server version 1.0.0 supports MCP protocol revisions `2025-11-25` and `2025-06-18`. It has been verified with LM Studio 0.4.20 Build 1, which initiates with `2025-11-25`.

This is a deliberately small, batch-free MCP implementation rather than a full MCP SDK. It implements initialization, `ping`, `tools/list`, `tools/call`, and one-way notifications. It does not advertise resources, prompts, sampling, elicitation, tasks, logging, or other optional MCP capabilities. A host with no supported protocol revision in common may refuse the connection.

Templates are included for LM Studio, Claude Desktop, VS Code, and Cursor. LM Studio is the verified target. The other templates use those hosts' conventional local-stdio formats, but every host version is not continuously tested.

## Manual install and other hosts

The quick LM Studio setup above is recommended for most users. The steps below are for manual review, custom install locations, and other MCP hosts.

### 1. Install the verified local copy

Obtain the project from a source you trust, extract it fully, and do not run it from inside a compressed archive. The installer makes its own stable, versioned copy; after setup succeeds, the extracted source folder is no longer needed for normal use. Read the provider note above and [PROVIDER-NOTICE.md](PROVIDER-NOTICE.md) before redistributing this project or using it commercially.

Before enabling it, review [`src/server.ps1`](src/server.ps1). The project has no runtime package-install step.

Preview the host-neutral local installer from the repository root in a normal, non-administrator terminal:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\install.ps1 -WhatIf
```

Then run it without `-WhatIf`:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

By default, the installer creates a versioned copy under `%LOCALAPPDATA%\Programs\SafeWebSearchMCP\1.0.0`. It does not edit a host configuration, change `PATH`, download anything, or update itself. Its result includes `ServerPath`, `SHA256`, and whether that exact version was already installed. Copy the reported `ServerPath` into the host template in the next step.

You can choose another absolute destination with `-InstallRoot`, but it must be either a directory that does not exist yet or one this installer created earlier. The installer applies its restricted permissions only to a directory it creates itself; it never repairs, re-owns, or replaces the permissions of a directory that was already there. Point it at an existing folder of your own and it refuses and changes nothing, rather than rewriting that folder's access control. UNC paths are not supported. You may also skip the installer and point a host directly at `src/server.ps1`; in that case, the source folder must remain in the same location.

### 2. Prepare a host configuration

Choose the template in [`configs`](configs), copy its server entry into your host's configuration, and replace this value with the real absolute path:

```text
C:/REPLACE_WITH_ABSOLUTE_PATH/safe-web-search-mcp/src/server.ps1
```

Forward slashes work in a Windows JSON path and avoid escaping. If you use backslashes instead, write each one twice, for example `C:\\Tools\\safe-web-search-mcp\\src\\server.ps1`.

The templates use the normal Windows PowerShell executable path. If Windows is installed on another drive, run the following and copy the trusted path it returns into the template:

```powershell
(Get-Command powershell.exe).Source
```

The `-ExecutionPolicy Bypass` argument applies to the child server process. It does not elevate privileges. It is present so a reviewed local script can start under restrictive per-machine defaults.

Do not replace an existing configuration file wholesale. Merge only the `safe-web-search` entry into its existing `mcpServers` or `servers` object.

### 3. Configure LM Studio manually

1. Open LM Studio's **Program** tab.
2. Choose **Install > Edit mcp.json**.
3. Merge the entry from [`configs/lm-studio.template.json`](configs/lm-studio.template.json).
4. Replace the placeholder server path and save the file.
5. Reload MCP servers or restart LM Studio.
6. Confirm that `search_web` appears in the tool list.

The [official LM Studio MCP guide](https://lmstudio.ai/docs/app/mcp) explains where `mcp.json` is managed. The LM Studio template sets `timeout` to `15000` milliseconds. Keep tool confirmation enabled and choose a one-time approval for each search when that option is available. Review the exact query before approving it.

Updating an offline model's context with search results does not change the model's training cutoff. It only gives that conversation the returned snippets.

### Other hosts

| Host | Template | Where to add it |
| --- | --- | --- |
| Claude Desktop | [`claude-desktop.template.json`](configs/claude-desktop.template.json) | Merge into the local Claude Desktop configuration, commonly `%APPDATA%\Claude\claude_desktop_config.json`, then fully restart Claude Desktop. |
| VS Code | [`vscode.template.json`](configs/vscode.template.json) | Run **MCP: Open User Configuration**, or merge into `.vscode/mcp.json` for one workspace. |
| Cursor | [`cursor.template.json`](configs/cursor.template.json) | Merge into `%USERPROFILE%\.cursor\mcp.json`, or `.cursor/mcp.json` for one project. |

Host interfaces and approval behavior change over time. Review the displayed command and tool arguments before trusting the server. Leave auto-run or blanket approval disabled for a network-facing tool unless you deliberately accept that risk. MCP tool annotations such as `readOnlyHint` are descriptive hints, not an operating-system sandbox.

## Use it

1. Start a new chat with a model that supports tools.
2. Ask for one web search, for example: `Search the web once for the latest LM Studio release notes.`
3. Read the query shown by your host. Choose **Allow once** only if it contains no private information.
4. Treat the returned text as search-result snippets. This server does not open or verify the linked pages.

For models that accept a system prompt, set the following. It is not an enforcement boundary. Mechanical, checkable rules of this kind were tested and observably changed the answer; the notes after the prompt say which wordings were tested and which were corrected afterwards:

> You have a web search tool. It returns text snippets only. It never opens or reads the linked pages.
>
> Follow these rules exactly:
>
> 1. Every factual claim you take from search results must begin with "Unverified snippet:" and end with the source domain in parentheses.
> 2. Never describe search content as "latest", "current", "today's", or "this week's". The tool cannot confirm recency.
> 3. search_completed_at_utc is the UTC time this server finished the search, taken from the clock of the machine it ran on. It is not a publication date and does not show that any result is current. Do not override it with your own sense of today's date; you have no way to check that. If the host or system supplies a current date, use that one and say the two disagree. Otherwise use its calendar date as a provisional working date, and say it came from the server machine's clock.
> 4. State explicitly in your answer that you did not open any of the pages.
> 5. If a claim appears in only one result, label it "single unverified result". If several results appear to trace back to one underlying source, say it is not independently corroborated. This tool never opens a page, so no primary source has been checked in any case; say so rather than implying one was.

In one documented test on a 35B-class local model, mechanical wordings of these rules changed the answer where a softer prompt had not: under the softer version the model still presented content-farm text as fact and described it as "the latest updates". The former rule 3 was followed. The former rule 5 was applied inconsistently, so do not rely on its label reaching every claim that warrants it.

Both of those wordings were replaced because they were inaccurate, not because they failed. The former rule 3 asserted that `search_completed_at_utc` was the correct current date and overrode anything the model believed; the former rule 5 called blogs and news aggregators low-quality. A clock is not an authority on the date, and a source's format does not decide whether it is reliable. Being obeyed is not a reason to keep an instruction that is false. The replacements have not been through the same comparison.

That test also observed the model dismissing the server timestamp as simulated and answering about the wrong period, which is why rule 3 still tells it not to substitute its own sense of the date. One model, one question, one run: a documented observation, not a guarantee.

You normally do not start `server.ps1` yourself; the AI host starts it when needed. If you run it in a terminal and it appears idle, it is waiting for MCP messages on standard input. Press `Ctrl+C` to stop it.

## Update or remove it

To update LM Studio, obtain and review a newer snapshot, extract it, then run `Install for LM Studio.cmd` again. It installs into a new versioned folder and opens LM Studio's confirmation with the new path. Test the new version before deleting the old folder. Other hosts can be updated by changing their configured server path manually.

To remove it, first delete the `safe-web-search` entry from every host configuration and restart those hosts. Then use File Explorer to delete the exact installed version folder reported by the installer. Do not delete the shared `%LOCALAPPDATA%\Programs` folder.

## Tool reference

### `search_web`

Searches the public web and returns a compact result list.

| Input | Type | Required | Limits |
| --- | --- | --- | --- |
| `query` | string | Yes | 1-300 characters; do not include secrets or private data. |
| `max_results` | integer | No | 1-6; defaults to 5. |

The result contains:

- the original query and provider name;
- `search_completed_at_utc`, which is the local search completion time, not the publication time of any source;
- `content_kind: unverified_search_result_snippets`, `freshness: unknown`, and `result_pages_opened: false`;
- the result count and an array of `title`, `url`, and `snippet` values; and
- usage and security notices.

The provider defines query syntax. Advanced operators such as `site:` and `OR` may be ignored or interpreted differently, so check every returned URL.

The server permits at most 10 searches per minute and 60 per hour for one running process. It also caps the provider response at 2 MiB. These limits are local safeguards, not a service guarantee. If the tool reports a rate limit, stop retrying or rephrasing the query and wait.

Example request to your model:

> Use `search_web` once to find the current release notes for LM Studio. Show the result URLs and distinguish snippets from verified page content.

Because this server cannot open pages, ask for claims to be described as search-result snippets unless another trusted tool verifies the source page.

## Troubleshooting

### The server does not appear

- Validate that the host configuration is JSON and that you merged into the correct top-level object. VS Code uses `servers`; the other included templates use `mcpServers`.
- Confirm that the server path is absolute and points to `src/server.ps1`.
- Run `(Get-Command powershell.exe).Source` and verify the configured executable.
- Fully restart hosts that do not reload MCP configuration automatically.
- Check that the selected model and chat mode support tools.

### The server starts and immediately stops

Open the host's MCP or developer log. Standard output is reserved for JSON-RPC messages, so diagnostics belong on standard error. Do not add `Write-Host` or ordinary output statements to the protocol path.

Run the offline checks from the repository root:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\run-offline.ps1
```

For the full package validation:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\validate-package.ps1
```

### Searches time out or report a provider-page error

- Check the Windows network and proxy configuration.
- Wait before retrying if the local rate limit was reached.
- Do not put the tool in a retry loop; the provider may be rate-limiting or blocking automated traffic.
- The provider's HTML layout may have changed. Check existing issues before reporting a parser problem.
- A blank or unrecognized page fails closed. The server deliberately does not guess whether it means genuine zero results, a block, or a layout change.

When sharing logs, remove search queries, usernames, local paths, proxy details, and other private information.

## Development

Runtime code lives in `src/server.ps1`. Offline tests live under `tests`, and package-maintenance scripts live under `scripts`.

Changes should preserve these boundaries:

- one read-only search tool;
- no result-page fetching;
- no file, shell, browser, account, or credential capability;
- fixed outbound search destination;
- bounded input, output, time, and rate;
- JSON-RPC only on standard output;
- no runtime dependency downloads.

See [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a change. Change history is in [CHANGELOG.md](CHANGELOG.md). Report security issues privately using [SECURITY.md](SECURITY.md), and follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Anyone forking or re-hosting the project should also review [GITHUB-SETUP.md](GITHUB-SETUP.md).

## License

See [LICENSE](LICENSE). The license covers project-authored code and documentation, not the provider's service, runtime search-result content, linked websites, or trademarks; see [PROVIDER-NOTICE.md](PROVIDER-NOTICE.md).
