# V2Next Agent Guidelines

Index only. Open the relevant guide for the current task.

Worktree copies under `/home/gamer/v2next-worktrees/*/AGENTS.md` must mirror this file unless a lane prompt declares a temporary override.

## Always Read First

- [Always-loaded rules](docs/agent-guides/always-loaded-rules.md) — controller boundary, gates, UI/product preservation, dev/release bundle, destructive writes, login/2FA, commits.

## Task-Specific Guides

- [Controller workflow & direct worker mode](docs/agent-guides/controller-workflow.md)
- [Review, QA, and integrate gates](docs/agent-guides/review-qa-integrate-gates.md)
- [Device QA login and 2FA](docs/agent-guides/device-qa-login-2fa.md)
- [Commit messages](docs/agent-guides/commit-messages.md)
- [Shared device lease (`192.168.50.237:12345`)](docs/device-lease.md)
- [Multi-account contract](docs/agent-guides/multi-account-contract.md) — mandatory blockers for account management entry, pending add-account state machine, honest logged-out UI, switch/remove/restore semantics.
