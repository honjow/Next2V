# Review, QA, and Integrate Gates

UI, interaction, navigation, and settings lanes must preserve role separation. The controller must not bypass these gates.

## Review Gate

`Review` is assigned to `reviewer` and covers only diff review, spec compliance, build logs, and static assertions.

`reviewer` must not use screenshots, recordings, or device logs produced by the implementation card as PASS evidence for device behavior.

## Device QA Gate

`QA on device` is assigned to `qa` and independently validates on shared device `192.168.50.237:12345`.

Device evidence must be captured during the QA card itself and stored in `.hermes-artifacts/<yyyymmdd-HHMM>-<lane>-qa/`. Do not reuse the implementation card's artifact directory. At minimum, include `validation-summary.md` and screenshots for key states.

For UI visual QA, start with a human visual audit of the whole screen and flow before checking the specific acceptance list. Ask: would this look correct to a user, does anything feel visually wrong, clipped, obscured, misaligned, stale, inconsistent with the reference screen, or semantically misleading? A PASS requires both (a) no obvious holistic visual/product regression and (b) every user-stated acceptance criterion mapped to screenshot/layout evidence.

Specific acceptance criteria are a floor, not the whole QA scope. Do not tunnel on the named condition while ignoring adjacent breakage. If the task has coupled visual requirements, validate each part separately and also judge their combined result as a whole. Example: an immersive/translucent WebView titlebar requires both (1) Web surface behind the titlebar for blur/material sampling and (2) inner Web content top avoidance so first content is not covered; even if both are technically present, QA must still reject if the final screen looks wrong to a human.

Layout nodes (`MaskBlur`, `HdsTitleBar`, etc.), source parity, build success, or navigation success are supporting evidence only; they cannot replace screenshot evidence for the actual visual condition. `PASS_WITH_LIMITATION` is forbidden for hard visual gates. Missing baseline screenshot, unstable reference capture, unverified criterion, or a visually suspicious result is `BLOCKED` or `FAIL`, not PASS.

Before installing or controlling the device, QA must prove hdc readiness with a real shell probe: `hdc tconn 192.168.50.237:12345`, wait about 2 seconds, then `hdc -t 192.168.50.237:12345 shell echo ok`. `Connect OK` or `list targets -v` showing `Connected` is not enough evidence because the target can appear connected before shell commands produce output. If the probe does not print `ok`, record QA as `BLOCKED` with the probe output instead of repeatedly reconnecting. Do not use `hdc tmode port ...` during normal QA unless the user explicitly asks to repair device connection mode.

If a later device command cannot find the target, stop that attempt, record the output, and restart QA from the standard hdc probe. Do not substitute `Connect OK` or `list targets` output for the shell probe.

If the scenario needs login or 2FA, follow [device-qa-login-2fa.md](device-qa-login-2fa.md).

## Integrate Gate

An integrate or commit-merge card must include a parent that is status=done with PASS conclusion from `qa`. Its body must explicitly reference the QA card id, run id, and artifact directory.

Reviewer PASS alone is not enough to authorize integrate.

## User Real-Device Ack Exception

When the user directly gives a real-device ack in conversation, the controller may close the corresponding `qa` card and treat the ack as equivalent evidence. The card summary must state "由用户实机 ack 闭环". Do not silently skip QA and do not fabricate worker-captured evidence.

## Post-Merge Repair

If a lane is discovered after merge to lack independent `qa`, create a post-merge `QA on device` card against current `master` HEAD. If that QA fails, use the normal revision flow. Do not retroactively rewrite reviewer PASS as QA PASS.

## Direct Worker Mode Mapping

In direct-worker controller mode, replace Kanban parent/child status with result JSON artifacts and controller verification. The same role separation and evidence rules still apply: implementation, read-only review, independent device QA, and integrate remain separate stages.
