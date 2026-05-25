# Multi-account contract

Mandatory product/state-machine contract for V2Next multi-account work. This is a project constraint, not a chat note.

## Scope

Applies to any lane touching account management, login, session/cookie storage, settings account entry, Account page, startup restore, or account switching/removal.

## Mandatory blockers

Any violation below is `FAIL` even if build/tests pass.

1. **Entry ownership**
   - Account management lives at `Settings -> Account management`.
   - `AccountPage.ets` / Me page must not contain add/switch/remove multi-account management actions.
   - The Me page may show current account overview only.

2. **Independent management page**
   - Account management must be its own management surface/page/component with account-management semantics.
   - The `Account` route must not reuse `AccountDashboardPage({ showDetail: true })` or a Me-page detail variant as account management.

3. **Add account is pending, not destructive**
   - Starting add-account/login-second-account must not clear or invalidate the current active account before the new login succeeds.
   - `prepareAddAccount()` or equivalent pre-login entry code must not call `CookieJarSettings.clear()`, `AuthSessionSettings.clear()`, or any equivalent runtime identity clearing before successful new-login registration.
   - Cancel/back/fail from add-account flow must preserve the previous active account, cookie/session runtime state, and visible app identity.

4. **Login success registration**
   - New account registration/switch happens only after successful login has produced validated cookie/session data.
   - Login success must create/update an `AccountStore` record from real `CookieJarSettings`/`AuthSessionSettings` data and then switch active account.

5. **Honest unauthenticated state**
   - If no real account/session exists, `Settings -> Account management` renders logged-out/login/add-account UI.
   - It must not render fake `V2EX user`, generic account detail, or placeholder signed-in state.

6. **Switch/remove/restore state ownership**
   - Switching account must apply the selected record's cookie/session back into runtime storage and WebCookieManager, not only set an active id.
   - Removing one account must not wipe unrelated accounts.
   - Removing active account must choose a deterministic fallback account or become logged out if none remain.
   - Startup restore must restore the active account's cookie/session, not only active id.

7. **Verification path**
   - Tests must include a non-network path that seeds two local account records, verifies list/current marker, switch, remove active fallback, remove all logged-out state, and restart active restore.
   - Device QA must cover `Settings -> Account management` and at least one path beyond the first visible screen; screenshots/layout dumps are required for key states.

## Required contracts before implementation PASS

A multi-account implementation/revision must add or update static/contract tests that fail on:

- `prepareAddAccount()` calling cookie/session clear before login success.
- Me page exposing add/switch/remove account-management actions.
- Account-management route reusing Me/dashboard detail page semantics.
- Logged-out account management rendering fake/generic signed-in user details.
- Switch implementation setting only active id without applying cookie/session.

## Review requirement

Reviewer must inspect both:

- Mandatory blockers above with file/line evidence.
- Open-ended consistency: adjacent flows, cancel/error/restart paths, state ownership, page responsibility, and product semantics not explicitly listed here.

Checklist-only PASS is invalid.
