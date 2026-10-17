# V2EX Auth / 2FA Contract

Updated: 2026-10-17. Covers initial login and periodic verification of an existing session.

## Session continuation

- Authenticated HTML requests recognize `/2fa` redirects or a real 2FA form. Merge received `Set-Cookie` in response order **before** publishing the challenge. Delayed responses whose request Cookie no longer matches the active account must not open a challenge.
- One global challenge owns the pending session. Concurrent business requests must not overwrite it. Explicit native login may start a new flow; cancel/failure must not clear the previously active account.
- Each submission fetches `/2fa` using the latest pending Cookie, then submits the parsed code field and the page's `once` when present. Do not replay unrelated hidden/button/submit fields. Keep the `/2fa` Referer and disable HTTP caching.
- Cookie merging supports `Max-Age` deletion, expired `Expires`, and `Max-Age` precedence. Preserve ordered updates, including A → B → A; never globally deduplicate header lines. This remains the existing first-party header transport, not a general domain/path CookieJar.
- Failed attempts retain the newest session, including updates received with an HTTP error. Clear the user's code input, retain the challenge, and fetch a fresh form on retry. Do not automatically resend the one-time code.
- Success requires `/balance` returning HTTP 200 with a signed-in identity and no login/2FA form, followed by `/settings` confirming the same identity. A redirect alone, HTTP 200 alone, or an anti-bot page is insufficient.
- If a prior POST succeeded but verification was interrupted, `/2fa` may no longer provide a form. In that case, run the same `/balance` and `/settings` checks without posting blindly.
- Persist only a verified result whose challenge/account/domain context remains current. A partial local save may be retried by the same flow. Existing account persistence spans multiple asynchronous writes; this patch does not make account switching and persistence transactional.
- Keep the existing global sheet and success refresh behavior. Do not automatically replay non-idempotent business writes.

## Durable diagnostics and collection

Use Settings → diagnostic logs (existing screen). Logging is enabled at `info` by default; disabling diagnostics or raising its minimum level can omit events. No new controls or visible workflow are introduced.

Each flow receives an independent `flowId`; `attempt` separates submissions and `stage` identifies the failed step. Events cover challenge detection/coalescing, form GET, verification POST, gated-page check, identity check, retry state, persistence, completion and cancellation. Request records include method, host without user-info, transport mode, and protocol version. Response records include status, route categories, duration, response length, header-update count, session-change/presence flags, form/identity/once-presence flags, server problem category, and server Date offset when provided. Transport failures retain numeric platform error codes. The server clock delta is an observation, not proof that the authenticator clock is wrong.

Never log actual Cookie values or hashes, verification codes, `once` values, request bodies, raw HTML, usernames, or arbitrary server/exception text in the 2FA journal. Server problem messages are classified into bounded categories. `challengeFieldPresent` means a page `once` was present; it does not contain its value. `responseUpdates` counts collected header entries (a final header can also appear in a callback), not distinct cookie names.

2FA events are written synchronously to the normal log and a separate `next2v-2fa-YYYYMMDD-HHMMSS[-NN].txt` journal in the app's `filesDir/diagnostics_logs` directory. Each write closes its handle. Journals appear in the existing file list and use the existing share/copy fallback. Logging failures never fail authentication.

Retention is independent of normal launch logs:

| Files | Count cap | Age cap | Total size cap | Segment cap |
| --- | ---: | ---: | ---: | ---: |
| Normal launch logs | 10 | 14 days | 5 MiB (existing policy) | Existing behavior |
| 2FA journals | 20 | 30 days | 2 MiB | 256 KiB |

These are upper bounds, not guaranteed retention periods: many incidents or size pressure can remove older segments sooner. Rotation reserves space for the next segment. Restarting or signing in again does not by itself clear the 2FA journals. OS/app data deletion and failed storage remain outside this guarantee.

If the issue recurs:

1. Note the approximate failure time and whether it was a first attempt or retry. Do not record the code.
2. Export the matching `next2v-2fa-…txt` file(s) from Settings → diagnostic logs → log files; if already signed in again, the earlier files remain subject to the independent retention limits.
3. Include the ordinary launch log covering that time for app lifecycle/build context. The generic “export current log” action does not automatically bundle every retained journal.
4. Follow `flowId` and `attempt` through `fetch_form`, `submit`, `verify_gate`, `verify_identity`, and `persist`; compare response flags and the terminal event. No terminal event may indicate process termination rather than a server rejection.

## Verification

- `node scripts/test_two_factor_session_behavior.mjs`: production ETS logic with synthetic responses; Cookie rotation/deletion/order, response handoff, once submission, retry, already-verified recovery, false success rejection, stale-account responses, prompt catch wiring and secret exclusion.
- `node scripts/test_two_factor_log_retention.mjs`: production sink with an in-memory filesystem; reading/exporting journals, 15 restart cycles, independent count/age/size limits and redaction.
- Existing global 2FA, parser fixture, login V2, node false-positive, multi-account and V1 inventory contracts remain required.
- macOS build: `hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`.
- These checks do not prove the real V2EX periodic challenge path. Final runtime acceptance requires an actual existing session being challenged and successfully continued without signing in again. The user's earlier challenge was cleared by re-login; no replacement login test may be reported as that acceptance.

## Reference implementations

- [R2V global prompt and retry state](https://github.com/kucial/v2ex-react-native/blob/main/src/containers/AuthWatcher/components/TwoFAModal.tsx)
- [V2Compose account repository](https://github.com/cooaer/v2compose/blob/master/shared/src/commonMain/kotlin/io/github/v2compose/repository/def/DefaultAccountRepository.kt)
- [v2ex-simple global 2FA manager](https://github.com/fan123199/v2ex-simple/blob/main/app/src/main/java/im/fdx/v2ex/ui/main/TwoFAManager.kt)

The expanded investigation found `once + code` in seven of eight inspected repositories, including related Flutter implementations; these are not eight independent runtime proofs. CzBiX/v2ex-android used code alone. Missing `once` remains a protocol discrepancy, not a proven sole cause of the user's historical failure.
