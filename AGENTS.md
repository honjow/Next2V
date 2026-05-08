# V2Next Agent Guidelines

## Controller workflow for product/UI tasks

For V2Next product, UI, navigation, settings, or interaction work, the agent is responsible for project control, not just code execution.

Before editing or delegating implementation:

1. Translate the user's natural-language complaint into an explicit controller spec.
2. Treat the original user wording as evidence, not as the executable implementation spec.
3. Separate:
   - product semantics: what the UI/action is supposed to mean;
   - preserved semantics: existing fields, states, routes, and actions that must not be replaced or removed;
   - non-goals: adjacent problems or metrics that must not be folded into the task;
   - verification path: exact route, state variants, action effects, and persistence/re-entry checks.
4. For information-migration requests, move the existing information structure unless the spec explicitly changes its meaning. Do not replace a field with a nearby metric or a guessed "more useful" value.
5. If implementation is delegated, require a spec-compliance review before code-quality review. The controller must still inspect the diff and independently verify build/device results; implementation-agent self-reports are not proof.
6. UI/interaction completion requires scenario validation when tooling is available: the requested state appears, preserved information remains, actions actually work, failure/unauthenticated states are handled where relevant, and the state is correct after navigation away/re-entry.
7. If the spec is found wrong or ambiguous, stop and revise the spec before continuing. Do not patch over a mistaken product interpretation.

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
