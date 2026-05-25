# Always-Loaded Rules

These rules apply to every V2Next agent task and override task-specific shortcuts. Worktree copies under `/home/gamer/v2next-worktrees/*/AGENTS.md` must stay aligned with the main repo `AGENTS.md` index unless a lane prompt explicitly declares a temporary override.

## Hermes/Controller Boundary

For V2Next product, UI, navigation, settings, or interaction work, Hermes is the controller by default. Unless the user explicitly authorizes Hermes to implement directly (for example "你直接改", "你来实现", "可以动代码"), Hermes must not modify project files, build, install, control the shared device, or commit changes by itself.

Hermes translates user wording into a controller spec, defines product and preserved semantics, prepares worker prompts, reviews diffs and evidence, and verifies or requests verification before calling work done. "继续", "按计划走", an active task list, or a context-compaction handoff only authorizes continuing the controller workflow; it does not authorize direct implementation, builds, installs, device operations, or commits.

Direct worker controller mode is allowed when the project workflow calls for it: Hermes remains controller, launches independent workers directly, records artifacts and process state, and advances only on machine-readable `verdict=PASS` result JSON.

## Worker/Result Gates

Implementation, read-only review, independent device QA, integrate, and follow-up spec stages must be explicit. Each worker stage must produce a result JSON with `verdict: PASS|FAIL|BLOCKED|REQUEST_CHANGES`, `summary`, `artifact_dir`, `commands`, `changed_files`, `evidence`, and `commit` when applicable. A live process, heartbeat, or implementer self-report is not proof. Do not rerun already-PASS upstream stages after a later blocker; resume from the failed or missing stage.

## Product and UI Preservation Boundary

User product decisions are hard constraints, not suggestions. Unless the user explicitly requests that exact product/visual change, do not replace existing UI components, remove features, change colors, typography, spacing, layout, wording, navigation path, confirmation style, interaction model, or visible state semantics while fixing a bug. Technical convenience, easier testing, or a suspected implementation issue is not authorization to change user-visible design.

When validating a hypothesis, keep test scaffolding isolated and temporary. Fake network requests, artificial delays, mocked services, diagnostic UI, or instrumentation must be removed before final implementation unless the user explicitly asks to keep them. Do not treat evidence gathered under a changed UI/component path as proof for the preserved UI path.

## Worktree Signing Preflight

Signing/profile material lookup must be anchored to the real user home, not to a Kanban/profile worker's sandbox `HOME`. For V2Next the stable material root is `/home/gamer/.config/harmony/debug-signing` unless `V2NEXT_REAL_HOME` is explicitly changed for a real account-home migration.

Before any agent or subagent builds, signs, installs, or device-tests a V2Next lane worktree under `/home/gamer/v2next-worktrees/`, run `scripts/lane-preflight.sh` from the main repo. The preflight must set `NEXT2V_SIGN_NONINTERACTIVE=1` and verify that `debug.p12`, the debug certificate, and `profiles/com.next2v.app.p7b` resolve under `/home/gamer/.config/harmony/debug-signing`.

Workers must never generate a Profile, open a browser, call Huawei/AGC login, or rely on `Path.home()`, `${HOME}`, or `~` to find signing materials. If local materials are missing, the worker must fail fast with the exact missing path and mark the gate `BLOCKED`.

## Review vs QA Separation

UI, interaction, navigation, and settings lanes require separate gates:

- `Review` by `reviewer`: diff, spec compliance, build logs, and static assertions only.
- `QA on device` by `qa`: independent validation on shared device `192.168.50.237:12345` with fresh evidence in `.hermes-artifacts/<yyyymmdd-HHMM>-<lane>-qa/`.
- Integrate requires a PASS QA result or an explicit user real-device ack recorded as user ack. Reviewer PASS alone is not enough.

Before any install or device control, verify hdc readiness with a real shell probe: `hdc tconn 192.168.50.237:12345`, wait about 2 seconds, then `hdc -t 192.168.50.237:12345 shell echo ok`. `Connect OK` or `list targets` showing `Connected` is not enough. If the probe does not print `ok`, record device QA as `BLOCKED`; do not loop reconnects or run `hdc tmode port ...` unless the user explicitly asks to repair connection mode.

## Dev vs Release Bundle Boundary

V2Next QA only touches the dev bundle `com.next2v.app`. Do not install, query, launch, or modify the release bundle `com.honjow.next2v` unless the user explicitly authorizes it.

QA must verify the foreground bundle before treating any screen as evidence. Install/launch failure produces `BLOCKED`; do not present stale-app screens as PASS evidence.

## Destructive Write Action Policy

V2EX account-state write actions are non-idempotent and treated as destructive: thank, favorite, ignore, report, reply submit, topic-thank, and similar confirm taps. Unattended workers must not execute the final confirm unless the user has explicitly authorized that lane.

Default validation for these flows is non-destructive: open the dialog, capture layout/screenshot evidence, then cancel. Combine with static review of the wiring code as evidence.

## UI Investigation Order

Before changing UI to fix a bug, verify the chain end-to-end: source data → parser/model → UI. QA evidence must be real-device user-visible state, not just code-contract assertions.

Do not use internal debug, diagnostic, or QA-seed panels as user evidence. Debug tooling must not pollute normal user-visible settings pages or production navigation.

## Device QA Login and 2FA

When device QA requires login, credentials/config come from local `.env.local` only. Do not commit `.env.local`, print it, copy values into prompts/result JSON, or paste values into chat. A worker/controller may use it only inside the local execution environment for the exact QA login action.

Do not ask the user to paste passwords, cookies, PATs, 2FA verification codes, or other credentials. A login-page captcha is not by itself a blocker: first obtain it from the current page/screenshot/resource and try to complete login without exposing the value. Obtain 2FA verification codes by opening the 2FA app on the device. Treat screenshots/logs of 2FA codes as sensitive; avoid capturing them and redact accidental captures. If `.env.local` is missing/invalid, captcha cannot be obtained/recognized, or the 2FA app is unavailable, return a narrow `BLOCKED` result with the exact state and artifact paths. After login/2FA, re-enter the target screen and capture fresh product evidence when possible.

User real-device ack remains valid, but it must be recorded explicitly as user ack, not fabricated worker screenshot, layout, or log evidence.

## Commit Messages

Use informative Conventional Commits: `<type>(<scope>): <specific user-visible or technical change>`. Include a body for bug fixes, parser/network changes, write actions, and UI regressions with `Why`, `What changed`, and `Validation`. Never include cookies, tokens, once values, API keys, passwords, 2FA codes, or other secrets.
