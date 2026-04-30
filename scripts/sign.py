#!/usr/bin/env python3
"""Next2V HAP 签名安装脚本"""
import sys, os, json, subprocess, urllib.request, urllib.error, random, webbrowser
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler

PROJ        = Path(__file__).resolve().parent.parent
SCRIPTS     = Path(__file__).resolve().parent
SIGN_DIR    = SCRIPTS
TOOL_LIB    = Path("/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/lib")
HAP_SIGN    = TOOL_LIB / "hap-sign-tool.jar"
HDC         = Path("/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc")
UNSIGNED_HAP = PROJ / "entry/build/default/outputs/default/entry-default-unsigned.hap"

BUNDLE_NAME = "com.next2v.app"
CERT_NAME   = "next2v-debug"

KS_FILE     = SCRIPTS / "xiaobai.p12"
KS_ALIAS    = "xiaobai"
KS_PWD      = "xiaobai123"
CSR         = SCRIPTS / "xiaobai.csr"

CERT_FILE   = SCRIPTS / f"{CERT_NAME}.cer"
PROFILE_FILE = SCRIPTS / f"{CERT_NAME}.p7b"
AUTH_FILE   = Path.home() / "Documents/hap_installer/userInfo.json"

ECO_URL = "https://cn.devecostudio.huawei.com/console/DevEcoIDE/apply?port={port}&appid=1007&code=20698961dd4f420c8b44f49010c6f0cc"

# ── API ───────────────────────────────────────────────────────
def api(url, data=None, method=None, headers=None, auth=None, raw=False):
    method = method or ("POST" if data else "GET")
    body = json.dumps(data).encode() if data else None
    h = {"content-type": "application/json"}
    if auth:
        h["oauth2Token"] = auth.get("accessToken", "")
        h["teamId"] = h["uid"] = auth.get("userId", "")
    if headers: h.update(headers)
    req = urllib.request.Request(url, data=body, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            text = resp.read().decode()
            if raw: return text
            try: return json.loads(text)
            except json.JSONDecodeError: return text
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read().decode()[:200]}")

def download(url, dest):
    urllib.request.urlretrieve(url, dest)

# ── 登录 ──────────────────────────────────────────────────────
class CallbackHandler(BaseHTTPRequestHandler):
    result = None
    def log_message(self, *a): pass
    def do_POST(self):
        if self.path == "/callback":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write("OK - back to terminal".encode())
            CallbackHandler.result = self.rfile.read(int(self.headers["Content-Length"])).decode()
        else:
            self.send_response(404); self.end_headers()

def login():
    port = random.randint(8333, 9333)
    server = HTTPServer(("127.0.0.1", port), CallbackHandler)
    server.timeout = 120
    print(f"\n浏览器登录: {ECO_URL.format(port=port)}")
    webbrowser.open(ECO_URL.format(port=port))
    print("等待登录回调 (120s)...")
    while CallbackHandler.result is None:
        server.handle_request()
    from urllib.parse import parse_qs, urlparse
    body = CallbackHandler.result
    params = parse_qs(body) if "=" in body else {}
    temp = params.get("tempToken", [body])[0] if params else body
    resp = api(f"https://cn.devecostudio.huawei.com/authrouter/auth/api/temptoken/check?site=CN&tempToken={temp}&appid=1007&version=0.0.0", method="GET")
    jwt = resp if isinstance(resp, str) else resp.get("ret", {}).get("msg", str(resp))
    user_resp = api("https://cn.devecostudio.huawei.com/authrouter/auth/api/jwToken/check", method="GET", headers={"refresh": "false", "jwtToken": jwt})
    info = (user_resp.get("userInfo") or user_resp.get("body", {}).get("userInfo") or user_resp) if isinstance(user_resp, dict) else {}
    auth = {"accessToken": info.get("accessToken"), "userId": info.get("userId") or info.get("userID"),
            "teamId": info.get("userId") or info.get("userID"), "nickName": info.get("nickName", "")}
    AUTH_FILE.parent.mkdir(parents=True, exist_ok=True)
    AUTH_FILE.write_text(json.dumps(auth, indent=2))
    print(f"登录成功: {auth['nickName']} (uid={auth['userId']})")
    return auth

def load_or_login():
    if AUTH_FILE.exists():
        auth = json.loads(AUTH_FILE.read_text())
        try:
            if api("https://connect-api.cloud.huawei.com/api/ups/user-permission-service/v1/user-team-list", method="GET", auth=auth).get("ret", {}).get("code") == 401:
                raise RuntimeError("expired")
            print(f"使用缓存: {auth.get('nickName', '?')}")
            return auth
        except: pass
    return login()

# ── 证书 ─────────────────────────────────────────────────────
def ensure_cert(auth):
    cert_list = api("https://connect-api.cloud.huawei.com/api/cps/harmony-cert-manage/v1/cert/list", method="GET", auth=auth).get("certList", [])
    debug_certs = [c for c in cert_list if c.get("certType") == 1]
    existing = next((c for c in debug_certs if c.get("certName") == CERT_NAME), None)
    if existing and CERT_FILE.exists():
        print(f"证书已存在: {CERT_NAME}")
        return existing["id"]
    # Check limit: max 3 debug certs
    if len(cert_list) >= 3 and not existing:
        debug_certs.sort(key=lambda c: c.get("expireTime", 0))
        old = debug_certs[0]
        print(f"证书数达上限，删除最旧: {old.get('certName')}")
        api("https://connect-api.cloud.huawei.com/api/cps/harmony-cert-manage/v1/cert/delete",
            data={"certIds": [old["id"]]}, method="DELETE", auth=auth)
    if not existing:
        csr_text = CSR.read_text()
        print(f"创建证书: {CERT_NAME} (CSR={len(csr_text)} bytes)")
        result = api("https://connect-api.cloud.huawei.com/api/cps/harmony-cert-manage/v1/cert/add",
                     data={"csr": csr_text, "certName": CERT_NAME, "certType": 1}, auth=auth)
        print(f"API响应: {json.dumps(result, ensure_ascii=False)[:300]}")
        existing = result.get("harmonyCert", {})
        if not existing: raise RuntimeError(f"证书创建失败: {result}")
    obj_id = existing.get("certObjectId")
    urls = api("https://connect-api.cloud.huawei.com/api/amis/app-manage/v1/objects/url/reapply",
               data={"sourceUrls": obj_id}, auth=auth)
    url = urls.get("urlsInfo", [{}])[0].get("newUrl")
    download(url, CERT_FILE)
    print(f"证书下载完成: {CERT_NAME}")
    return existing["id"]

# ── 设备 ─────────────────────────────────────────────────────
def get_udid():
    result = subprocess.run([str(HDC), "shell", "bm", "get", "--udid"], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if "udid" in line.lower():
            parts = line.split(":")
            if len(parts) > 1: return parts[-1].strip()
    raise RuntimeError("无法获取设备 UDID")

def ensure_device(auth, udid):
    devices = api("https://connect-api.cloud.huawei.com/api/cps/device-manage/v1/device/list?start=1&pageSize=100&encodeFlag=0", method="GET", auth=auth).get("list", [])
    if not any(d.get("udid") == udid for d in devices):
        api("https://connect-api.cloud.huawei.com/api/cps/device-manage/v1/device/add",
            data={"deviceName": f"next2v-dev-{udid[:10]}", "udid": udid, "deviceType": 4}, auth=auth)
        devices = api("https://connect-api.cloud.huawei.com/api/cps/device-manage/v1/device/list?start=1&pageSize=100&encodeFlag=0", method="GET", auth=auth).get("list", [])
    return [d["id"] for d in devices]

# ── Profile ─────────────────────────────────────────────────
def ensure_profile(auth, cert_id, device_ids):
    name = f"next2v-debug_{BUNDLE_NAME.replace('.', '_')}"
    result = api("https://connect-api.cloud.huawei.com/api/cps/provision-manage/v1/ide/test/provision/add",
                 data={"provisionName": name, "aclPermissionList": [], "deviceList": device_ids,
                       "certList": [cert_id], "packageName": BUNDLE_NAME}, auth=auth)
    url = result.get("provisionFileUrl")
    if not url: raise RuntimeError(f"Profile 创建失败: {result}")
    download(url, PROFILE_FILE)
    print(f"Profile 下载完成")

# ── 签名 & 安装 ─────────────────────────────────────────────
def sign_and_install():
    signed = PROJ / "entry/build/default/outputs/default/entry-default-signed.hap"
    cmd = ["java", "-jar", str(HAP_SIGN), "sign-app",
           "-mode", "localSign", "-keyAlias", KS_ALIAS, "-keyPwd", KS_PWD,
           "-appCertFile", str(CERT_FILE), "-profileFile", str(PROFILE_FILE),
           "-inFile", str(UNSIGNED_HAP), "-signAlg", "SHA256withECDSA",
           "-keystoreFile", str(KS_FILE), "-keystorePwd", KS_PWD,
           "-compatibleVersion", "8", "-outFile", str(signed)]
    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stdout + result.stderr)
    if "sign-app success" not in result.stdout + result.stderr:
        raise RuntimeError("签名失败")
    print("安装 HAP...")
    result = subprocess.run([str(HDC), "install", str(signed)], capture_output=True, text=True)
    print(result.stdout + result.stderr)

# ── main ────────────────────────────────────────────────────
def main():
    if not UNSIGNED_HAP.exists():
        print(f"ERROR: 未找到 {UNSIGNED_HAP}，请先构建")
        sys.exit(1)

    if CERT_FILE.exists() and PROFILE_FILE.exists() and "--refresh" not in sys.argv:
        print("证书和 Profile 已存在，跳过 AGC API...")
        sign_and_install()
        return

    auth = load_or_login()
    cert_id = ensure_cert(auth)
    udid = get_udid()
    device_ids = ensure_device(auth, udid)
    if not PROFILE_FILE.exists() or "--refresh" in sys.argv:
        ensure_profile(auth, cert_id, device_ids)
    sign_and_install()
    print("完成！")

if __name__ == "__main__":
    main()
