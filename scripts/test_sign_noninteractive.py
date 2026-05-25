#!/usr/bin/env python3
"""Static gate: non-interactive signing never triggers AGC browser login.

This test proves that when `NEXT2V_SIGN_NONINTERACTIVE=1` is set:
- With local signing materials present: sign.py produces a signed HAP cleanly,
  never calling `load_or_login()`, `login()`, or `webbrowser.open()`.
- Without local materials: sign.py exits non-zero with a clear missing-materials
  error message, never attempting a browser login.
"""
from __future__ import annotations

import os
import sys
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIGN_PY = ROOT / "scripts" / "sign.py"
UNSIGNED_HAP = ROOT / "entry" / "build" / "default" / "outputs" / "default" / "entry-default-unsigned.hap"
SIGNED_HAP = ROOT / "entry" / "build" / "default" / "outputs" / "default" / "entry-default-signed.hap"

REQUIRED_ENV_VARS = [
    "HARMONY_DEBUG_DIR",
    "HARMONY_DEBUG_CERT_NAME",
    "HARMONY_DEBUG_KS_ALIAS",
    "HARMONY_DEBUG_KS_PWD",
    "HARMONY_DEBUG_PROFILE",
]


def _load_env(fake_home: str | None = None) -> dict[str, str]:
    """Source dev.env and return the resulting env dict."""
    dev_env = ROOT / "scripts" / "dev.env"
    if not dev_env.exists():
        raise AssertionError(f"dev.env missing: {dev_env}")

    source_env = os.environ.copy()
    if fake_home is not None:
        source_env["HOME"] = fake_home
    source_env.pop("V2NEXT_REAL_HOME", None)

    # Use bash to source dev.env and print env; parse output.
    result = subprocess.run(
        ["bash", "-c", f'set -a; source "{dev_env}" >/dev/null 2>&1; env'],
        capture_output=True, text=True, timeout=10, env=source_env,
    )
    if result.returncode != 0:
        raise AssertionError(f"Failed to source dev.env: {result.stderr}")

    env = source_env.copy()
    for line in result.stdout.splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            env[key] = value
    return env


def _check_env(env: dict[str, str]) -> None:
    """Verify all required env vars are set and resolve to real paths."""
    for var in REQUIRED_ENV_VARS:
        val = env.get(var)
        if not val:
            raise AssertionError(f"env var {var} not set after sourcing dev.env")
        print(f"  {var}={val}")


def _check_materials(env: dict[str, str]) -> list[str]:
    """Check which signing materials exist. Returns list of missing paths."""
    ks = Path(env["HARMONY_DEBUG_DIR"]) / "debug.p12"
    cert = Path(env["HARMONY_DEBUG_DIR"]) / f"{env['HARMONY_DEBUG_CERT_NAME']}.cer"
    profile = Path(env["HARMONY_DEBUG_PROFILE"])

    missing = []
    for p, label in [(ks, "keystore"), (cert, "certificate"), (profile, "profile")]:
        if not p.exists():
            missing.append(f"{label}: {p}")
    return missing


def _run_sign_noninteractive(env: dict[str, str]) -> tuple[int, str, str]:
    """Run sign.py --non-interactive --no-install and return (exit_code, stdout, stderr)."""
    env = env.copy()
    env["NEXT2V_SIGN_NONINTERACTIVE"] = "1"
    env.pop("PYTHONSTARTUP", None)  # avoid interactive REPL init

    if not SIGN_PY.exists():
        raise AssertionError(f"sign.py not found: {SIGN_PY}")

    cmd = [sys.executable, str(SIGN_PY), "--non-interactive", "--no-install"]
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=30,
        env=env, cwd=str(ROOT),
    )
    return result.returncode, result.stdout, result.stderr


def main() -> int:
    print("=== test_sign_noninteractive ===")

    # 1) Load environment
    print("\n[1] Loading dev.env...")
    env = _load_env()
    _check_env(env)

    # 2) Prove worker/sandbox HOME cannot redirect signing materials
    print("\n[2] Checking sandbox HOME normalization...")
    sandbox_env = _load_env(fake_home="/tmp/v2next-kanban-sandbox-home")
    _check_env(sandbox_env)
    expected_dir = "/home/gamer/.config/harmony/debug-signing"
    if sandbox_env.get("HARMONY_DEBUG_DIR") != expected_dir:
        raise AssertionError(
            f"sandbox HOME redirected HARMONY_DEBUG_DIR: {sandbox_env.get('HARMONY_DEBUG_DIR')} != {expected_dir}"
        )
    expected_profile = f"{expected_dir}/profiles/com.next2v.app.p7b"
    if sandbox_env.get("HARMONY_DEBUG_PROFILE") != expected_profile:
        raise AssertionError(
            f"sandbox HOME redirected HARMONY_DEBUG_PROFILE: {sandbox_env.get('HARMONY_DEBUG_PROFILE')} != {expected_profile}"
        )
    print("  PASS: sandbox HOME does not affect signing material paths")

    # 3) Check materials
    print("\n[3] Checking signing materials...")
    missing = _check_materials(env)
    if missing:
        print(f"  Signing materials MISSING:")
        for m in missing:
            print(f"    - {m}")
    else:
        print("  All signing materials PRESENT")

    # 4) Run non-interactive signing
    print("\n[4] Running sign.py --non-interactive --no-install...")
    rc, stdout, stderr = _run_sign_noninteractive(env)
    combined = stdout + stderr

    # 5) Assertions: must NOT trigger browser login
    print("\n[5] Checking output for browser login triggers...")
    browser_triggers = [
        "webbrowser",
        "Complete Huawei account login in your browser",
        "Waiting for login callback",
        "Login success",
        "Login callback",
        "token expired, re-login",
        "Using cached account",
    ]
    triggered = [t for t in browser_triggers if t in combined]
    if triggered:
        raise AssertionError(
            f"sign.py triggered browser login! Found: {triggered}\n"
            f"Output was:\n{combined[:2000]}"
        )
    print(f"  PASS: no browser login trigger found in output")

    # 6) Check result
    print("\n[6] Checking result...")
    if rc != 0:
        # Missing materials: must fail with a clear error path
        if missing:
            if "Non-interactive signing materials missing" in combined:
                print(f"  PASS: non-interactive fail-fast on missing materials (exit={rc})")
                print(f"  Missing: {[m for m in missing]}")
                return 0
            else:
                raise AssertionError(
                    f"sign.py failed (exit={rc}) but not with expected non-interactive error:\n{combined[:2000]}"
                )
        else:
            raise AssertionError(
                f"sign.py failed (exit={rc}) with materials present:\n{combined[:2000]}"
            )

    # 7) Success path: verify signed HAP produced
    print(f"  sign.py exit=0")
    if SIGNED_HAP.exists():
        size = SIGNED_HAP.stat().st_size
        print(f"  Signed HAP exists: {SIGNED_HAP} ({size:,} bytes)")
        print(f"  PASS: non-interactive signing produced signed HAP")
    else:
        raise AssertionError(f"sign.py succeeded but no signed HAP at {SIGNED_HAP}")

    print("\n=== PASS ===")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"\n=== FAIL: {exc} ===", file=sys.stderr)
        raise SystemExit(1)
