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
# 注意：签名物料现统一放真实用户 home 的 .config/harmony/debug-signing/，不再 copy 进 worktree。

set +e  # 本脚本由调用方 source；只在硬阻塞时主动 exit

LANE_ART="${1:-}"
if [ -z "$LANE_ART" ]; then
  echo "lane-preflight: missing ART argument" >&2
  return 1 2>/dev/null || exit 1
fi
mkdir -p "$LANE_ART"
LANE_ART="$(cd "$LANE_ART" && pwd)"

V2NEXT_REPO=/home/gamer/git/V2Next
LANE_ROOT="$(pwd)"

# 1) PATH
export PATH="/home/gamer/devtool/ohos/command-line-tools/bin:/home/gamer/devtool/ohos/command-line-tools/ohpm/bin:/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains:/home/gamer/OpenHarmony/20/toolchains:$PATH"

# 1a) Restore ohpm dependencies for fresh git worktrees.
# Git worktrees do not carry untracked oh_modules. Without those HAR links,
# :entry:default@CompileArkTS can misreport imported @ComponentV2 components as
# "does not meet UI component syntax". Keep this in preflight so controller/worker
# build gates use the same dependency restore path as dev.sh instead of producing
# false environmental blockers.
if ! command -v ohpm >/dev/null 2>&1; then
  cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"missing_ohpm","artifact_dir":"$LANE_ART","hint":"OpenHarmony command-line-tools/bin or ohpm/bin is not on PATH"}
JSON
  echo "lane-preflight: ohpm not found → BLOCKED" >&2
  exit 1
fi

for module_dir in . shared feature/feed feature/detail feature/node feature/settings feature/user entry; do
  if [ -f "$LANE_ROOT/$module_dir/oh-package.json5" ]; then
    echo "lane-preflight: ohpm install $module_dir at $(date -Iseconds)" >> "$LANE_ART/preflight.log"
    (cd "$LANE_ROOT/$module_dir" && ohpm install >> "$LANE_ART/preflight.log" 2>&1)
    code=$?
    if [ "$code" -ne 0 ]; then
      cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"ohpm_install_failed","artifact_dir":"$LANE_ART","module":"$module_dir","exit_code":$code,"hint":"check $LANE_ART/preflight.log"}
JSON
      echo "lane-preflight: ohpm install failed for $module_dir → BLOCKED" >&2
      exit 1
    fi
  fi
done

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

# 2a) 签名物料绑定真实用户 home，而不是 worker HOME。source dev.env 后再次
# 固定这些路径，防止 profile/sandbox HOME 改写签名/profile 查找位置。
export V2NEXT_REAL_HOME="${V2NEXT_REAL_HOME:-/home/gamer}"
export HARMONY_DEBUG_DIR="${V2NEXT_REAL_HOME}/.config/harmony/debug-signing"
export HARMONY_DEBUG_PROFILE="${HARMONY_DEBUG_DIR}/profiles/com.next2v.app.p7b"
echo "lane-preflight: HOME=${HOME}; V2NEXT_REAL_HOME=${V2NEXT_REAL_HOME}; HARMONY_DEBUG_DIR=${HARMONY_DEBUG_DIR}" >> "$LANE_ART/preflight.log"

# 2b) 强制非交互签名模式：本地物料缺失时 sign.py 必须带明确路径快速失败，
# 不能打开浏览器登录并在 headless Kanban worker 里超时。
export NEXT2V_SIGN_NONINTERACTIVE=1

# 3) 本地签名材料优先。
# sign.py 的正常非交互路径是：debug.p12 + cert + profile 已存在时直接签名，跳过 AGC API。
# 因此 preflight 不能在材料齐全时先探测 AGC token；否则一个无关的 401 会把已可用的本地签名路径误报为 token 过期。
KS_FILE="$HARMONY_DEBUG_DIR/debug.p12"
CERT_FILE="$HARMONY_DEBUG_DIR/${HARMONY_DEBUG_CERT_NAME}.cer"
PROFILE_FILE="$HARMONY_DEBUG_PROFILE"
if [ -s "$KS_FILE" ] && [ -s "$CERT_FILE" ] && [ -s "$PROFILE_FILE" ]; then
  echo "lane-preflight: local signing materials present; skip AGC auth probe at $(date -Iseconds)" >> "$LANE_ART/preflight.log"
  return 0 2>/dev/null || exit 0
fi

# 4) 只有本地签名材料缺失时才检查 AGC auth，避免 worker 卡进 headless browser login。
"$V2NEXT_REPO/scripts/check-signing-auth.sh" >>"$LANE_ART/preflight.log" 2>&1
auth_code=$?
case "$auth_code" in
  0) ;;
  2)
    cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"signing_auth_missing","artifact_dir":"$LANE_ART","missing_materials":["$KS_FILE","$CERT_FILE","$PROFILE_FILE"],"action_required":"in main repo run: bash dev.sh --build-only (manual browser login)"}
JSON
    echo "lane-preflight: AUTH_FILE missing and local signing materials incomplete → BLOCKED" >&2
    exit 1 ;;
  3)
    cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"signing_auth_probe_401_with_missing_local_materials","artifact_dir":"$LANE_ART","missing_materials":["$KS_FILE","$CERT_FILE","$PROFILE_FILE"],"action_required":"in main repo run: bash dev.sh --build-only (refresh Huawei AGC auth or regenerate missing signing materials)"}
JSON
    echo "lane-preflight: AGC auth probe returned 401 and local signing materials incomplete → BLOCKED" >&2
    exit 1 ;;
  *)
    cat > "$LANE_ART/result.json" <<JSON
{"verdict":"BLOCKED","blocked_reason":"signing_auth_check_error_$auth_code","artifact_dir":"$LANE_ART","hint":"check $LANE_ART/preflight.log"}
JSON
    echo "lane-preflight: signing auth check error code=$auth_code" >&2
    exit 1 ;;
esac

echo "lane-preflight: OK at $(date -Iseconds)" >> "$LANE_ART/preflight.log"
