# Device QA Login and 2FA

When a device QA scenario requires a logged-in account, the controller and QA worker must preserve the boundary between product evidence and account access.

## Credential Source

Login credentials/config are sourced from local `.env.local` when device QA requires login. `.env.local` is local-only and secret-bearing.

Rules:

- Do not commit `.env.local`.
- Do not print `.env.local` contents.
- Do not copy values from `.env.local` into prompts, result JSON, artifacts, or chat.
- For lane worktrees under `/home/gamer/v2next-worktrees/`, the controller must copy `/home/gamer/git/V2Next/.env.local` to `<lane>/.env.local` with mode `600` before dispatching any login-required QA. A missing worktree-local file is a controller preflight failure, not a valid product QA blocker.
- Do not ask the user to paste passwords, cookies, PATs, 2FA verification codes, or other credentials.
- A worker/controller may use `.env.local` only inside the local execution environment for the exact QA login action.

## 2FA Workflow

2FA verification codes should be obtained by opening the 2FA app on the device. Treat codes and account-specific 2FA screens as sensitive.

Rules:

- Avoid screenshots, screen recordings, layout dumps, or logs that expose 2FA codes.
- Redact any code or secret-bearing content if accidentally captured.
- Do not store, commit, or quote 2FA codes, cookies, verification tokens, account identifiers, or account-specific sensitive data.

## Login Captcha

A normal login-page captcha is not the same as 2FA and is not automatically a blocker. CAPTCHA handling is a QA-worker responsibility, not a controller responsibility.

Required QA sequence when a login form shows a captcha field:

1. Capture a fresh screenshot/layout from the current QA run.
2. Use the QA worker's own vision/OCR or image preprocessing to read the captcha. Do not rely on a controller-read value, chat-transcribed value, or stale artifact.
3. Enter credentials from local `.env.local` and the QA-read captcha inside the device/login flow.
4. Submit once; if the captcha changes or fails, capture a fresh screenshot and retry OCR/preprocessing once.
5. Continue the original product scenario after login succeeds.

Evidence rules:

- Result JSON must include screenshot/layout paths, OCR attempt status, submit result, and any cooldown/error state.
- Do not print or store the raw captcha value in chat, prompts, commits, or long-lived docs. If an artifact needs to mention it, redact the value and keep only attempt metadata.
- Controller must not read or provide captcha values for QA proof. If a controller accidentally reads one, QA must treat it as invalid and re-read inside the QA run.

Only report `BLOCKED` after QA-owned fresh OCR/preprocessing attempts fail, login enters cooldown/IP restriction, `.env.local` is missing/invalid, a real-time 2FA code is required, or the page is no longer an actionable login form. Include the non-secret state and artifact paths.

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
