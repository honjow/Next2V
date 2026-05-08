# V2Next Agent Guidelines

## Commit messages

Use informative Conventional Commits. Avoid vague subjects such as `fix bug`, `update`, `resolve regressions`, or messages that only name the area.

Format:

```text
<type>(<scope>): <specific user-visible or technical change>

Why:
- <root cause or motivation>

What changed:
- <main implementation points>

Validation:
- <commands/tests/device checks that passed>
```

Rules:

- `type` should usually be `fix`, `feat`, `refactor`, `test`, `docs`, `chore`, or `perf`.
- `scope` should identify the affected area, for example `detail`, `network`, `parser`, `node`, `settings`, or `ui`.
- The subject must be specific enough to distinguish this commit from nearby commits.
- Include a body for bug fixes, parser/network changes, write actions, and UI regressions.
- Mention real validation performed, such as `node scripts/...`, `bash dev.sh --build-only`, install target, or device/UI verification.
- Never include cookies, tokens, once values, API keys, passwords, or other credentials. Use `[REDACTED]` if needed.
