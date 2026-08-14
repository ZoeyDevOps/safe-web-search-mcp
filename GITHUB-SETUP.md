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

Topics, which are also the set this repository carries:

`mcp`, `model-context-protocol`, `mcp-server`, `mcp-tools`, `powershell`,
`windows`, `web-search`, `lm-studio`, `cursor`

Two rules kept that list shorter than it could be. Do not file the project
under the provider's name. Topics are metadata GitHub attaches to the project
itself, and the trademark item in [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md)
asks that nothing present this project as the provider's own. Naming the
provider in prose that describes what the software does is a different act from
tagging the project with their brand, which is why the README names them freely
and this list does not. Do not add a topic for a host the project ships no
template and no tested path for, however plausible the integration sounds; a
topic is a claim that someone searching for that host should find this.

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
- Enable **Private vulnerability reporting** as soon as the repository is
  public. It cannot be enabled earlier: the setting does not exist on a private
  repository, and the API reports it as absent rather than disabled. Treat the
  gap between making the repository public and turning this on as the window it
  is, and close it in the same sitting. Until it is on, `SECURITY.md` has no
  private route to point a reporter at.
- Once CI has run successfully, protect `main`: require a pull request, require
  the successful Windows PowerShell job from `.github/workflows/ci.yml`, block
  force pushes, and block branch deletion. Branch protection is also
  unavailable on a private repository on some account plans.
- Require the status check by its **job** name, `Windows PowerShell 5.1 /
  offline protocol suite`, not the workflow name that the badge and run list
  display. Requiring a name that never reports leaves `main` unmergeable with
  no clear error.

The next two depend on how many people maintain the repository, so they differ
between this repository and a fork:

- Required approvals. This repository requires zero, because a single
  maintainer cannot approve their own pull request; requiring one approval with
  bypass disabled would make `main` unmergeable. A fork with more than one
  maintainer should require at least one, and should also dismiss stale
  approvals when new commits are pushed. Dismissing stale approvals has no
  effect at zero.
- A human review for workflow-file changes. That is worth requiring wherever
  more than one person can review. It is not in force here, for the same reason.

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
