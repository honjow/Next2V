#!/bin/bash
# dev.sh - Next2V 鸿蒙开发一键脚本
#
# 用法:
#   bash dev.sh                   # debug 构建 + 签名 + 安装到缓存/选择的设备
#   bash dev.sh --build-only      # debug 仅构建 + 签名，不安装到设备
#   bash dev.sh --release-build-only # release 仅构建 + 签名，不安装到设备
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
# 加载共享 env（HarmonyOS 调试签名物料路径等）
if [ -f "$PROJ/scripts/dev.env" ]; then
  # shellcheck disable=SC1091
  source "$PROJ/scripts/dev.env"
fi
HDC=/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc
BUNDLE=com.next2v.app
DEBUG_BUNDLE=com.next2v.app
RELEASE_BUNDLE=com.honjow.next2v

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

set_app_bundle_name() {
  local bundle_name="$1"
  python3 - "$PROJ/AppScope/app.json5" "$bundle_name" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
bundle = sys.argv[2]
text = path.read_text(encoding="utf-8")
text = text.replace('"bundleName": "com.next2v.app"', f'"bundleName": "{bundle}"')
text = text.replace('"bundleName": "com.honjow.next2v"', f'"bundleName": "{bundle}"')
path.write_text(text, encoding="utf-8")
PY
}

restore_debug_bundle_name() {
  set_app_bundle_name "$DEBUG_BUNDLE"
}

restore_release_bundle_name() {
  set_app_bundle_name "$RELEASE_BUNDLE"
}

current_app_bundle_name() {
  python3 - "$PROJ/AppScope/app.json5" <<'PY'
from pathlib import Path
import json
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(data.get("app", {}).get("bundleName", ""))
PY
}

hap_bundle_name() {
  local hap_path="$1"
  python3 - "$hap_path" <<'PY'
import json
import sys
import zipfile

hap = sys.argv[1]
with zipfile.ZipFile(hap) as zf:
    data = json.loads(zf.read("module.json").decode("utf-8"))
print(data.get("app", {}).get("bundleName", ""))
PY
}

assert_hap_bundle_name() {
  local hap_path="$1"
  local expected_bundle="$2"
  if [ ! -f "$hap_path" ]; then
    echo "错误: HAP 不存在，无法校验包名: $hap_path" >&2
    exit 1
  fi
  local actual_bundle
  actual_bundle="$(hap_bundle_name "$hap_path")"
  echo "==> 校验 HAP 包名: $actual_bundle"
  if [ "$actual_bundle" != "$expected_bundle" ]; then
    echo "错误: HAP 包名不符合预期，expected=$expected_bundle actual=$actual_bundle" >&2
    exit 1
  fi
}

case "$1" in
  -h|--help)
    cat <<'EOF'
dev.sh - Next2V 鸿蒙开发一键脚本

用法:
  bash dev.sh                   debug 构建 + 签名 + 安装到缓存/选择的设备
  bash dev.sh --build-only      debug 仅构建 + 签名，不安装到设备
  bash dev.sh --release-build-only release 仅构建 + 签名，不安装到设备
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
    DEBUG_APP_SCOPE_BACKUP="$(mktemp)"
    cp "$PROJ/AppScope/app.json5" "$DEBUG_APP_SCOPE_BACKUP"
    cleanup_debug_packaging() {
      local status=0
      if [ -n "${DEBUG_APP_SCOPE_BACKUP:-}" ] && [ -f "$DEBUG_APP_SCOPE_BACKUP" ]; then
        cp "$DEBUG_APP_SCOPE_BACKUP" "$PROJ/AppScope/app.json5" || status=$?
        rm -f "$DEBUG_APP_SCOPE_BACKUP"
      else
        restore_release_bundle_name || status=$?
      fi
      return "$status"
    }
    trap cleanup_debug_packaging EXIT
    restore_debug_bundle_name
    echo "==> Debug bundleName: $(current_app_bundle_name)"
    hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
    assert_hap_bundle_name "$PROJ/entry/build/default/outputs/default/entry-default-unsigned.hap" "$DEBUG_BUNDLE"
    cleanup_debug_packaging
    trap - EXIT
    python3 "$PROJ/scripts/sign.py" --no-install "$@"
    ;;
  --release-build-only)
    shift
    ensure_ohpm_dependencies
    echo "==> 构建 release HAP..."
    cd "$PROJ"
    RELEASE_BUILD_PROFILE_BACKUP_DIR="$(mktemp -d)"
    APP_SCOPE_BACKUP="$RELEASE_BUILD_PROFILE_BACKUP_DIR/AppScope-app.json5"
    backup_release_build_profiles() {
      cp "$PROJ/AppScope/app.json5" "$APP_SCOPE_BACKUP"
      local profile
      for profile in "$PROJ"/shared/BuildProfile.ets "$PROJ"/feature/*/BuildProfile.ets; do
        [ -f "$profile" ] || continue
        mkdir -p "$RELEASE_BUILD_PROFILE_BACKUP_DIR/$(dirname "${profile#$PROJ/}")"
        cp "$profile" "$RELEASE_BUILD_PROFILE_BACKUP_DIR/${profile#$PROJ/}"
      done
    }
    restore_release_build_profiles() {
      local backup relpath
      [ -n "${RELEASE_BUILD_PROFILE_BACKUP_DIR:-}" ] && [ -d "$RELEASE_BUILD_PROFILE_BACKUP_DIR" ] || return 0
      if [ -f "$APP_SCOPE_BACKUP" ]; then
        cp "$APP_SCOPE_BACKUP" "$PROJ/AppScope/app.json5"
      fi
      while IFS= read -r -d '' backup; do
        relpath="${backup#$RELEASE_BUILD_PROFILE_BACKUP_DIR/}"
        cp "$backup" "$PROJ/$relpath"
      done < <(find "$RELEASE_BUILD_PROFILE_BACKUP_DIR" -type f -name BuildProfile.ets -print0)
      rm -rf "$RELEASE_BUILD_PROFILE_BACKUP_DIR"
    }
    cleanup_release_packaging() {
      local status=0
      python3 "$PROJ/scripts/prune-release-media-resources.py" --restore || status=$?
      restore_release_build_profiles || status=$?
      return "$status"
    }
    backup_release_build_profiles
    trap cleanup_release_packaging EXIT
    set_app_bundle_name "$RELEASE_BUNDLE"
    echo "==> Release bundleName: $(current_app_bundle_name)"
    python3 "$PROJ/scripts/prune-release-media-resources.py" --apply
    hvigorw assembleHap --mode module -p product=default -p buildMode=release --no-daemon
    assert_hap_bundle_name "$PROJ/entry/build/default/outputs/default/entry-default-unsigned.hap" "$RELEASE_BUNDLE"
    python3 "$PROJ/scripts/sign.py" --no-install "$@"
    cleanup_release_packaging
    trap - EXIT
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
    DEBUG_APP_SCOPE_BACKUP="$(mktemp)"
    cp "$PROJ/AppScope/app.json5" "$DEBUG_APP_SCOPE_BACKUP"
    cleanup_debug_packaging() {
      local status=0
      if [ -n "${DEBUG_APP_SCOPE_BACKUP:-}" ] && [ -f "$DEBUG_APP_SCOPE_BACKUP" ]; then
        cp "$DEBUG_APP_SCOPE_BACKUP" "$PROJ/AppScope/app.json5" || status=$?
        rm -f "$DEBUG_APP_SCOPE_BACKUP"
      else
        restore_release_bundle_name || status=$?
      fi
      return "$status"
    }
    trap cleanup_debug_packaging EXIT
    restore_debug_bundle_name
    echo "==> Debug bundleName: $(current_app_bundle_name)"
    hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
    assert_hap_bundle_name "$PROJ/entry/build/default/outputs/default/entry-default-unsigned.hap" "$DEBUG_BUNDLE"
    cleanup_debug_packaging
    trap - EXIT
    python3 "$PROJ/scripts/sign.py" "$@"
    ;;
esac
