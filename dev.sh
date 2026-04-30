#!/bin/bash
# Next2V dev script
# 用法:
#   bash dev.sh                    # 构建+签名+安装
#   bash dev.sh --no-build         # 跳过构建，直接签名安装
#   bash dev.sh --refresh          # 强制刷新证书和 Profile
#   bash dev.sh --log              # 查看 hilog
set -e

PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HDC=/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc
BUNDLE=com.next2v.app

# 防锁屏
if [ "$1" != "--log" ]; then
  "$HDC" shell "power-shell wakeup" 2>/dev/null || true
  "$HDC" shell "power-shell timeout -o 3600000" 2>/dev/null || true
fi

case "$1" in
  --no-build)
    python3 "$PROJ/scripts/sign.py" --no-build
    ;;
  --refresh)
    python3 "$PROJ/scripts/sign.py" --refresh
    ;;
  --log)
    "$HDC" shell "hilog -b D | grep -i next2v || hilog | grep -i next2v"
    ;;
  --launch)
    "$HDC" shell "aa start -a EntryAbility -b $BUNDLE"
    ;;
  *)
    # 构建
    echo "==> 构建 HAP..."
    cd "$PROJ"
    hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
    # 签名+安装
    python3 "$PROJ/scripts/sign.py"
    ;;
esac
