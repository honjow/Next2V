# V2EX Auth / 2FA Contract

Status: draft, derived from project discussion and reference-client research.

## Key behavior

For accounts with V2EX two-factor authentication enabled, after password/CAPTCHA login succeeds but before 2FA is completed, V2EX can redirect **any authenticated page request** to `/2fa`.

Therefore `/2fa` handling is not only a native-login-page step. It must be treated as a session/global auth state.

## Required design implication

- Any network request or page fetch that follows authenticated redirects must detect `Location: /2fa` or equivalent `/2fa` final URL.
- Detection should trigger a single shared 2FA challenge state.
- The app should not mark login/session as fully authenticated until 2FA is submitted and a private page proof succeeds.
- Submitting the challenge should use the V2EX-compatible contract observed in reference clients:
  - endpoint: `/2fa`
  - method: POST
  - body field: `code`
  - referer: `/2fa`
  - cookie: current login/session cookie
- After successful 2FA, the originally blocked request may be retried or the affected page refreshed.
- If a code is wrong or expired, keep the 2FA challenge active and only clear the 2FA code input.

## Reference evidence

See:

- `.hermes-artifacts/20260511-auth-reference-research/research.md`
- `.hermes-artifacts/20260511-auth-reference-research/contract-and-patch-plan.md`

Reference client behavior confirmed in `CzBiX/v2ex-android`:

- redirect `/2fa` means two-factor required;
- submit `POST /2fa` with `code`;
- verify login after redirect/session continuation.

## Current patch review note

The current uncommitted auth patch may still be too login-flow-local. Before committing, review whether `/2fa` redirect detection exists at the shared request/session layer or only inside `V2exNativeAuthService.login/completeTwoFactor`.
