#!/usr/bin/env bash
# Lane wrapper preflight：在 hermes worker 起来前，把"签名+构建+设备"
# 路径上的共享前置条件检查掉。任何 lane wrapper 在调用 `hermes -p ... chat`
# 之前必须 source 它，并已经 cd 到 worktree 根。
#
# 调用约定：
#   cd /home/gamer/v2next-worktrees/<lane>
#   source /home/gamer/git/V2Next/scripts/lane-preflight.sh "$ART"
#
# $ART = 当前 lane 的 artifact 目录。BLOCKED 时会被写 result.json + exit 1。
#
# 副作用：
#   - source 主仓 scripts/dev.env（HARMONY_DEBUG_* / SCREEN_OFF_TIMEOUT_MS 等）
#   - 设置 PATH（ohpm + hdc + harmony toolchains）
#   - 调用 check-signing-auth.sh 验 Huawei AGC token；缺失/过期写 BLOCKED 并 exit
# 不写日志/不打印 secret。
#
# 注意：签名物料现统一放 ~/.config/harmony/debug-signing/，不再 copy 进 worktree。

set +e  # 本脚本由调用方 source；只在硬阻塞时主动 exit

LANE_ART="${1:-}"
if [ -z "$LANE_ART" ]; then
  echo "lane-preflight: missing ART argument" >&2
  return 1 2>/dev/null || exit 1
fi

V2NEXT_REPO=/home/gamer/git/V2Next

# 1) PATH
export PATH="/home/gamer/devtool/ohos/command-line-tools/bin:/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains:/home/gamer/OpenHarmony/20/toolchains:$PATH"

# 2) source dev.env（HARMONY_DEBUG_* 等）
if [ -f "$V2NEXT_REPO/scripts/dev.env" ]; then
  # shellcheck disable=SC1091
  source "$V2NEXT_REPO/scripts/dev.env"
else
  cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"missing_dev_env","artifact_dir":"$LANE_ART","hint":"$V2NEXT_REPO/scripts/dev.env not found"}
JSON
  echo "lane-preflight: $V2NEXT_REPO/scripts/dev.env not found → BLOCKED" >&2
  exit 1
fi

# 3) 签名 token 预检（绕过 headless browser login 死路）
"$V2NEXT_REPO/scripts/check-signing-auth.sh" >>"$LANE_ART/preflight.log" 2>&1
auth_code=$?
case "$auth_code" in
  0) ;;
  2)
    cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"signing_auth_missing","artifact_dir":"$LANE_ART","action_required":"in main repo run: bash dev.sh --build-only (manual browser login)"}
JSON
    echo "lane-preflight: AUTH_FILE missing → BLOCKED" >&2
    exit 1 ;;
  3)
    cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"signing_token_expired","artifact_dir":"$LANE_ART","action_required":"in main repo run: bash dev.sh --build-only (refresh Huawei AGC token via browser)"}
JSON
    echo "lane-preflight: signing token expired → BLOCKED" >&2
    exit 1 ;;
  *)
    cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"signing_auth_check_error_$auth_code","artifact_dir":"$LANE_ART","hint":"check $LANE_ART/preflight.log"}
JSON
    echo "lane-preflight: signing auth check error code=$auth_code" >&2
    exit 1 ;;
esac

echo "lane-preflight: OK at $(date -Iseconds)" >> "$LANE_ART/preflight.log"
