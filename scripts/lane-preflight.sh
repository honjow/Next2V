#!/usr/bin/env bash
# Lane wrapper preflight：在 hermes worker 起来前，把所有"签名+构建+设备"路径上的
# 共享前置条件检查掉。任何 lane wrapper 在调用 `hermes -p ... chat` 之前必须 source 它。
#
# 调用约定：
#   source /home/gamer/git/V2Next/scripts/lane-preflight.sh "$ART"
#
# $ART = 当前 lane 的 artifact 目录，BLOCKED 时会被写 result.json。
#
# 副作用：
#   - 设置 PATH（含 ohpm + hdc）
#   - 调用 sync-signing-materials.sh 把 4 个签名物料 install 进当前 worktree
#   - 调用 check-signing-auth.sh 验 token；token 过期/缺失则写 BLOCKED 并 exit
# 不写日志/不打印 secret。

set +e  # 让调用方自己控制错误处理；本脚本只在硬阻塞时主动 exit

LANE_ART="${1:-}"
if [ -z "$LANE_ART" ]; then
  echo "lane-preflight: missing ART argument" >&2
  return 1 2>/dev/null || exit 1
fi

# 1) PATH（避免 wrapper 各自重复声明）
export PATH="/home/gamer/devtool/ohos/command-line-tools/bin:/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains:/home/gamer/OpenHarmony/20/toolchains:$PATH"

V2NEXT_REPO=/home/gamer/git/V2Next

# 2) 同步签名物料到当前 worktree
#    用 PWD 推断 worktree 根（wrapper 在调本脚本前已 cd 到 worktree）。
WORKTREE_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
WORKTREE_SCRIPTS="$WORKTREE_ROOT/scripts"
mkdir -p "$WORKTREE_SCRIPTS"
if [ -x "$V2NEXT_REPO/scripts/sync-signing-materials.sh" ]; then
  if ! bash "$V2NEXT_REPO/scripts/sync-signing-materials.sh" \
        "$V2NEXT_REPO/scripts" --dest "$WORKTREE_SCRIPTS" \
        >>"$LANE_ART/preflight.log" 2>&1; then
    cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"sync_signing_materials_failed","artifact_dir":"$LANE_ART","worktree":"$WORKTREE_ROOT","hint":"check $LANE_ART/preflight.log"}
JSON
    echo "lane-preflight: sync-signing-materials.sh FAILED → $LANE_ART/preflight.log" >&2
    exit 1
  fi
fi

# 3) 签名 token 预检（绕过 headless browser login 死路）
"$V2NEXT_REPO/scripts/check-signing-auth.sh" >>"$LANE_ART/preflight.log" 2>&1
auth_code=$?
case "$auth_code" in
  0) ;;  # ok
  2)
    cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"signing_auth_missing","artifact_dir":"$LANE_ART","action_required":"main repo run: bash dev.sh --build-only (manual browser login)"}
JSON
    echo "lane-preflight: AUTH_FILE missing, BLOCKED" >&2
    exit 1 ;;
  3)
    cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"signing_token_expired","artifact_dir":"$LANE_ART","action_required":"main repo run: bash dev.sh --build-only (manual browser login to refresh token)"}
JSON
    echo "lane-preflight: signing token expired, BLOCKED" >&2
    exit 1 ;;
  *)
    cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"signing_auth_check_error_$auth_code","artifact_dir":"$LANE_ART","hint":"check $LANE_ART/preflight.log"}
JSON
    echo "lane-preflight: signing auth check error code=$auth_code" >&2
    exit 1 ;;
esac

echo "lane-preflight: OK at $(date -Iseconds)" >> "$LANE_ART/preflight.log"
