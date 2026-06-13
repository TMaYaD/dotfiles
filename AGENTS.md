# Agent guidelines

This is a **public** dotfiles repository. Anything committed here is world-readable.

## Never commit sensitive or non-universal content

- **No secrets, ever.** Never commit credentials, API keys, tokens, passwords,
  private keys, or any other sensitive material — not in tracked files and not in
  commit messages. Machine-local secrets belong in gitignored `*.local.*` files.
- **Nothing machine-, project-, or person-specific.** These configs are shared
  publicly, so keep everything universal:
  - No absolute home paths (e.g. `/Users/<you>/...`), private project names,
    private bot/instance names, employer/client names, or internal hostnames.
  - In examples, use generic placeholders (`owner/repo`, `acme/webapp`, `<login>`).
  - Machine-local overrides go in gitignored files (`*.local.*`,
    `**/.claude/settings.local.json`), never in tracked files.
- When unsure whether something is safe to publish, ask before committing.

## Commits

- Use Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`; scope like `feat(skills):`).
- One commit per logical change; split unrelated changes into separate commits.
- No model identifiers or AI attribution in commit messages.
