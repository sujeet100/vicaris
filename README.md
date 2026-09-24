# sujit-marketplace

Sujit's personal Claude Code plugin marketplace.

## Plugins

- **Vicaris** — sends a story in your place and brings back reviewed, tested
  MRs across every repo it touches (understand → implement → review → test →
  finalize), grounded in Sujit's coding principles. See [`plugins/vicaris/README.md`](plugins/vicaris/README.md).

## Install

```bash
claude plugin marketplace add <path-to-this-repo>
claude plugin install vicaris@sujit-marketplace
```

Then in any project:

```
/vicaris PROJ-1234         # a ticket key, or a free-text task/brief
```

To update after editing:

```bash
claude plugin marketplace update sujit-marketplace
claude plugin update vicaris@sujit-marketplace
```

## Per-project setup

The plugin is generic. Anything project- or product-specific lives in one
gitignored file: copy `plugins/vicaris/references/project-context.template.md`
to `project-context.md` beside it and fill it in for the project you're working
in (verify command, app/login, SSO, observability, MR-reviewer path, Slack
target). Delete sections that don't apply.
