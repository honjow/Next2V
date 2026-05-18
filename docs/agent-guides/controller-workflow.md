# Controller Workflow

This guide expands the always-loaded controller rules in `AGENTS.md`.

## Hermes Execution Boundary

For V2Next product, UI, navigation, settings, or interaction work, Hermes is responsible for project control by default, not direct implementation.

Unless the user explicitly authorizes Hermes to implement directly, for example "你直接改", "你来实现", or "可以动代码", Hermes must not modify project files, build, install, control the shared device, or commit changes by itself.

Default Hermes responsibilities are:

1. Translate the user's natural-language complaint into an explicit controller spec.
2. Define product semantics, preserved semantics, non-goals, and verification paths.
3. Prepare implementation prompts/specs for a coding agent when code changes are needed.
4. Review implementation diffs and evidence instead of treating implementer self-reports as proof.
5. Verify or request verification evidence according to the agreed workflow before calling a task done.

Important: "继续", "按计划走", an active task list, or a context-compaction handoff only authorizes continuing the controller workflow. These signals do not authorize Hermes to self-execute code changes, builds, installs, device operations, or commits.

## Spec Discipline

Before editing or delegating implementation:

1. Translate the user's natural-language complaint into an explicit controller spec.
2. Treat the original user wording as evidence, not as the executable implementation spec.
3. Separate product semantics, preserved semantics, non-goals, and verification path.
4. For information-migration requests, move the existing information structure unless the spec explicitly changes its meaning. Do not replace a field with a nearby metric or a guessed "more useful" value.
5. Treat the existing UI/interaction surface as preserved unless the user explicitly changes it. Do not swap system components for custom components, alter colors, spacing, typography, copy, navigation, confirmation flows, or remove features just because it makes an implementation easier.
6. Keep diagnostic changes out of final diffs. Fake network calls, artificial delays, mocked services, diagnostic UI, logging overlays, and temporary instrumentation may only be used as isolated verification scaffolding; remove them before final validation unless the user explicitly asks to keep them.
7. Evidence must match the preserved product path. A test performed with a different component, confirmation flow, mock path, or altered UI cannot be used as proof that the original preserved path works.
8. If implementation is delegated, require a spec-compliance review before code-quality review. The controller must still inspect the diff and independently verify build/device results; implementation-agent self-reports are not proof.
9. UI/interaction completion requires scenario validation when tooling is available: the requested state appears, preserved information remains, actions actually work, failure/unauthenticated states are handled where relevant, and the state is correct after navigation away/re-entry.
10. If the spec is found wrong or ambiguous, stop and revise the spec before continuing. Do not patch over a mistaken product interpretation.

## Direct Worker Controller Mode

When the user explicitly rejects Kanban/watchdog orchestration for V2Next work, use direct worker controller mode instead of board tasks.

Required contract:

1. Hermes remains the controller; a status-only cron, board dispatcher, or one-shot worker launch is not sufficient.
2. Start independent worker processes directly by command, normally `codex exec --sandbox danger-full-access --color never - < prompt.md` under a PTY/log wrapper.
3. Record per stage: controller artifact directory, prompt path, worker log path, result JSON path, PID/session id, worktree, and current git status.
4. Use explicit stages: implementation -> read-only review -> independent device QA -> integrate -> next planned lane/spec.
5. Each stage must produce a machine-readable result JSON with `verdict: PASS|FAIL|BLOCKED|REQUEST_CHANGES`, `summary`, `artifact_dir`, `commands`, `changed_files`, `evidence`, and `commit` when applicable.
6. Advance only on `verdict=PASS`. `FAIL`, `BLOCKED`, or `REQUEST_CHANGES` must stop or trigger a narrow recovery worker with evidence; do not call a live process or heartbeat "progress".
7. If a worker exits 0 without the result JSON, inspect required artifacts before declaring failure. For spec stages, a `summary.md` containing `Verdict: SPEC_READY` may be converted into a result JSON by the controller/recovery worker. For QA, only synthesize from `validation-summary.md` when it explicitly says PASS and screenshots/layout/logs exist. For integrate, verify commit and push evidence first.
8. Do not rerun already-PASS upstream stages after a later blocker; resume from the failed/missing stage.
9. No-progress escalation is mandatory: monitor process liveness, log growth, artifact creation, git diff/commit state, elapsed time, and no-output threshold; then inspect logs and kill/restart/split/switch worker or stop as a real blocker.

The Review/QA/Integrate quality gates still apply in direct-worker mode; replace Kanban parent/child status with result JSON artifacts and controller verification.

## Worktree Setup Preflight

Before any agent or subagent builds, signs, installs, or device-tests a V2Next lane worktree under `/home/gamer/v2next-worktrees/`, run `scripts/sync-signing-materials.sh` in that worktree, or copy the same four gitignored files from `/home/gamer/git/V2Next/scripts`:

- `scripts/xiaobai.p12`
- `scripts/xiaobai.csr`
- `scripts/next2v-debug.cer`
- `scripts/next2v-debug.p7b`

These files are intentionally gitignored and must not be committed or printed. Do this before `bash dev.sh`, otherwise `scripts/sign.py` may try Huawei/AGC login, hit an expired token, and stall in a headless browser callback.
