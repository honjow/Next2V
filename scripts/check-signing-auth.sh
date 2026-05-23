#!/usr/bin/env bash
# 检查华为 AGC 签名 token 是否仍可用。
# 退出码：
#   0 = token 有效
#   2 = AUTH_FILE 不存在（首次需手动 login）
#   3 = token 401 过期
#   4 = 网络/其他错误
# 不打印 token 值，只回 0/1 状态。
exec python3 - <<'PY'
import json, sys, urllib.request, urllib.error
from pathlib import Path
af = Path.home() / "Documents" / "hap_installer" / "userInfo.json"
if not af.exists():
    print("auth_file_missing", file=sys.stderr)
    sys.exit(2)
try:
    auth = json.loads(af.read_text())
except Exception as e:
    print(f"auth_file_malformed: {e}", file=sys.stderr)
    sys.exit(4)
req = urllib.request.Request(
    "https://connect-api.cloud.huawei.com/api/ups/user-permission-service/v1/user-team-list",
    headers={
        "content-type": "application/json",
        "oauth2Token": auth.get("accessToken", ""),
        "teamId":      auth.get("userId", ""),
        "uid":         auth.get("userId", ""),
    },
    method="GET",
)
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read())
        code = (data.get("ret") or {}).get("code")
        if code == 401:
            print("token_expired", file=sys.stderr); sys.exit(3)
        print("auth_ok")
        sys.exit(0)
except urllib.error.HTTPError as e:
    if e.code == 401:
        print("http_401", file=sys.stderr); sys.exit(3)
    print(f"http_error_{e.code}", file=sys.stderr); sys.exit(4)
except Exception as e:
    print(f"net_error: {type(e).__name__}", file=sys.stderr); sys.exit(4)
PY
