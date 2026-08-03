# sujit-marketplace

Sujit's personal Claude Code plugin marketplace.

## Plugins

- **dev-flow** — autonomous end-to-end dev workflow (plan → implement →
  adversarial review → test → finalize), grounded in Sujit's coding
  principles. See [`plugins/dev-flow/README.md`](plugins/dev-flow/README.md).

## Install

```bash
claude plugin marketplace add ~/projects/personal/dev-flow
claude plugin install dev-flow@sujit-marketplace
```

Then in any project:

```
/dev-flow PROJ-1234         # a ticket key, or a free-text task/brief
```

To update after editing:

```bash
claude plugin marketplace update sujit-marketplace
claude plugin update dev-flow@sujit-marketplace
```

## Per-project setup

The plugin is generic. Anything project- or product-specific lives in one file:
`plugins/dev-flow/references/project-context.md`. Edit it for the project you're
working in (verify command, app/login, SSO, observability, MR-reviewer path,
Slack target). Delete sections that don't apply.
