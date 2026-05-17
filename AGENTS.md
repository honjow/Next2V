# V2Next Agent Guidelines

This file is the always-loaded entrypoint. Keep the non-negotiable rules here concise, then open the linked guide that matches the current task.

## Always-Loaded Rules

### Hermes/controller boundary

For V2Next product, UI, navigation, settings, or interaction work, Hermes is the controller by default. Unless the user explicitly authorizes Hermes to implement directly, for example "你直接改", "你来实现", or "可以动代码", Hermes must not modify project files, build, install, control the shared device, or commit changes by itself.

Hermes translates user wording into a controller spec, defines product and preserved semantics, prepares worker prompts, reviews diffs and evidence, and verifies or requests verification before calling work done. "继续", "按计划走", an active task list, or a context-compaction handoff only authorizes continuing controller workflow; it does not authorize direct implementation, builds, installs, device operations, or commits.

Direct worker controller mode is allowed when this project workflow calls for it: Hermes remains controller, launches independent workers directly, records artifacts and process state, and advances only on machine-readable `verdict=PASS` result JSON.

### Worker/result gates

Implementation, read-only review, independent device QA, integrate, and follow-up spec stages must be explicit. Each worker stage must produce a result JSON with `verdict: PASS|FAIL|BLOCKED|REQUEST_CHANGES`, `summary`, `artifact_dir`, `commands`, `changed_files`, `evidence`, and `commit` when applicable. A live process, heartbeat, or implementer self-report is not proof. Do not rerun already-PASS upstream stages after a later blocker; resume from the failed or missing stage.

### Worktree signing preflight

Before any agent or subagent builds, signs, installs, or device-tests a V2Next lane worktree under `/home/gamer/v2next-worktrees/`, run `scripts/sync-signing-materials.sh` in that worktree, or copy the same four gitignored signing files from `/home/gamer/git/V2Next/scripts`. These files are secret-bearing local materials, must not be printed or committed, and prevent `scripts/sign.py` from stalling on Huawei/AGC login during `bash dev.sh`.

### Review vs QA separation

UI, interaction, navigation, and settings lanes require separate gates:

- `Review` by `v2reviewer`: diff, spec compliance, build logs, and static assertions only.
- `QA on device` by `v2qa`: independent validation on shared device `192.168.50.237:12345` with fresh evidence in `.hermes-artifacts/<yyyymmdd-HHMM>-<lane>-qa/`.
- Integrate requires a PASS QA result or an explicit user real-device ack recorded as user ack. Reviewer PASS alone is not enough.

### Device QA login and 2FA

When device QA requires login, credentials/config come from local `.env.local` only. Do not commit `.env.local`, print it, copy values into prompts/result JSON, or paste values into chat. A worker/controller may use it only inside the local execution environment for the exact QA login action.

Do not ask the user to paste passwords, cookies, PATs, 2FA verification codes, or other credentials. Obtain 2FA verification codes by opening the 2FA app on the device. Treat screenshots/logs of 2FA codes as sensitive; avoid capturing them and redact accidental captures. If `.env.local` is missing/invalid or the 2FA app is unavailable, return a narrow `BLOCKED` result with the exact state and artifact paths. After login/2FA, re-enter the target screen and capture fresh product evidence when possible.

User real-device ack remains valid, but it must be recorded explicitly as user ack, not fabricated worker screenshot, layout, or log evidence.

### Commit messages

Use informative Conventional Commits: `<type>(<scope>): <specific user-visible or technical change>`. Include a body for bug fixes, parser/network changes, write actions, and UI regressions with `Why`, `What changed`, and `Validation`. Never include cookies, tokens, once values, API keys, passwords, 2FA codes, or other secrets.

## Read More When Needed

- Controller workflow and direct worker mode: [docs/agent-guides/controller-workflow.md](docs/agent-guides/controller-workflow.md)
- Device QA login and 2FA: [docs/agent-guides/device-qa-login-2fa.md](docs/agent-guides/device-qa-login-2fa.md)
- Review, QA, and integrate gates: [docs/agent-guides/review-qa-integrate-gates.md](docs/agent-guides/review-qa-integrate-gates.md)
- Commit messages: [docs/agent-guides/commit-messages.md](docs/agent-guides/commit-messages.md)
