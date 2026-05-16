#!/bin/bash
# dev.sh - Next2V 鸿蒙开发一键脚本
#
# 用法:
#   bash dev.sh                   # debug 构建 + 签名 + 安装到缓存/选择的设备
#   bash dev.sh --build-only      # 仅构建 + 签名，不安装到设备
#   bash dev.sh -d all            # 安装到所有已连接设备（并刷新缓存时效）
#   bash dev.sh -d <device>       # 安装到指定设备（不影响缓存）
#   bash dev.sh --no-build        # 跳过构建，直接签名安装（沿用上次产物）
#   bash dev.sh --force-profile   # 强制重建证书和 Profile
#   bash dev.sh --refresh         # 强制刷新证书和 Profile（同 --force-profile）
#   bash dev.sh --log             # 查看设备 hilog
#   bash dev.sh --launch          # 启动应用
#   bash dev.sh -h | --help       # 显示此帮助
#
# 设备缓存:
#   首次运行若检测到多设备会交互提示选择，结果缓存 7 天。
#   缓存期内不带 -d 参数时自动使用上次选择的设备并刷新缓存时效。
#   -d all 时安装到全部设备，缓存设备在线则同步刷新其缓存时效。

set -e
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HDC=/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc
BUNDLE=com.next2v.app

keep_awake() {
  if [ -n "${HDC_TARGET:-}" ]; then
    "$PROJ/scripts/keep_awake.sh" -t "$HDC_TARGET" >/dev/null 2>&1 || true
  else
    "$PROJ/scripts/keep_awake.sh" >/dev/null 2>&1 || true
  fi
}

ensure_ohpm_dependencies() {
  if ! command -v ohpm >/dev/null 2>&1; then
    echo "错误: 未找到 ohpm，请先把 OpenHarmony command-line-tools/bin 加入 PATH" >&2
    exit 1
  fi

  local module_dirs=(
    "."
    "shared"
    "feature/feed"
    "feature/detail"
    "feature/node"
    "feature/settings"
    "feature/user"
    "entry"
  )

  echo "==> 检查/恢复 ohpm 依赖..."
  for module_dir in "${module_dirs[@]}"; do
    if [ -f "$PROJ/$module_dir/oh-package.json5" ]; then
      echo "   - ohpm install $module_dir"
      (cd "$PROJ/$module_dir" && ohpm install)
    fi
  done
}

case "$1" in
  -h|--help)
    cat <<'EOF'
dev.sh - Next2V 鸿蒙开发一键脚本

用法:
  bash dev.sh                   debug 构建 + 签名 + 安装到缓存/选择的设备
  bash dev.sh --build-only      仅构建 + 签名，不安装到设备
  bash dev.sh -d all            安装到所有已连接设备（并刷新缓存时效）
  bash dev.sh -d <device>       安装到指定设备（不影响缓存）
  bash dev.sh --no-build        跳过构建，直接签名安装（沿用上次产物）
  bash dev.sh --force-profile   强制重建证书和 Profile
  bash dev.sh --refresh         强制刷新证书和 Profile（同 --force-profile）
  bash dev.sh --log             查看设备 hilog
  bash dev.sh --launch          启动应用
  bash dev.sh -h | --help       显示此帮助

设备缓存:
  首次运行若检测到多设备会交互提示选择，结果缓存 7 天。
  缓存期内不带 -d 参数时自动使用上次选择的设备并刷新缓存时效。
  -d all 时安装到全部设备，缓存设备在线则同步刷新其缓存时效。
EOF
    ;;
  --log)
    keep_awake
    "$HDC" shell "hilog | grep -i next2v"
    ;;
  --launch)
    keep_awake
    "$HDC" shell "aa start -a EntryAbility -b $BUNDLE"
    ;;
  --refresh)
    echo "==> Force-refreshing certificate and profile..."
    rm -f "$PROJ/scripts/next2v-debug.cer" "$PROJ/scripts/next2v-debug.p7b"
    python3 "$PROJ/scripts/sign.py" --force-profile
    ;;
  --build-only)
    shift
    ensure_ohpm_dependencies
    echo "==> 构建 HAP..."
    cd "$PROJ"
    hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
    python3 "$PROJ/scripts/sign.py" --no-install "$@"
    ;;
  --no-build)
    shift
    python3 "$PROJ/scripts/sign.py" "$@"
    ;;
  *)
    # 构建 + 签名 + 安装
    keep_awake
    ensure_ohpm_dependencies
    echo "==> 构建 HAP..."
    cd "$PROJ"
    hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
    python3 "$PROJ/scripts/sign.py" "$@"
    ;;
esac
