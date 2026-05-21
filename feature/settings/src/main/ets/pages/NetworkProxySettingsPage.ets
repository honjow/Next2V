import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AppModalScaffold,
  AppTextField,
  ConciseListRow,
  GroupedListSection,
  NetworkProxyRequest,
  NetworkProxySettings,
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants,
  type NetworkProxyProfile,
  type NetworkProxyProfilesSnapshot,
  type NetworkProxySettingsSnapshot,
  type NetworkProxyValidationResult,
} from 'shared'
import { SettingsSectionHeader } from '../components/SettingsPageComponents'

@Component
export struct NetworkProxySettingsPage {
  @StorageLink(StorageKeys.NETWORK_PROXY_ENABLED) proxyEnabled: boolean = false
  @StorageLink(StorageKeys.NETWORK_PROXY_ACTIVE_PROFILE_ID) activeProfileId: string = NetworkProxySettings.SYSTEM_PROFILE_ID
  @StorageLink(StorageKeys.NETWORK_PROXY_PROFILES) profilesJson: string = '[]'
  @StorageProp(StorageKeys.KEYBOARD_HEIGHT) keyboardH: number = 0
  @State private testStatus: string = ''
  @State private testing: boolean = false
  @State private editorOpen: boolean = false
  @State private editingProfileId: string = ''
  @State private editorType: string = NetworkProxySettings.MODE_HTTP
  @State private editorName: string = ''
  @State private editorHost: string = ''
  @State private editorPortText: string = ''
  @State private editorUsername: string = ''
  @State private editorPassword: string = ''
  @State private editorExclusionListText: string = ''
  @State private bypassEditorFocused: boolean = false

  build() {
    Column() {
      this.LandingPage()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .bindContentCover(this.editorOpen, this.EditorContent, { modalTransition: ModalTransition.DEFAULT })
  }

  @Builder
  LandingPage() {
    SecondaryListScaffold({ includeKeyboardPadding: false }) {
      ListItem() {
        this.SwitchSection()
      }
      ListItem() {
        SettingsSectionHeader({ title: '代理连接' })
      }
      ListItem() {
        this.ProxyConnectionSection()
      }
      if (this.proxyEnabled && this.activeProfileId !== '') {
        ListItem() {
          this.ActionSection()
        }
      }
    }
  }

  @Builder
  SwitchSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '使用代理',
        subtitle: this.proxyEnabled ? this.activeSummary() : '关闭',
        hasSwitch: true,
        checked: this.proxyEnabled,
        showChevron: false,
        switchAction: (value: boolean) => { this.setEnabled(value) },
      })
    }
  }

  @Builder
  ProxyConnectionSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '系统代理',
        subtitle: this.systemSubtitle(),
        showChevron: false,
        prefixBuilderParam: (): void => this.ProxySelectionRadio(NetworkProxySettings.SYSTEM_PROFILE_ID),
        action: () => { this.selectProfile(NetworkProxySettings.SYSTEM_PROFILE_ID) },
      })
      ForEach(this.profileList(), (profile: NetworkProxyProfile) => {
        this.ManualProfileRow(profile)
      }, (profile: NetworkProxyProfile) => profile.id)
      ConciseListRow({
        title: '添加代理',
        showChevron: true,
        action: () => { this.openEditor('') },
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
  ManualProfileRow(profile: NetworkProxyProfile) {
    ConciseListRow({
      title: NetworkProxySettings.profileTitle(profile),
      subtitle: this.profileSubtitle(profile),
      showChevron: false,
      prefixBuilderParam: (): void => this.ProxySelectionRadio(profile.id),
      suffixBuilderParam: (): void => this.EditProfileButton(profile.id),
      action: () => { this.selectProfile(profile.id) },
    })
  }

  @Builder
  EditProfileButton(profileId: string) {
    Button() {
      SymbolGlyph($r('sys.symbol.gearshape'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([$r('sys.color.font_secondary')])
    }
    .width(40)
    .height(40)
    .borderRadius(ThemeConstants.RADIUS_ROUND)
    .backgroundColor(Color.Transparent)
    .onClick(() => { this.openEditor(profileId) })
  }

  @Builder
  EditorContent() {
    AppModalScaffold({
      title: '代理信息',
      includeKeyboardPadding: true,
      closeAction: () => { this.closeEditor() },
      saveAction: () => { this.saveEditor() },
    }) {
      if (!this.shouldCollapseTopForKeyboard()) {
        ListItem() {
          this.ProtocolSection()
        }
      }
      ListItem() {
        this.EditorFieldsSection()
      }
    }
  }

  @Builder
  ProtocolSection() {
    GroupedListSection() {
      ConciseListRow({
        title: 'HTTP 代理',
        showChevron: false,
        suffixBuilderParam: (): void => this.ProtocolRadio(NetworkProxySettings.MODE_HTTP),
        action: () => { this.editorType = NetworkProxySettings.MODE_HTTP },
      })
      ConciseListRow({
        title: 'SOCKS5 代理',
        subtitle: this.editorType === NetworkProxySettings.MODE_SOCKS5 ? '不支持认证' : '',
        showChevron: false,
        suffixBuilderParam: (): void => this.ProtocolRadio(NetworkProxySettings.MODE_SOCKS5),
        action: () => { this.editorType = NetworkProxySettings.MODE_SOCKS5 },
      })
    }
  }

  @Builder
  ProxySelectionRadio(profileId: string) {
    Radio({ value: profileId, group: 'networkProxyProfile' })
      .checked(this.proxyEnabled && this.activeProfileId === profileId)
      .onChange((isChecked: boolean) => {
        if (isChecked) {
          this.selectProfile(profileId)
        }
      })
  }

  @Builder
  ProtocolRadio(protocol: string) {
    Radio({ value: protocol, group: 'networkProxyProtocol' })
      .checked(this.editorType === protocol)
      .onChange((isChecked: boolean) => {
        if (isChecked) {
          this.editorType = protocol
        }
      })
  }

  @Builder
  EditorFieldsSection() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      this.NameFieldRow()
      this.HostFieldRow()
      this.PortFieldRow()
      if (this.editorType === NetworkProxySettings.MODE_HTTP) {
        this.UsernameFieldRow()
        this.PasswordFieldRow()
      } else {
        this.StaticFieldRow('认证', '不支持认证')
      }
      this.BypassListRow()
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder
  FieldLabel(label: string) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
  }

  @Builder
  NameFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('名称（可选）')
      AppTextField({ text: $editorName, placeholder: '' })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  HostFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('服务器')
      AppTextField({ text: $editorHost, placeholder: '127.0.0.1' })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  PortFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('端口')
      AppTextField({ text: $editorPortText, placeholder: '7890' })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  UsernameFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('用户名（可选）')
      AppTextField({ text: $editorUsername, placeholder: '' })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  PasswordFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('密码（可选）')
      AppTextField({
        text: $editorPassword,
        placeholder: '',
        inputType: InputType.Password,
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
      this.FieldLabel('绕过列表（可选）')
      TextArea({ placeholder: '每行一个域名或 IP', text: this.editorExclusionListText })
        .height(80)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_primary'))
        .placeholderColor($r('sys.color.font_secondary'))
        .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
        .borderRadius(ThemeConstants.RADIUS_MD)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .onFocus(() => { this.bypassEditorFocused = true })
        .onBlur(() => { this.bypassEditorFocused = false })
        .onChange((value: string) => { this.editorExclusionListText = value })
    }
    .width('100%')
  }

  private profileList(): NetworkProxyProfile[] {
    return NetworkProxySettings.parseProfilesJson(this.profilesJson)
  }

  private currentProfilesSnapshot(): NetworkProxyProfilesSnapshot {
    return NetworkProxySettings.normalizeProfiles({
      enabled: this.proxyEnabled,
      activeProfileId: this.activeProfileId,
      profiles: this.profileList(),
    })
  }

  private currentEffectiveSnapshot(): NetworkProxySettingsSnapshot {
    return NetworkProxySettings.effectiveSnapshot(this.currentProfilesSnapshot())
  }

  private activeSummary(): string {
    return NetworkProxySettings.summary(this.currentEffectiveSnapshot())
  }

  private systemSubtitle(): string {
    if (!this.proxyEnabled || this.activeProfileId !== NetworkProxySettings.SYSTEM_PROFILE_ID) {
      return '内置选项'
    }
    return '当前连接'
  }

  private profileSubtitle(profile: NetworkProxyProfile): string {
    const subtitle = NetworkProxySettings.profileSubtitle(profile)
    if (this.proxyEnabled && this.activeProfileId === profile.id) {
      return `${subtitle} · 当前连接`
    }
    return subtitle
  }

  private setEnabled(value: boolean): void {
    this.saveProfiles({
      enabled: value,
      activeProfileId: this.activeProfileId || NetworkProxySettings.SYSTEM_PROFILE_ID,
      profiles: this.profileList(),
    }, true)
  }

  private selectProfile(profileId: string): void {
    this.saveProfiles({
      enabled: true,
      activeProfileId: profileId,
      profiles: this.profileList(),
    }, true)
  }

  private openEditor(profileId: string): void {
    const profile = NetworkProxySettings.findProfile(this.profileList(), profileId)
    this.editingProfileId = profile ? profile.id : ''
    this.editorType = profile ? profile.type : NetworkProxySettings.MODE_HTTP
    this.editorName = profile && profile.name ? profile.name : ''
    this.editorHost = profile ? profile.host : ''
    this.editorPortText = profile && profile.port > 0 ? `${profile.port}` : ''
    this.editorUsername = profile && profile.username ? profile.username : ''
    this.editorPassword = profile && profile.password ? profile.password : ''
    this.editorExclusionListText = profile && profile.exclusionList ? profile.exclusionList.join('\n') : ''
    this.bypassEditorFocused = false
    this.editorOpen = true
  }

  private closeEditor(): void {
    this.editorOpen = false
    this.bypassEditorFocused = false
  }

  private saveEditor(): void {
    const port = this.parsePort(this.editorPortText)
    const profile: NetworkProxyProfile = {
      id: this.editingProfileId || NetworkProxySettings.newProfileId(),
      type: this.editorType === NetworkProxySettings.MODE_SOCKS5 ? 'socks5' : 'http',
      host: this.editorHost,
      port,
      exclusionList: NetworkProxySettings.parseExclusionList(this.editorExclusionListText),
    }
    const name = this.editorName.trim()
    if (name) {
      profile.name = name
    }
    if (profile.type === NetworkProxySettings.MODE_HTTP) {
      const username = this.editorUsername.trim()
      if (username) {
        profile.username = username
        profile.password = this.editorPassword
      }
    }
    const normalizedProfile = NetworkProxySettings.normalizeProfile(profile)
    if (!normalizedProfile) {
      this.showToast('请输入有效代理主机')
      return
    }
    const validation = NetworkProxySettings.validate(NetworkProxySettings.snapshotFromProfile(normalizedProfile))
    if (!validation.ok) {
      this.showToast(validation.message)
      return
    }
    const profiles = this.upsertProfile(normalizedProfile)
    this.saveProfiles({
      enabled: true,
      activeProfileId: normalizedProfile.id,
      profiles,
    }, true)
    this.editorOpen = false
  }

  private upsertProfile(profile: NetworkProxyProfile): NetworkProxyProfile[] {
    const profiles = this.profileList()
    let replaced = false
    const result: NetworkProxyProfile[] = []
    for (const item of profiles) {
      if (item.id === profile.id) {
        result.push(profile)
        replaced = true
      } else {
        result.push(item)
      }
    }
    if (!replaced) {
      result.push(profile)
    }
    return result
  }

  private saveProfiles(snapshot: NetworkProxyProfilesSnapshot, showError: boolean): void {
    const normalized = NetworkProxySettings.normalizeProfiles(snapshot)
    const validation = NetworkProxySettings.validateProfiles(normalized)
    if (!validation.ok) {
      if (showError) {
        this.showToast(validation.message)
      }
      NetworkProxySettings.applyProfiles(normalized)
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxySettings.saveProfiles(context, normalized).catch((error: Error) => {
      if (showError) {
        this.showToast(error.message || '保存失败')
      }
      console.error('save network proxy settings failed: ' + (error.message || 'unknown'))
    })
  }

  private testConnection(): void {
    if (this.testing || !this.proxyEnabled) {
      return
    }
    const snapshot = this.currentEffectiveSnapshot()
    const validation: NetworkProxyValidationResult = NetworkProxySettings.validate(snapshot)
    if (!validation.ok) {
      this.testStatus = validation.message
      this.showToast(validation.message)
      return
    }
    this.testing = true
    this.testStatus = '测试中…'
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxySettings.saveProfiles(context, this.currentProfilesSnapshot())
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

  private shouldCollapseTopForKeyboard(): boolean {
    return this.bypassEditorFocused && this.keyboardH > 0
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
