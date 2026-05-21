import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AppTextField,
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
  @StorageProp(StorageKeys.KEYBOARD_HEIGHT) keyboardH: number = 0
  @State private portText: string = ''
  @State private modeMenuShown: boolean = false
  @State private testStatus: string = ''
  @State private testing: boolean = false
  @State private bypassEditorFocused: boolean = false

  aboutToAppear(): void {
    this.portText = this.port > 0 ? `${this.port}` : ''
  }

  build() {
    Column() {
      SecondaryListScaffold({ includeKeyboardPadding: true }) {
        if (!this.shouldCollapseTopForKeyboard()) {
          ListItem() {
            SettingsSectionHeader({ title: '网络代理' })
          }
          ListItem() {
            this.ModeSection()
          }
        }
        if (this.needsManualProxy()) {
          ListItem() {
            SettingsSectionHeader({ title: '手动代理' })
          }
          ListItem() {
            this.ManualSection()
          }
        }
        if (this.currentMode() !== NetworkProxySettings.MODE_OFF) {
          ListItem() {
            this.ActionSection()
          }
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
    Column({ space: ThemeConstants.SPACE_SM }) {
      this.HostFieldRow()
      this.PortFieldRow()
      if (this.currentMode() === NetworkProxySettings.MODE_HTTP) {
        this.UsernameFieldRow()
        this.PasswordFieldRow()
      } else {
        this.StaticFieldRow('认证', '不支持认证')
      }
      this.BypassListRow()
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
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
  FieldLabel(label: string) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
  }

  @Builder
  HostFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('主机')
      AppTextField({
        text: $host,
        placeholder: '127.0.0.1',
        onTextChange: (value: string) => {
          this.host = value
          this.saveCurrent(false)
        }
      })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  PortFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('端口')
      AppTextField({
        text: $portText,
        placeholder: '7890',
        onTextChange: (value: string) => {
          this.port = this.parsePort(value)
          this.saveCurrent(false)
        }
      })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  UsernameFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('用户名（可选）')
      AppTextField({
        text: $username,
        placeholder: '',
        onTextChange: (value: string) => {
          this.username = value
          this.saveCurrent(false)
        }
      })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  PasswordFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('密码（可选）')
      AppTextField({
        text: $password,
        placeholder: '',
        inputType: InputType.Password,
        onTextChange: (value: string) => {
          this.password = value
          this.saveCurrent(false)
        }
      })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  StaticFieldRow(label: string, value: string) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel(label)
      Text(value)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .height(44)
        .width('100%')
        .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
        .borderRadius(ThemeConstants.RADIUS_ROUND)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .textAlign(TextAlign.Start)
    }
    .width('100%')
  }

  @Builder
  BypassListRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('绕过列表')
      TextArea({ placeholder: '每行一个域名或 IP', text: this.exclusionListText })
        .height(96)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_primary'))
        .placeholderColor($r('sys.color.font_secondary'))
        .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
        .borderRadius(ThemeConstants.RADIUS_MD)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .onFocus(() => { this.bypassEditorFocused = true })
        .onBlur(() => { this.bypassEditorFocused = false })
        .onChange((value: string) => {
          this.exclusionListText = value
          this.saveCurrent(false)
        })
    }
    .width('100%')
  }

  private currentMode(): NetworkProxyMode {
    return NetworkProxySettings.normalizeMode(this.mode)
  }

  private needsManualProxy(): boolean {
    const current = this.currentMode()
    return current === NetworkProxySettings.MODE_HTTP || current === NetworkProxySettings.MODE_SOCKS5
  }

  private shouldCollapseTopForKeyboard(): boolean {
    return this.needsManualProxy() && this.bypassEditorFocused && this.keyboardH > 0
  }

  private modeOptions(): SettingsOption[] {
    return [
      { value: NetworkProxySettings.MODE_OFF, label: '关闭' },
      { value: NetworkProxySettings.MODE_SYSTEM, label: '系统代理' },
      { value: NetworkProxySettings.MODE_HTTP, label: 'HTTP 代理' },
      { value: NetworkProxySettings.MODE_SOCKS5, label: 'SOCKS5 代理' },
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
