# V2Next Agent Guidelines

Index plus hard-stop constraints. Open the relevant guide for the current task.

Worktree copies under `/home/gamer/v2next-worktrees/*/AGENTS.md` must mirror this file unless a lane prompt declares a temporary override.

## Hard Stop: macOS Must Not Use `dev.sh`

On macOS/Darwin, do not run `bash dev.sh`, `bash dev.sh --build-only`, `bash dev.sh --no-build`, or any `dev.sh` mode. That script is for the Linux lane/worker environment with `/home/gamer/...` signing/toolchain paths.

macOS already uses the project-local DevEco/Hvigor configuration and signing material. For local macOS build validation, use:

```bash
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

If a macOS task appears to require `dev.sh`, stop and return `BLOCKED` with the requested command and the macOS-safe alternative above.

## Hard Stop: State Management V2 Only

State Management V1 is retired in this project. New development must not introduce or restore V1 component/state decorators in `entry/`, `feature/`, or `shared/` code.

Forbidden V1 patterns include `@Component`, `@State`, `@Prop`, `@Link`, `@Watch`, `@StorageLink`, `@StorageProp`, `@Provide`, `@Consume`, `@ObjectLink`, `@Observed`, `@Track`, `@LocalStorageLink`, and `@LocalStorageProp`. Use V2 primitives such as `@ComponentV2`, `@ObservedV2`, `@Trace`, `@Local`, `@Param`, `@Monitor`, and project V2 state holders/bridges instead.

Do not add a V1 adapter, allowlist entry, temporary bridge, key-churn refresh workaround, or compatibility exception to make a change easier. If a requested change appears to require V1, stop and return `BLOCKED` with source/build/device evidence and a V2-only alternative.

For any ArkTS/UI/state change, `node scripts/test_v1_decorator_inventory_contract.mjs` is a required gate and must report `0 file(s)` with live V1 decorators before merge/push.

## Always Read First

- [Always-loaded rules](docs/agent-guides/always-loaded-rules.md) — controller boundary, gates, UI/product preservation, encapsulation/task-boundary discipline, dev/release bundle, destructive writes, login/2FA, commits.
- [HarmonyOS default constraints](docs/agent-guides/harmonyos-default.md) — ArkTS/ETS syntax hard stops, official API/resource/i18n/theme requirements, and ArkUI animation constraints.

## Task-Specific Guides

- [Controller workflow & direct worker mode](docs/agent-guides/controller-workflow.md)
- [Review, QA, and integrate gates](docs/agent-guides/review-qa-integrate-gates.md)
- [Device QA login and 2FA](docs/agent-guides/device-qa-login-2fa.md)
- [Commit messages](docs/agent-guides/commit-messages.md)
- [Shared device lease (`192.168.50.237:12345`)](docs/device-lease.md)
- [Multi-account contract](docs/agent-guides/multi-account-contract.md) — mandatory blockers for account management entry, pending add-account state machine, honest logged-out UI, switch/remove/restore semantics.
