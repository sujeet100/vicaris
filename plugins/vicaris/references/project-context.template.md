# Project context — template

Copy this to `project-context.md` in the same directory and fill it in. That file
is **gitignored on purpose**: it is the one place client- and project-specific
detail lives, so keeping it out of the repo is what lets this plugin be shared or
published without leaking an employer's internals.

Every stage loads it *only if present*, so `vicaris` works without it — you just
lose the project-specific shortcuts and fall back to generic behaviour.

Keep real credentials out of it even so. Reference a keychain entry or an
environment variable and let the shell resolve it at run time.

## Repos

- Where the repos sit on disk, side by side or otherwise.
- Which one is primary (the one that holds the branch manifest).
- The remote host and group path, if MRs are created by CLI.

## Build and verify

- The fast verify command each stage runs after editing (unit tests, lint, type
  check) and roughly how long it takes.
- The full suite, and when it is worth paying for.
- Any generated code or migration step that must run before tests pass.

## Running locally

- How to bring the stack up, and from which directory.
- The URL the app serves on, and which service owns which route prefix.
- Whether login is required, and how to obtain a session. Store the account in
  the keychain and reference the service and account names here, never the
  password:

  ```bash
  security add-generic-password -s <service> -a <account> -w
  ```

## Migrations

- The command that applies a migration, and the one that reverses it.
- A scratch or disposable database the rehearsal can run against, and how to reset
  it. Without this the `production` gate records the rehearsal as not run, which is
  honest but weaker than running it.

## Observability

- Where traces and logs live, and how to reach them (skill, MCP, or URL).
- Which environment is safe to inspect.

## Review and announcement

- The MR review command, if there is a standalone reviewer.
- The channel MRs are announced in, and the exact message shape expected.
- A Slack target for run updates, only if it should differ from the Slack member
  ID in the plugin's settings.
- The issue-tracker key format, so branch names and MR titles carry it.

## Prompt and eval conventions

- Where prompts live and how they are stitched together, if the project ships
  LLM prompts.
- How to run the eval suite, and what a passing run looks like.
