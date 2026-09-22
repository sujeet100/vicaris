# sujit-marketplace

Sujit's personal Claude Code plugin marketplace.

## Plugins

- **Vicaris** — autonomous end-to-end dev workflow (plan → implement →
  adversarial review → test → finalize), grounded in Sujit's coding
  principles. See [`plugins/vicaris/README.md`](plugins/vicaris/README.md).

## Install

```bash
claude plugin marketplace add ~/projects/personal/vicaris
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

The plugin is generic. Anything project- or product-specific lives in one file:
`plugins/vicaris/references/project-context.md`. Edit it for the project you're
working in (verify command, app/login, SSO, observability, MR-reviewer path,
Slack target). Delete sections that don't apply.
