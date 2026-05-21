import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ConciseListRow,
  GroupedListSection,
  NetworkProxyRequest,
  NetworkProxySettings,
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants,
  type NetworkProxyMode,
  type NetworkProxySettingsSnapshot,
  type NetworkProxyValidationResult,
} from 'shared'
import {
  SettingsCheckedMenuItem,
  SettingsDivider,
  SettingsDropdownRow,
  SettingsSectionHeader,
} from '../components/SettingsPageComponents'
import { SettingsPageCoordinator, type SettingsOption } from '../model/SettingsPageCoordinator'

@Component
export struct NetworkProxySettingsPage {
  @StorageLink(StorageKeys.NETWORK_PROXY_MODE) mode: string = NetworkProxySettings.MODE_OFF
  @StorageLink(StorageKeys.NETWORK_PROXY_HOST) host: string = ''
  @StorageLink(StorageKeys.NETWORK_PROXY_PORT) port: number = 0
  @StorageLink(StorageKeys.NETWORK_PROXY_USERNAME) username: string = ''
  @StorageLink(StorageKeys.NETWORK_PROXY_PASSWORD) password: string = ''
  @StorageLink(StorageKeys.NETWORK_PROXY_EXCLUSION_LIST) exclusionListText: string = ''
  @State private modeMenuShown: boolean = false
  @State private testStatus: string = ''
  @State private testing: boolean = false

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          SettingsSectionHeader({ title: '网络代理' })
        }
        ListItem() {
          this.ModeSection()
        }
        if (this.needsManualProxy()) {
          ListItem() {
            SettingsSectionHeader({ title: '手动代理' })
          }
          ListItem() {
            this.ManualSection()
          }
        }
        ListItem() {
          SettingsSectionHeader({ title: '说明' })
        }
        ListItem() {
          this.DescriptionSection()
        }
        ListItem() {
          this.ActionSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  ModeSection() {
    GroupedListSection() {
      SettingsDropdownRow({
        title: '模式',
        subtitle: '仅影响 V2Next 应用网络请求，不是系统全局 VPN',
        trailingText: NetworkProxySettings.label(this.currentMode()),
        openAction: () => { this.showModeMenu() },
      })
        .bindMenu(this.modeMenuShown, this.ModeMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => { this.modeMenuShown = false },
        })
    }
  }

  @Builder
  ManualSection() {
    GroupedListSection() {
      this.TextFieldRow('主机', '127.0.0.1', this.host, (value: string) => {
        this.host = value
        this.saveCurrent(false)
      })
      SettingsDivider()
      this.TextFieldRow('端口', '7890', this.port > 0 ? `${this.port}` : '', (value: string) => {
        this.port = this.parsePort(value)
        this.saveCurrent(false)
      })
      SettingsDivider()
      if (this.currentMode() === NetworkProxySettings.MODE_HTTP) {
        this.TextFieldRow('用户名（可选）', '', this.username, (value: string) => {
          this.username = value
          this.saveCurrent(false)
        })
        SettingsDivider()
        this.TextFieldRow('密码（可选）', '', this.password, (value: string) => {
          this.password = value
          this.saveCurrent(false)
        }, true)
        SettingsDivider()
      } else {
        ConciseListRow({
          title: '认证',
          subtitle: 'SOCKS5 本版基于 RCP，暂不支持用户名/密码认证',
          showChevron: false,
        })
        SettingsDivider()
      }
      this.TextAreaRow('绕过列表', '每行一个域名/IP；HTTP 与 RCP 支持时使用', this.exclusionListText, (value: string) => {
        this.exclusionListText = value
        this.saveCurrent(false)
      })
    }
  }

  @Builder
  DescriptionSection() {
    GroupedListSection() {
      ConciseListRow({
        title: this.descriptionTitle(),
        subtitle: this.descriptionText(),
        showChevron: false,
      })
    }
  }

  @Builder
  ActionSection() {
    GroupedListSection() {
      ConciseListRow({
        title: this.testing ? '正在测试连接…' : '测试连接',
        subtitle: this.testStatus,
        showChevron: false,
        action: () => { this.testConnection() },
      })
    }
  }

  @Builder
  ModeMenu() {
    Menu() {
      ForEach(this.modeOptions(), (option: SettingsOption) => {
        SettingsCheckedMenuItem({
          label: option.label,
          selected: this.mode === option.value,
          selectAction: () => { this.updateMode(option.value) }
        })
      }, (option: SettingsOption) => option.value)
    }
  }

  @Builder
  TextFieldRow(label: string, placeholderText: string, textValue: string, changeAction: (value: string) => void, isPassword: boolean = false) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      TextInput({ placeholder: placeholderText, text: textValue })
        .type(isPassword ? InputType.Password : InputType.Normal)
        .height(44)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => { changeAction(value) })
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
  }

  @Builder
  TextAreaRow(label: string, placeholderText: string, textValue: string, changeAction: (value: string) => void) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      TextArea({ placeholder: placeholderText, text: textValue })
        .height(96)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => { changeAction(value) })
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
  }

  private currentMode(): NetworkProxyMode {
    return NetworkProxySettings.normalizeMode(this.mode)
  }

  private needsManualProxy(): boolean {
    const current = this.currentMode()
    return current === NetworkProxySettings.MODE_HTTP || current === NetworkProxySettings.MODE_SOCKS5
  }

  private modeOptions(): SettingsOption[] {
    return [
      { value: NetworkProxySettings.MODE_OFF, label: '关闭' },
      { value: NetworkProxySettings.MODE_SYSTEM, label: '系统代理' },
      { value: NetworkProxySettings.MODE_HTTP, label: 'HTTP 代理' },
      { value: NetworkProxySettings.MODE_SOCKS5, label: 'SOCKS5 代理（实验性）' },
    ]
  }

  private snapshot(): NetworkProxySettingsSnapshot {
    return NetworkProxySettings.normalize({
      mode: this.currentMode(),
      host: this.host,
      port: this.port,
      username: this.currentMode() === NetworkProxySettings.MODE_HTTP ? this.username : '',
      password: this.currentMode() === NetworkProxySettings.MODE_HTTP ? this.password : '',
      exclusionList: NetworkProxySettings.parseExclusionList(this.exclusionListText),
    })
  }

  private updateMode(value: string): void {
    this.modeMenuShown = false
    this.mode = NetworkProxySettings.normalizeMode(value)
    if (this.mode === NetworkProxySettings.MODE_SOCKS5) {
      this.username = ''
      this.password = ''
    }
    this.saveCurrent(true)
  }

  private saveCurrent(showError: boolean): void {
    const snapshot = this.snapshot()
    const validation = NetworkProxySettings.validate(snapshot)
    if (!validation.ok && !showError) {
      NetworkProxySettings.apply(snapshot)
      return
    }
    if (!validation.ok) {
      this.showToast(validation.message)
      NetworkProxySettings.apply(snapshot)
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxySettings.save(context, snapshot).catch((error: Error) => {
      if (showError) {
        this.showToast(error.message || '保存失败')
      }
      console.error('save network proxy settings failed: ' + (error.message || 'unknown'))
    })
  }

  private testConnection(): void {
    if (this.testing) {
      return
    }
    const snapshot = this.snapshot()
    const validation: NetworkProxyValidationResult = NetworkProxySettings.validate(snapshot)
    if (!validation.ok) {
      this.testStatus = validation.message
      this.showToast(validation.message)
      return
    }
    if (snapshot.mode === NetworkProxySettings.MODE_SOCKS5 && (snapshot.username || snapshot.password)) {
      this.testStatus = 'SOCKS5 暂不支持用户名/密码认证'
      this.showToast(this.testStatus)
      return
    }
    this.testing = true
    this.testStatus = '测试中…'
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxySettings.save(context, snapshot)
      .then(() => NetworkProxyRequest.testConnection())
      .then((response) => {
        this.testing = false
        if (response.responseCode >= 200 && response.responseCode < 300) {
          this.testStatus = `连接成功（HTTP ${response.responseCode}）`
        } else {
          this.testStatus = `连接失败：HTTP ${response.responseCode}`
        }
        this.showToast(this.testStatus)
      })
      .catch((error: Error) => {
        this.testing = false
        this.testStatus = this.errorSummary(error)
        this.showToast(this.testStatus)
      })
  }

  private showModeMenu(): void {
    this.modeMenuShown = false
    setTimeout(() => { this.modeMenuShown = true }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private parsePort(value: string): number {
    const parsed = Number.parseInt((value || '').trim(), 10)
    if (!Number.isFinite(parsed)) {
      return 0
    }
    if (parsed < 0 || parsed > 65535) {
      return 0
    }
    return parsed
  }

  private descriptionTitle(): string {
    if (this.currentMode() === NetworkProxySettings.MODE_SOCKS5) {
      return 'SOCKS5 兼容性提示'
    }
    return '作用范围'
  }

  private descriptionText(): string {
    if (this.currentMode() === NetworkProxySettings.MODE_SOCKS5) {
      return '本版通过 RCP 覆盖应用内主要网络请求；SOCKS5 可能先本地 DNS 解析再连接，不保证代理侧域名规则。图片直显/WebView 不保证覆盖。'
    }
    return '代理只作用于 V2Next 应用发起的网络请求，不会修改系统全局网络或提供 VPN。图片直显/WebView 后续单独覆盖。'
  }

  private errorSummary(error: Error): string {
    const message = (error.message || '测试失败').trim()
    if (message.length > 80) {
      return message.substring(0, 80)
    }
    return message
  }

  private showToast(message: string): void {
    promptAction.openToast({ message }).catch((_error: Error) => {})
  }
}
