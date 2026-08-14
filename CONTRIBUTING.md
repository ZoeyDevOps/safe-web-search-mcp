# Contributing

Thank you for helping improve Safe Web Search MCP. The project is intentionally small, Windows-focused, and conservative about new capabilities.

## Before opening an issue

- Search existing issues first.
- Do not post vulnerabilities publicly. Follow the private reporting instructions in `SECURITY.md`.
- Remove queries, usernames, local paths, proxy details, and other private information from logs.
- Include the Windows version, PowerShell version, MCP host and version, model or chat mode, and the smallest reproducible example.

Provider outages, rate limits, bot checks, and HTML changes are expected operational risks. Confirm that a problem is repeatable before reporting it as a parser defect.

## Development setup

Use a normal, non-administrator Windows account with Windows PowerShell 5.1. The server has no runtime package dependencies.

Run the offline protocol suite from the repository root:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\run-offline.ps1
```

Run the complete package validation before submitting a pull request:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\validate-package.ps1
```

That validation does not exercise the installer's access-control behavior. If you change `scripts\install.ps1`, also run the suite that guards it:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\install-root-acl.ps1
```

It proves the installer refuses a pre-existing `-InstallRoot` rather than rewriting that directory's permissions, and that a refused root is left unchanged. Nothing else runs it. CI cannot: the hosted runner is elevated, the installer refuses to start elevated, and so this behavior has no automated coverage anywhere. A non-administrator terminal is required for the same reason.

Routine tests must not send live queries to DuckDuckGo. Use synthetic fixtures and bounded inputs. A manual provider check should be rare, explicit, and never contain private data.

## Design boundaries

Changes must preserve the project's narrow security model:

- expose only the read-only `search_web` tool;
- never open or fetch a returned result URL;
- do not add file, shell, browser-control, account, or credential access;
- keep outbound requests limited to the documented search endpoint;
- keep redirects and cookies disabled;
- keep input, response, parsing, timeout, and rate limits;
- write protocol messages only to standard output and diagnostics only to standard error;
- do not add runtime dependency downloads.

A proposal that expands these boundaries should begin as a design issue and explain the threat model, user benefit, and safer alternatives. It may be declined to keep the project auditable.

## Pull requests

Keep changes focused and explain their user-visible effect. Update tests and documentation when behavior changes. Add a short entry under `Unreleased` in `CHANGELOG.md` for a user-visible fix or feature.

By contributing, you agree that your contribution is provided under the repository's license and that you have the right to submit it.
