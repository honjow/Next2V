#!/usr/bin/env python3
"""Static contract checks for V2Next network proxy lane."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding='utf-8')


def require(name: str, condition: bool, detail: str = '') -> None:
    if not condition:
        suffix = f': {detail}' if detail else ''
        raise AssertionError(f'{name}{suffix}')
    print(f'PASS {name}')


def main() -> int:
    settings = read('shared/src/main/ets/settings/NetworkProxySettings.ets')
    adapter = read('shared/src/main/ets/network/NetworkProxyRequest.ets')
    storage = read('shared/src/main/ets/constants/StorageKeys.ets')
    bootstrap = read('shared/src/main/ets/settings/SettingsBootstrap.ets')
    settings_page = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
    proxy_page = read('feature/settings/src/main/ets/pages/NetworkProxySettingsPage.ets')
    routes = read('entry/src/main/ets/model/IndexRouteCoordinator.ets') + read('entry/src/main/ets/pages/Index.ets')

    for mode in ["'off'", "'system'", "'http'", "'socks5'"]:
        require(f'mode {mode}', mode in settings)

    for key in [
        'NETWORK_PROXY_ENABLED', 'NETWORK_PROXY_ACTIVE_PROFILE_ID', 'NETWORK_PROXY_PROFILES',
        'NETWORK_PROXY_MODE', 'NETWORK_PROXY_HOST', 'NETWORK_PROXY_PORT',
        'NETWORK_PROXY_USERNAME', 'NETWORK_PROXY_PASSWORD', 'NETWORK_PROXY_EXCLUSION_LIST'
    ]:
        require(f'storage key {key}', key in storage and key in settings)

    require('settings persist json', 'writeJsonValue<NetworkProxyProfilesSnapshot>' in settings and 'readJsonObject<Object>' in settings)
    require('profile model exists', 'NetworkProxyProfile' in settings and 'NetworkProxyProfilesSnapshot' in settings)
    require('built-in system proxy id', 'SYSTEM_PROFILE_ID' in settings and "'system'" in settings)
    require('legacy migration', 'migrateLegacy' in settings and 'normalizeProfilesFromPersisted' in settings)
    require('host validation', 'isValidHost' in settings and '请输入有效代理主机' in settings)
    require('port validation', 'isValidPort' in settings and '端口需为 1-65535' in settings)
    require('http proxy construction', 'connection.HttpProxy' in settings and 'username' in settings and 'exclusionList' in settings)
    require('socks5 url construction', "`socks5://${normalized.host}:${normalized.port}`" in settings)
    require('http url construction', "`http://${normalized.host}:${normalized.port}`" in settings)

    require('bootstrap restore', 'restoreNetworkProxy' in bootstrap and 'NetworkProxySettings.load' in bootstrap)
    require('networkkit options helper', 'networkKitProxyOption' in adapter and 'usingProxy = proxy' in adapter)
    require('networkkit off/system/http semantics', 'return false' in adapter and 'return true' in adapter and 'buildHttpProxy' in adapter)
    require('rcp socks5 selected', "settings.mode === 'socks5'" in adapter and 'requestViaRcp' in adapter)
    require('rcp web proxy tunnel always', 'createTunnel: \'always\'' in adapter and 'buildSocks5Url' in adapter)
    require('socks5 auth rejected', 'SOCKS5 代理暂不支持用户名/密码认证' in adapter or 'SOCKS5 暂不支持用户名/密码认证' in proxy_page)
    require('test connection endpoint', 'testConnection' in adapter and 'api/v2/site/info' in adapter)

    require('settings main entry', "title: '网络代理'" in settings_page and "pushPathByName('NetworkProxySettings'" in settings_page)
    require('settings second page route', 'NetworkProxySettingsPage' in routes and 'networkProxySettings' in routes)
    require('settings second page modes', 'SOCKS5 代理' in proxy_page and 'HTTP 代理' in proxy_page and '系统代理' in proxy_page)
    require('built-in system proxy selectable option exists', "title: '系统代理'" in proxy_page and 'selectProfile(NetworkProxySettings.SYSTEM_PROFILE_ID)' in proxy_page)
    require(
        'proxy selection uses radio controls',
        'ProxySelectionRadio' in proxy_page
        and "Radio({ value: profileId, group: 'networkProxyProfile' })" in proxy_page
        and '.checked(this.proxyEnabled && this.activeProfileId === profileId)' in proxy_page
        and 'this.selectProfile(profileId)' in proxy_page,
    )
    require(
        'proxy row radios are consistently prefix aligned',
        re.search(
            r"title: '系统代理'.*?prefixBuilderParam: \(\): void => this\.ProxySelectionRadio\(NetworkProxySettings\.SYSTEM_PROFILE_ID\).*?ManualProfileRow",
            proxy_page,
            re.S,
        ) is not None
        and re.search(
            r"title: '系统代理'.*?suffixBuilderParam: \(\): void => this\.ProxySelectionRadio\(NetworkProxySettings\.SYSTEM_PROFILE_ID\).*?ManualProfileRow",
            proxy_page,
            re.S,
        ) is None
        and 'prefixBuilderParam: (): void => this.ProxySelectionRadio(profile.id)' in proxy_page
        and 'suffixBuilderParam: (): void => this.EditProfileButton(profile.id)' in proxy_page,
    )
    require('add proxy row', "title: '添加代理'" in proxy_page and "openEditor('')" in proxy_page)
    require(
        'proxy editor uses bindContentCover',
        '.bindContentCover(this.editorOpen, this.EditorContent' in proxy_page
        and 'AppModalScaffold' in proxy_page
        and "title: '代理信息'" in proxy_page
        and 'saveEditor()' in proxy_page
        and 'closeEditor()' in proxy_page,
    )
    require(
        'proxy editor is not fake route branch',
        'if (this.editorOpen)' not in proxy_page
        and 'EditorPage' not in proxy_page
        and 'EditorTopBar' not in proxy_page,
    )
    require(
        'proxy editor has no string modal chrome glyphs',
        "Button('‹')" not in proxy_page
        and "Button('✓')" not in proxy_page
        and "Button('←')" not in proxy_page,
    )
    require('no duplicate local network proxy title section', "SettingsSectionHeader({ title: '网络代理' })" not in proxy_page)
    require('editor protocol choices only', 'HTTP 代理' in proxy_page and 'SOCKS5 代理' in proxy_page and 'MTProto' not in proxy_page)
    require(
        'editor protocol selection uses radio controls',
        'ProtocolRadio' in proxy_page
        and "Radio({ value: protocol, group: 'networkProxyProtocol' })" in proxy_page
        and '.checked(this.editorType === protocol)' in proxy_page
        and 'this.editorType = protocol' in proxy_page,
    )
    require('settings has no selected text markers', '已选择' not in proxy_page)
    forbidden_proxy_explainers = [
        '不是系统全局', '本地 DNS', 'VPN', 'WebView', '图片直显',
        '实验性', '不保证', '代理仅用于应用内网络请求'
    ]
    require('settings has no scope/explainer copy', not any(copy in proxy_page for copy in forbidden_proxy_explainers))
    require('settings test action', "'测试连接'" in proxy_page and 'NetworkProxyRequest.testConnection' in proxy_page)
    require(
        'settings off hides test action',
        'if (this.proxyEnabled && this.activeProfileId' in proxy_page and 'this.ActionSection()' in proxy_page,
    )
    require(
        'settings bypass keyboard collapses top chrome',
        'shouldCollapseTopForKeyboard' in proxy_page and 'bypassEditorFocused' in proxy_page and 'StorageKeys.KEYBOARD_HEIGHT' in proxy_page,
    )

    create_http = []
    for path in ROOT.rglob('*.ets'):
        text = path.read_text(encoding='utf-8')
        if 'http.createHttp()' in text:
            create_http.append(str(path.relative_to(ROOT)))
    require('single createHttp in adapter', create_http == ['shared/src/main/ets/network/NetworkProxyRequest.ets'], ', '.join(create_http))

    required_proxy_call_sites = {
        'shared/src/main/ets/network/HttpClient.ets': 3,
        'shared/src/main/ets/network/ApiV2Service.ets': 1,
        'shared/src/main/ets/network/ApiService.ets': 2,
        'shared/src/main/ets/network/V2exNativeAuthService.ets': 2,
        'shared/src/main/ets/network/Sov2exService.ets': 1,
        'entry/src/main/ets/pages/ImagePreviewPage.ets': 1,
    }
    for rel, minimum in required_proxy_call_sites.items():
        count = read(rel).count('NetworkProxyRequest.request(')
        require(f'proxy call-site {rel}', count >= minimum, f'found {count}, expected >= {minimum}')

    require('no httpclient package', '@ohos/httpclient' not in ''.join(p.read_text(encoding='utf-8', errors='ignore') for p in ROOT.rglob('*.ets')))
    print('All network proxy static contracts passed')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f'FAIL {exc}', file=sys.stderr)
        raise SystemExit(1)
