# V2Next Agent Guidelines

## Controller workflow for product/UI tasks

For V2Next product, UI, navigation, settings, or interaction work, Hermes is responsible for project control by default, not direct implementation.

### Hermes execution boundary

Unless the user explicitly authorizes Hermes to implement directly (for example: "你直接改", "你来实现", "可以动代码"), Hermes must not modify project files, build, install, control the shared device, or commit changes by itself.

Default Hermes responsibilities are:

1. Translate the user's natural-language complaint into an explicit controller spec.
2. Define product semantics, preserved semantics, non-goals, and verification paths.
3. Prepare implementation prompts/specs for a coding agent when code changes are needed.
4. Review implementation diffs and evidence instead of treating implementer self-reports as proof.
5. Verify or request verification evidence according to the agreed workflow before calling a task done.

Important: "继续", "按计划走", an active task list, or a context-compaction handoff only authorizes continuing the controller workflow. These signals do not authorize Hermes to self-execute code changes, builds, installs, device operations, or commits.

### Direct worker controller mode (no Kanban)

When the user explicitly rejects Kanban/watchdog orchestration for V2Next work, use direct worker controller mode instead of board tasks.

Required contract:

1. Hermes remains the controller; a status-only cron, board dispatcher, or one-shot worker launch is not sufficient.
2. Start independent worker processes directly by command, normally `codex exec --sandbox danger-full-access --color never - < prompt.md` under a PTY/log wrapper.
3. Record per stage: controller artifact directory, prompt path, worker log path, result JSON path, PID/session id, worktree, and current git status.
4. Use explicit stages: implementation -> read-only review -> independent device QA -> integrate -> next planned lane/spec.
5. Each stage must produce a machine-readable result JSON with `verdict: PASS|FAIL|BLOCKED|REQUEST_CHANGES`, `summary`, `artifact_dir`, `commands`, `changed_files`, `evidence`, and `commit` when applicable.
6. Advance only on `verdict=PASS`. `FAIL`, `BLOCKED`, or `REQUEST_CHANGES` must stop or trigger a narrow recovery worker with evidence; do not call a live process or heartbeat “progress”.
7. If a worker exits 0 without the result JSON, inspect required artifacts before declaring failure. For spec stages, a `summary.md` containing `Verdict: SPEC_READY` may be converted into a result JSON by the controller/recovery worker. For QA, only synthesize from `validation-summary.md` when it explicitly says PASS and screenshots/layout/logs exist. For integrate, verify commit and push evidence first.
8. Do not rerun already-PASS upstream stages after a later blocker; resume from the failed/missing stage.
9. No-progress escalation is mandatory: monitor process liveness, log growth, artifact creation, git diff/commit state, elapsed time, and no-output threshold; then inspect logs and kill/restart/split/switch worker or stop as a real blocker.

The existing Review/QA/Integrate quality gates below still apply in direct-worker mode; replace Kanban parent/child status with result JSON artifacts and controller verification.

### Worktree setup preflight

Before any agent or subagent builds, signs, installs, or device-tests a V2Next lane worktree under `/home/gamer/v2next-worktrees/`, run `scripts/sync-signing-materials.sh` in that worktree (or copy the same four gitignored files from `/home/gamer/git/V2Next/scripts`):

- `scripts/xiaobai.p12`
- `scripts/xiaobai.csr`
- `scripts/next2v-debug.cer`
- `scripts/next2v-debug.p7b`

These files are intentionally gitignored and must not be committed or printed. Do this before `bash dev.sh`, otherwise `scripts/sign.py` may try Huawei/AGC login, hit an expired token, and stall in a headless browser callback.

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

## Kanban dispatch rules: review vs QA separation

UI / 交互 / 导航 / 设置类 lane 必须满足以下硬约束。Controller (v2pm) 不得绕过；dispatcher 派 integrate 卡前必须核对。

1. **角色分离**：禁止单卡同时叫 “Review/QA” 或由同一 assignee 完成两件事。必须拆为两张独立卡：
   - `Review`，assignee = `v2reviewer`：只做 diff / spec 合规 / 构建日志 / 静态断言。
   - `QA on device`，assignee = `v2qa`：在共享设备 `192.168.50.237:12345` 上独立验证。
2. **证据来源隔离**：`v2reviewer` 不得以实现卡（v2frontend）产出的截图 / 录屏 / 设备日志作为 PASS 证据。设备证据必须由 `v2qa` 在本次 QA 卡内自抓。
3. **QA artifact 路径**：v2qa 必须把证据落在 `.hermes-artifacts/<yyyymmdd-HHMM>-<lane>-qa/`，禁止复用实现卡的目录。至少包含 `validation-summary.md` + 关键状态截图。
4. **Integrate 卡门控**：integrate / commit-merge 卡的 `--parent` 必须包含一张 status=done 且结论 PASS 的 `v2qa` 卡，并在 body 中显式引用该卡 id、run id、artifact 目录。仅有 v2reviewer PASS 不足以授权 integrate。
5. **用户实机 ack 例外**：当用户在对话中直接给出实机 ack 时，可由 controller 关闭对应 v2qa 卡并以用户 ack 作为等价证据，但必须在卡的 summary 中写明 “由用户实机 ack 闭环”，不得静默跳过。
6. **遗漏补救**：若发现某 lane 在合并后才被察觉缺独立 v2qa，必须对 master 当前 HEAD 补一张 post-merge `QA on device` 卡，结论 FAIL 时按修订流程走，不允许追溯性地把 reviewer PASS 改写为 QA PASS。

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
