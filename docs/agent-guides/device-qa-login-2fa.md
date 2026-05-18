# Device QA Login and 2FA

When a device QA scenario requires a logged-in account, the controller and QA worker must preserve the boundary between product evidence and account access.

## Credential Source

Login credentials/config are sourced from local `.env.local` when device QA requires login. `.env.local` is local-only and secret-bearing.

Rules:

- Do not commit `.env.local`.
- Do not print `.env.local` contents.
- Do not copy values from `.env.local` into prompts, result JSON, artifacts, or chat.
- Do not ask the user to paste passwords, cookies, PATs, 2FA verification codes, or other credentials.
- A worker/controller may use `.env.local` only inside the local execution environment for the exact QA login action.

## 2FA Workflow

2FA verification codes should be obtained by opening the 2FA app on the device. Treat codes and account-specific 2FA screens as sensitive.

Rules:

- Avoid screenshots, screen recordings, layout dumps, or logs that expose 2FA codes.
- Redact any code or secret-bearing content if accidentally captured.
- Do not store, commit, or quote 2FA codes, cookies, verification tokens, account identifiers, or account-specific sensitive data.

## Login Captcha

A normal login-page captcha is not the same as 2FA and is not automatically a blocker. When the login form shows a captcha field, first try to obtain the captcha from the current page, screenshot, or page resource and enter it without printing or storing the value. Only report `BLOCKED` after the captcha cannot be obtained or recognized, and include the non-secret state and artifact paths.

## QA Evidence Boundary

If the shared device is unauthenticated, do not mark the product scenario PASS from unauthenticated screenshots, login prompts, or unrelated fallback states.

When login/2FA succeeds, re-enter the target route or screen and capture fresh product evidence when possible. The evidence should show the requested product state and behavior, not the credential or 2FA process.

If installing a fresh build will clear app data or session state, state this before QA. Prefer reusing current app state only when it is compatible with the lane and does not hide the behavior under test.

## Blockers

If login or 2FA blocks QA because `.env.local` is missing/invalid, the 2FA app is unavailable, or the device cannot reach the needed login state, return a narrow `BLOCKED` result.

The blocker must include:

- Exact screen/state observed.
- Route or action being verified.
- Artifact path.
- What input or device state is missing.

Do not report a broad product failure for an account-access blocker.

## User Real-Device Ack

A direct user real-device ack may close a QA scenario, but the controller must record it explicitly as user ack. Do not pretend the worker captured a missing screenshot, layout dump, or other evidence.
