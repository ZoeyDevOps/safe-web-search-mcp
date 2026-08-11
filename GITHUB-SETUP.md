# GitHub setup

This file covers repository settings that cannot be stored in source files.

It has two audiences. It records the setup this repository uses, and it doubles
as a checklist for anyone forking or re-hosting the project. The steps read as
instructions because they are written for that second reader; a visitor to this
repository is not being asked to carry them out.

## Before the first push

Completed for this repository. For a fork, work through these first.

1. Read [PROVIDER-NOTICE.md](PROVIDER-NOTICE.md). The HTML adapter carries no
   written provider authorization; this project publishes it as an accepted,
   documented risk rather than a resolved question. Repository visibility is the
   maintainer's decision, and making it public is a decision to adopt that
   position publicly. The reasoning recorded there is specific to the original
   author's jurisdiction and to non-commercial personal use, so satisfy yourself
   that it holds for your own circumstances first.
2. Run the validation command from [README.md](README.md).
3. Have a reviewer who did not write the change inspect the whole tree.
4. Check the staged file list before committing. Do not include installed
   copies, backups, logs, local MCP configuration, or audit attachments.

When creating the GitHub repository, leave GitHub's **Add a README**,
**Add .gitignore**, and **Choose a license** options unchecked. This repository
already contains those files.

Suggested description:

> A small Windows MCP server that gives compatible AI apps one web-search tool.

Suggested topics:

`mcp`, `model-context-protocol`, `powershell`, `windows`, `lm-studio`,
`web-search`

## Recommended repository settings

After the repository exists:

- Keep `main` as the default branch.
- Set default GitHub Actions workflow permissions to **Read repository
  contents**.
- Allow actions from GitHub and require actions to be pinned to a full commit
  SHA where your account plan supports that policy.
- Enable secret scanning and push protection where available.
- Enable dependency alerts. Dependabot is configured only for GitHub Actions;
  this project has no package dependencies.
- Enable **Private vulnerability reporting** before any public release.
- Once CI has run successfully, protect `main`: require a pull request, require
  the successful Windows PowerShell job from `.github/workflows/ci.yml`, dismiss
  stale approvals, block force pushes, and block branch deletion.
- Require a human review for workflow-file changes.

Do not place provider keys, personal paths, installed configuration, or search
queries in repository secrets, issues, test fixtures, or Actions logs.

## First commit and push

These commands record how this repository first reached GitHub, and are the same
steps for a fork. If you are following them, run them only after the audit above
is complete.

If this folder is not already a Git repository, initialize it first with
`git init -b main`. Then review and stage the files:

```powershell
git add --all
git status --short
git diff --cached --check
git commit -m "Initial safe web search MCP"
git remote add origin https://github.com/OWNER/safe-web-search-mcp.git
git push -u origin main
```

Replace `OWNER` with the actual GitHub account or organization. Before the
commit, inspect `git status --short`; every listed file should be intentional.

## Releases

Use semantic version tags such as `v1.0.0`. Follow
[RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md) before tagging. GitHub will create
source archives automatically. If a separate installation archive is attached,
publish its SHA-256 checksum and build it from a clean, reviewed checkout. Keep
`Install for LM Studio.cmd` at the archive root so the documented quick install
does not depend on Git, Python, a package manager, or a temporary download at
runtime.
