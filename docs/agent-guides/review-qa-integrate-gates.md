# Review, QA, and Integrate Gates

UI, interaction, navigation, and settings lanes must preserve role separation. The controller must not bypass these gates.

## Review Gate

`Review` is assigned to `v2reviewer` and covers only diff review, spec compliance, build logs, and static assertions.

`v2reviewer` must not use screenshots, recordings, or device logs produced by the implementation card as PASS evidence for device behavior.

## Device QA Gate

`QA on device` is assigned to `v2qa` and independently validates on shared device `192.168.50.237:12345`.

Device evidence must be captured during the QA card itself and stored in `.hermes-artifacts/<yyyymmdd-HHMM>-<lane>-qa/`. Do not reuse the implementation card's artifact directory. At minimum, include `validation-summary.md` and screenshots for key states.

Before installing or controlling the device, QA must prove hdc readiness with a real shell probe: `hdc tconn 192.168.50.237:12345`, wait about 2 seconds, then `hdc -t 192.168.50.237:12345 shell echo ok`. `Connect OK` or `list targets -v` showing `Connected` is not enough evidence because the target can appear connected before shell commands produce output. If the probe does not print `ok`, record QA as `BLOCKED` with the probe output instead of repeatedly reconnecting. Do not use `hdc tmode port ...` during normal QA unless the user explicitly asks to repair device connection mode.

If the scenario needs login or 2FA, follow [device-qa-login-2fa.md](device-qa-login-2fa.md).

## Integrate Gate

An integrate or commit-merge card must include a parent that is status=done with PASS conclusion from `v2qa`. Its body must explicitly reference the QA card id, run id, and artifact directory.

Reviewer PASS alone is not enough to authorize integrate.

## User Real-Device Ack Exception

When the user directly gives a real-device ack in conversation, the controller may close the corresponding `v2qa` card and treat the ack as equivalent evidence. The card summary must state "由用户实机 ack 闭环". Do not silently skip QA and do not fabricate worker-captured evidence.

## Post-Merge Repair

If a lane is discovered after merge to lack independent `v2qa`, create a post-merge `QA on device` card against current `master` HEAD. If that QA fails, use the normal revision flow. Do not retroactively rewrite reviewer PASS as QA PASS.

## Direct Worker Mode Mapping

In direct-worker controller mode, replace Kanban parent/child status with result JSON artifacts and controller verification. The same role separation and evidence rules still apply: implementation, read-only review, independent device QA, and integrate remain separate stages.
