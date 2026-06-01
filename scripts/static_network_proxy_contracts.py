#!/usr/bin/env python3
"""Static contract checks for V2Next network proxy lane."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
WRONG_TEST_ENDPOINT = 'api/v2/site' + '/info'
FORBIDDEN_BLOCKED_ENDPOINT = '/' + 'blocked'
FORBIDDEN_IGNORED_ENDPOINT = '/' + 'ignored'
FORBIDDEN_REMOTE_VALIDATION_SKIP = "remoteValidation: " + "'skip'"


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
    api_constants = read('shared/src/main/ets/constants/ApiConstants.ets')
    storage = read('shared/src/main/ets/constants/StorageKeys.ets')
    bootstrap = read('shared/src/main/ets/settings/SettingsBootstrap.ets')
    settings_page = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
    proxy_page = read('feature/settings/src/main/ets/pages/NetworkProxySettingsPage.ets')
    routes = read('entry/src/main/ets/model/IndexRouteCoordinator.ets') + read('entry/src/main/ets/pages/Index.ets')

    for mode in ["'off'", "'system'", "'http'", "'socks5'"]:
        require(f'mode {mode}', mode in settings)

    for key in [
        'NETWORK_PROXY_MODE', 'NETWORK_PROXY_HOST', 'NETWORK_PROXY_PORT',
        'NETWORK_PROXY_USERNAME', 'NETWORK_PROXY_PASSWORD', 'NETWORK_PROXY_EXCLUSION_LIST',
        'NETWORK_PROXY_SCHEME'
    ]:
        require(f'storage key {key}', key in storage and key in settings)

    require('settings persist json', 'writeJsonValue<NetworkProxySettingsSnapshot>' in settings and 'readJsonObject<NetworkProxySettingsSnapshot>' in settings)
    require('profile storage keys', 'networkProxyProfiles' in settings and 'networkProxyActiveProfileId' in settings)
    require('profile api exists', 'NetworkProxyProfileSettings' in settings and 'setActiveProfile' in settings and 'upsertProfile' in settings and 'deleteProfile' in settings)
    require('profile switching preserves runtime snapshot', 'NetworkProxySettings.save(context, profile.snapshot)' in settings and 'NetworkProxySettings.current()' in adapter)
    require('host validation', 'isValidHost' in settings and 'R_INVALID_PROXY_HOST' in settings)
    require('port validation', 'isValidPort' in settings and 'R_INVALID_PROXY_PORT' in settings)
    require('http proxy construction', 'connection.HttpProxy' in settings and 'username' in settings and 'exclusionList' in settings)
    require('proxy scheme model', 'NetworkProxyScheme' in settings and 'proxyScheme' in settings and "'https'" in settings)
    require('socks5 url construction', "socks5://${userinfo}${normalized.host}:${normalized.port}" in settings)
    require('proxy credentials retained', "mode === 'http' || mode === 'socks5'" in settings and "buildProxyUserInfo" in settings and "normalized.username ? `${NetworkProxySettings.encodeUserInfo(normalized.username)}:${NetworkProxySettings.encodeUserInfo(normalized.password)}@` : ''" in settings)
    require('url userinfo encoding', 'encodeURIComponent(value)' in settings and 'encodeUserInfo' in settings)
    require('http url construction with optional userinfo', "`${normalized.proxyScheme}://${userinfo}${normalized.host}:${normalized.port}`" in settings)
    require('https userinfo redaction contract', 'https?|socks5' in read('shared/src/main/ets/diagnostics/DiagnosticsRedactor.ets') and 'https?|socks5' in read('shared/src/main/ets/diagnostics/DiagnosticsLogFileSink.ets'))
    require('https proxy scheme supported', "MODE_HTTPS_PROXY" in settings and "NetworkProxySettings.MODE_HTTPS_PROXY" in proxy_page)

    require('bootstrap restore', 'restoreNetworkProxy' in bootstrap and 'NetworkProxySettings.load' in bootstrap)
    require('networkkit options helper', 'networkKitProxyOption' in adapter and 'usingProxy = proxy' in adapter)
    require('networkkit off/system/http semantics', 'return false' in adapter and 'return true' in adapter and 'buildHttpProxy' in adapter)
    require(
        'socks5 via dedicated socket, https proxy via rcp',
        "settings.mode === 'socks5'" in adapter
        and 'requestViaSocks5Socket' in adapter
        and 'Socks5HttpClient.request(' in adapter
        and "settings.proxyScheme === 'https'" in adapter
        and 'requestViaRcp' in adapter
        # The device SDK's SOCKS5 user/pass auth is broken, so SOCKS5 must use the
        # hand-rolled socket client (Socks5HttpClient), not the combined RCP path
        # that earlier migrations routed it through. Guard against that regression.
        and "settings.mode === 'socks5' || settings.proxyScheme === 'https'" not in adapter,
    )
    require('rcp web proxy tunnel always', 'createTunnel: \'always\'' in adapter and 'buildSocks5Url' in adapter and 'buildHttpUrl' in adapter)
    require('socks5 auth not rejected', 'SOCKS5 代理暂不支持用户名/密码认证' not in adapter and 'SOCKS5 暂不支持用户名/密码认证' not in proxy_page and 'R_SOCKS5_AUTH_UNSUPPORTED' not in proxy_page and 'R_AUTH_NOT_SUPPORTED' not in proxy_page)
    require('no remoteValidation skip in product path', FORBIDDEN_REMOTE_VALIDATION_SKIP not in adapter and FORBIDDEN_REMOTE_VALIDATION_SKIP not in settings and FORBIDDEN_REMOTE_VALIDATION_SKIP not in proxy_page)
    require(
        'test connection endpoint',
        'testConnection(baseUrl: string)' in adapter
        and 'ApiConstants.BASE_URL_COM' not in adapter
        and 'ApiConstants.API_SITE_INFO' in adapter
        and 'NetworkProxyRequest.testConnection(HttpClient.getInstance().getBaseUrl())' in proxy_page
        and "'/api/site/info.json'" in api_constants
        and WRONG_TEST_ENDPOINT not in adapter
        and WRONG_TEST_ENDPOINT not in api_constants,
    )

    require('settings main entry', ("title: '网络代理'" in settings_page or 'R_NAV_NETWORK_PROXY' in settings_page) and "pushPathByName('NetworkProxySettings'" in settings_page)
    require('settings second page route', 'NetworkProxySettingsPage' in routes and 'networkProxySettings' in routes)
    require('settings second page modes', 'R_SOCKS5_PROXY' in proxy_page and 'R_HTTP_PROXY' in proxy_page and 'R_HTTPS_PROXY_ENTRY' in proxy_page and 'R_SYSTEM_PROXY' in proxy_page)
    forbidden_proxy_explainers = [
        '不是系统全局', '本地 DNS', 'VPN', 'WebView', '图片直显',
        '实验性', '不保证', '代理仅用于应用内网络请求'
    ]
    require('settings has no scope/explainer copy', not any(copy in proxy_page for copy in forbidden_proxy_explainers))
    forbidden_fake_modal_ui = [
        "Button('‹')", "Button('" + chr(0x2713) + "')", 'EditorTopBar', 'fake route branch',
    ]
    require('settings has no fake modal chrome', not any(copy in proxy_page for copy in forbidden_fake_modal_ui))
    require('profile editor uses native tall sheet scaffold', 'bindSheet($$this.profileEditorVisible' in proxy_page and 'defaultSheetOptions(SheetSize.LARGE' in proxy_page and '[SheetSize.LARGE]' in proxy_page and 'AppModalScaffold({' in proxy_page)
    require('profile list uses hds rows with real active control', 'ProxyConnectionSection' in proxy_page and 'ConciseListRow({' in proxy_page and "Radio({ value: this.row.id, group: 'networkProxyProfiles' })" in proxy_page)
    require('profile editor avoids fake route branch', 'if (this.editorOpen)' not in proxy_page and 'fake full-page route' not in proxy_page)
    require('profile editor protocol uses semantic radio rows', "Radio({ value: protocol, group: 'networkProxyEditorProtocol' })" in proxy_page and 'suffixBuilderParam: (): void => this.ProtocolRadio' in proxy_page and 'ProtocolChoice' not in proxy_page)
    forbidden_protocol_buttons = ["Button('HTTP 代理')", "Button('HTTPS 代理入口')", "Button('SOCKS5 代理')", 'this.ProtocolChoice(']
    require('profile editor has no button-as-protocol-selector', not any(copy in proxy_page for copy in forbidden_protocol_buttons))
    save_section_match = re.search(r'EditorActionSection\(\) \{(?P<body>.*?)\n  \}\n\n  @Builder\n  EditorSectionLabel', proxy_page, re.S)
    save_section = save_section_match.group('body') if save_section_match else ''
    require(
        'profile editor save action is normal arkui button',
        ("Button('保存')" in save_section or 'Button(AppStrings.R_COMMON_SAVE' in save_section) and '.type(ButtonType.Normal)' in save_section and "title: '保存'" not in save_section,
    )
    require('shared component guard names', 'AppModalScaffold.ets' not in ''.join(sys.argv[1:]))
    require('settings test action', ('R_TEST_CONNECTION' in proxy_page or "'测试连接'" in proxy_page) and 'NetworkProxyRequest.testConnection' in proxy_page)
    require(
        'settings off hides test action',
        'currentMode() !== NetworkProxySettings.MODE_OFF' in proxy_page and 'this.ActionSection()' in proxy_page,
    )
    require(
        'settings bypass editor does not collapse sheet content on focus',
        # The editor inputs live in the AppModalScaffold tall sheet, which handles
        # keyboard avoidance natively via includeKeyboardPadding: true. The outer
        # list opts out (includeKeyboardPadding: false). No manual collapse-on-focus
        # hack and no live StorageKeys.KEYBOARD_HEIGHT reads (retired by the layout lane).
        'shouldCollapseTopForKeyboard' not in proxy_page
        and 'bypassEditorFocused' not in proxy_page
        and 'includeKeyboardPadding: true' in proxy_page
        and 'includeKeyboardPadding: false' in proxy_page
        and 'StorageKeys.KEYBOARD_HEIGHT' not in proxy_page,
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

    all_ets = ''.join(p.read_text(encoding='utf-8', errors='ignore') for p in ROOT.rglob('*.ets'))
    require('no httpclient package', '@ohos/httpclient' not in all_ets)
    require('no phantom blocklist endpoints', FORBIDDEN_BLOCKED_ENDPOINT not in all_ets and FORBIDDEN_IGNORED_ENDPOINT not in all_ets)
    print('All network proxy static contracts passed')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f'FAIL {exc}', file=sys.stderr)
        raise SystemExit(1)
