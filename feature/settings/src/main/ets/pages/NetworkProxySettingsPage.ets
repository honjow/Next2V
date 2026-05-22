import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AppModalScaffold,
  AppTextField,
  ConciseListRow,
  defaultSheetOptions,
  GroupedListSection,
  HttpClient,
  NetworkProxyProfileSettings,
  NetworkProxyRequest,
  NetworkProxySettings,
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants,
  type NetworkProxyMode,
  type NetworkProxyProfile,
  type NetworkProxySettingsSnapshot,
  type NetworkProxyValidationResult,
} from 'shared'
import { SettingsSectionHeader } from '../components/SettingsPageComponents'

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
  @State private testStatus: string = ''
  @State private testing: boolean = false
  @State private profiles: NetworkProxyProfile[] = []
  @State private activeProfileId: string = ''
  @State private profileEditorVisible: boolean = false
  @State private editingProfileId: string = ''
  @State private editorName: string = ''
  @State private editorMode: string = NetworkProxySettings.MODE_HTTP
  @State private editorHost: string = ''
  @State private editorPort: number = 0
  @State private editorPortText: string = ''
  @State private editorUsername: string = ''
  @State private editorPassword: string = ''
  @State private editorExclusionListText: string = ''

  aboutToAppear(): void {
    this.portText = this.port > 0 ? `${this.port}` : ''
    this.loadProfiles()
  }

  build() {
    Column() {
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
    .bindSheet($$this.profileEditorVisible, this.ProfileEditorSheet(), defaultSheetOptions(SheetSize.LARGE, () => { this.profileEditorVisible = false }, [SheetSize.LARGE]))
  }

  @Builder
  SwitchSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '使用代理',
        subtitle: this.proxyEnabled() ? this.activeSummary() : '关闭',
        hasSwitch: true,
        checked: this.proxyEnabled(),
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
        prefixBuilderParam: (): void => this.ProxySelectionRadio(NetworkProxySettings.MODE_SYSTEM),
        action: () => { this.selectSystemProxy() },
      })
      ForEach(this.profiles, (profile: NetworkProxyProfile) => {
        this.ManualProfileRow(profile)
      }, (profile: NetworkProxyProfile) => profile.id)
      ConciseListRow({
        title: '添加代理',
        showChevron: true,
        action: () => { this.openNewProfileEditor() },
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
      title: this.profileTitle(profile),
      subtitle: this.profileSubtitle(profile),
      showChevron: false,
      prefixBuilderParam: (): void => this.ProxySelectionRadio(profile.id),
      suffixBuilderParam: (): void => this.EditProfileButton(profile.id),
      action: () => { this.applyProfile(profile) },
    })
  }

  @Builder
  ProxySelectionRadio(profileId: string) {
    Radio({ value: profileId, group: 'networkProxyProfiles' })
      .checked(this.proxyEnabled() && this.selectedProfileId() === profileId)
      .onChange((checked: boolean) => {
        if (!checked) {
          return
        }
        if (profileId === NetworkProxySettings.MODE_SYSTEM) {
          this.selectSystemProxy()
          return
        }
        const profile = this.findProfile(profileId)
        if (profile) {
          this.applyProfile(profile)
        }
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
    .onClick(() => {
      const profile = this.findProfile(profileId)
      if (profile) {
        this.openProfileEditor(profile)
      }
    })
  }

  @Builder
  ProfileEditorSheet() {
    AppModalScaffold({
      title: '代理信息',
      includeKeyboardPadding: true,
      contentBackgroundColor: $r('sys.color.ohos_id_color_sub_background'),
      closeAction: () => { this.closeEditor() },
    }) {
      ListItem() {
        this.ProtocolSection()
      }
      ListItem() {
        this.ProfileEditorFields()
      }
      ListItem() {
        this.EditorActionSection()
      }
    }
  }

  @Builder
  ProtocolSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.EditorSectionLabel('代理类型')
      GroupedListSection() {
        ConciseListRow({
          title: 'HTTP 代理',
          subtitle: '支持用户名和密码认证',
          showChevron: false,
          suffixBuilderParam: (): void => this.ProtocolRadio(NetworkProxySettings.MODE_HTTP),
          action: () => { this.updateEditorMode(NetworkProxySettings.MODE_HTTP) },
        })
        ConciseListRow({
          title: 'SOCKS5 代理',
          subtitle: '不支持认证',
          showChevron: false,
          suffixBuilderParam: (): void => this.ProtocolRadio(NetworkProxySettings.MODE_SOCKS5),
          action: () => { this.updateEditorMode(NetworkProxySettings.MODE_SOCKS5) },
        })
      }
    }
    .width('100%')
  }

  @Builder
  ProtocolRadio(protocol: string) {
    Radio({ value: protocol, group: 'networkProxyEditorProtocol' })
      .checked(this.editorCurrentMode() === protocol)
      .onChange((checked: boolean) => {
        if (checked) {
          this.updateEditorMode(protocol)
        }
      })
  }

  @Builder
  ProfileEditorFields() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.EditorSectionLabel('代理参数')
      GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
        Column({ space: ThemeConstants.SPACE_LG }) {
          this.EditorHostFieldRow()
          this.EditorPortFieldRow()
          if (this.editorCurrentMode() === NetworkProxySettings.MODE_HTTP) {
            this.EditorUsernameFieldRow()
            this.EditorPasswordFieldRow()
          } else {
            this.StaticFieldRow('认证', '不支持认证')
          }
          this.EditorNameFieldRow()
          this.EditorBypassListRow()
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  EditorActionSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.EditorSectionLabel('操作')
      GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Button('保存')
            .type(ButtonType.Normal)
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .width('100%')
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .onClick(() => { this.saveProfileEditor() })
          if (this.editingProfileId) {
            ConciseListRow({
              title: '删除代理',
              destructive: true,
              showChevron: false,
              action: () => { this.confirmDeleteProfile() },
            })
          }
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  EditorSectionLabel(label: string) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_SECTION_TITLE)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
  }


  @Builder
  ActionSymbol(icon: Resource) {
    SymbolGlyph(icon)
      .fontSize(ThemeConstants.FONT_SIZE_TITLE)
      .fontColor([ThemeConstants.BRAND_PRIMARY])
  }

  @Builder
  FieldLabel(label: string) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
  }

  @Builder
  EditorNameFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('名称（可选）')
      AppTextField({
        text: $editorName,
        placeholder: '默认使用服务器:端口',
        onTextChange: (value: string) => { this.editorName = value }
      })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  EditorHostFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('服务器')
      AppTextField({
        text: $editorHost,
        placeholder: '127.0.0.1',
        onTextChange: (value: string) => { this.editorHost = value }
      })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  EditorPortFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('端口')
      AppTextField({
        text: $editorPortText,
        placeholder: '7890',
        onTextChange: (value: string) => {
          this.editorPortText = value
          this.editorPort = this.parsePort(value)
        }
      })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  EditorUsernameFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('用户名（可选）')
      AppTextField({
        text: $editorUsername,
        placeholder: '',
        onTextChange: (value: string) => { this.editorUsername = value }
      })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  EditorPasswordFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel('密码（可选）')
      AppTextField({
        text: $editorPassword,
        placeholder: '',
        inputType: InputType.Password,
        onTextChange: (value: string) => { this.editorPassword = value }
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
  EditorBypassListRow() {
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
        .onChange((value: string) => { this.editorExclusionListText = value })
    }
    .width('100%')
  }

  private currentMode(): NetworkProxyMode {
    return NetworkProxySettings.normalizeMode(this.mode)
  }

  private proxyEnabled(): boolean {
    return this.currentMode() !== NetworkProxySettings.MODE_OFF
  }

  private selectedProfileId(): string {
    if (this.currentMode() === NetworkProxySettings.MODE_SYSTEM) {
      return NetworkProxySettings.MODE_SYSTEM
    }
    return this.activeProfileId
  }

  private activeSummary(): string {
    if (this.currentMode() === NetworkProxySettings.MODE_SYSTEM) {
      return '系统代理'
    }
    return NetworkProxySettings.summary(this.snapshot())
  }

  private systemSubtitle(): string {
    if (this.currentMode() === NetworkProxySettings.MODE_SYSTEM) {
      return '当前连接'
    }
    return '内置选项'
  }

  private profileTitle(profile: NetworkProxyProfile): string {
    const name = (profile.name || '').trim()
    if (name) {
      return name
    }
    const snapshot = NetworkProxySettings.normalize(profile.snapshot)
    if (snapshot.host && snapshot.port > 0) {
      return `${snapshot.host}:${snapshot.port}`
    }
    return '代理配置'
  }

  private profileSubtitle(profile: NetworkProxyProfile): string {
    const summary = NetworkProxySettings.summary(profile.snapshot)
    if (this.proxyEnabled() && this.activeProfileId === profile.id && this.currentMode() !== NetworkProxySettings.MODE_SYSTEM) {
      return `${summary} · 当前连接`
    }
    return summary
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

  private editorSnapshot(): NetworkProxySettingsSnapshot {
    return NetworkProxySettings.normalize({
      mode: this.editorCurrentMode(),
      host: this.editorHost,
      port: this.editorPort,
      username: this.editorCurrentMode() === NetworkProxySettings.MODE_HTTP ? this.editorUsername : '',
      password: this.editorCurrentMode() === NetworkProxySettings.MODE_HTTP ? this.editorPassword : '',
      exclusionList: NetworkProxySettings.parseExclusionList(this.editorExclusionListText),
    })
  }

  private editorCurrentMode(): NetworkProxyMode {
    const mode = NetworkProxySettings.normalizeMode(this.editorMode)
    if (mode === NetworkProxySettings.MODE_SOCKS5) {
      return NetworkProxySettings.MODE_SOCKS5
    }
    return NetworkProxySettings.MODE_HTTP
  }

  private setEnabled(value: boolean): void {
    if (!value) {
      this.mode = NetworkProxySettings.MODE_OFF
      this.saveCurrent(true)
      return
    }
    const active = this.findProfile(this.activeProfileId)
    if (active) {
      this.applyProfile(active)
      return
    }
    this.selectSystemProxy()
  }

  private selectSystemProxy(): void {
    this.mode = NetworkProxySettings.MODE_SYSTEM
    this.testStatus = ''
    this.saveCurrent(true)
  }

  private updateEditorMode(value: string): void {
    this.editorMode = NetworkProxySettings.normalizeMode(value) === NetworkProxySettings.MODE_SOCKS5 ? NetworkProxySettings.MODE_SOCKS5 : NetworkProxySettings.MODE_HTTP
    if (this.editorMode === NetworkProxySettings.MODE_SOCKS5) {
      this.editorUsername = ''
      this.editorPassword = ''
    }
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
    NetworkProxySettings.save(context, snapshot)
      .then(() => { this.persistActiveProfileSnapshot(context, snapshot) })
      .catch((error: Error) => {
        if (showError) {
          this.showToast(error.message || '保存失败')
        }
        console.error('save network proxy settings failed: ' + (error.message || 'unknown'))
      })
  }

  private persistActiveProfileSnapshot(context: common.UIAbilityContext, snapshot: NetworkProxySettingsSnapshot): void {
    if (!this.activeProfileId || snapshot.mode === NetworkProxySettings.MODE_OFF || snapshot.mode === NetworkProxySettings.MODE_SYSTEM) {
      return
    }
    const profile = this.findProfile(this.activeProfileId)
    if (!profile) {
      return
    }
    const updated = NetworkProxyProfileSettings.createProfile(this.profileTitle(profile), snapshot, profile.id)
    NetworkProxyProfileSettings.upsertProfile(context, updated)
      .then((state) => {
        this.profiles = state.profiles
        this.activeProfileId = state.activeProfileId
      })
      .catch((error: Error) => {
        console.error('save active network proxy profile failed: ' + (error.message || 'unknown'))
      })
  }

  private testConnection(): void {
    if (this.testing || this.currentMode() === NetworkProxySettings.MODE_OFF) {
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
      .then(() => NetworkProxyRequest.testConnection(HttpClient.getInstance().getBaseUrl()))
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

  private loadProfiles(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxyProfileSettings.load(context)
      .then((state) => {
        this.profiles = state.profiles
        this.activeProfileId = state.activeProfileId
      })
      .catch((error: Error) => {
        console.error('load network proxy profiles failed: ' + (error.message || 'unknown'))
      })
  }

  private applyProfile(profile: NetworkProxyProfile): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxyProfileSettings.setActiveProfile(context, profile.id)
      .then((state) => {
        this.profiles = state.profiles
        this.activeProfileId = state.activeProfileId
        this.applySnapshotToPage(profile.snapshot)
        this.testStatus = ''
        this.showToast('已切换配置')
      })
      .catch((error: Error) => { this.showToast(error.message || '切换失败') })
  }

  private openNewProfileEditor(): void {
    const current = this.snapshot()
    if (current.mode === NetworkProxySettings.MODE_HTTP || current.mode === NetworkProxySettings.MODE_SOCKS5) {
      this.openEditor('', '', current)
      return
    }
    this.openEditor('', '', NetworkProxySettings.normalize({
      mode: NetworkProxySettings.MODE_HTTP,
      host: '',
      port: 0,
      username: '',
      password: '',
      exclusionList: [],
    }))
  }

  private openProfileEditor(profile: NetworkProxyProfile): void {
    this.openEditor(profile.id, profile.name, profile.snapshot)
  }

  private openEditor(id: string, name: string, snapshot: NetworkProxySettingsSnapshot): void {
    const normalized = NetworkProxySettings.normalize(snapshot)
    this.editingProfileId = id
    this.editorName = name
    this.editorMode = normalized.mode === NetworkProxySettings.MODE_SOCKS5 ? NetworkProxySettings.MODE_SOCKS5 : NetworkProxySettings.MODE_HTTP
    this.editorHost = normalized.host
    this.editorPort = normalized.port
    this.editorPortText = normalized.port > 0 ? `${normalized.port}` : ''
    this.editorUsername = normalized.username
    this.editorPassword = normalized.password
    this.editorExclusionListText = NetworkProxySettings.exclusionListText(normalized)
    this.profileEditorVisible = true
  }

  private closeEditor(): void {
    this.profileEditorVisible = false
  }

  private saveProfileEditor(): void {
    const snapshot = this.editorSnapshot()
    const validation = NetworkProxySettings.validate(snapshot)
    if (!validation.ok) {
      this.showToast(validation.message)
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const profile = NetworkProxyProfileSettings.createProfile(this.editorProfileName(snapshot), snapshot, this.editingProfileId || undefined)
    NetworkProxyProfileSettings.upsertProfile(context, profile)
      .then((state) => {
        this.profiles = state.profiles
        this.activeProfileId = state.activeProfileId
        return NetworkProxyProfileSettings.setActiveProfile(context, profile.id)
      })
      .then((state) => {
        this.profiles = state.profiles
        this.activeProfileId = state.activeProfileId
        this.applySnapshotToPage(profile.snapshot)
        this.closeEditor()
        this.showToast('已保存')
      })
      .catch((error: Error) => { this.showToast(error.message || '保存失败') })
  }

  private confirmDeleteProfile(): void {
    const profile = this.findProfile(this.editingProfileId)
    if (!profile) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: '删除代理',
      message: `确定删除“${this.profileTitle(profile)}”？`,
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '删除',
        action: () => { this.deleteProfile(profile) }
      }
    })
  }

  private deleteProfile(profile: NetworkProxyProfile): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxyProfileSettings.deleteProfile(context, profile.id)
      .then((state) => {
        this.profiles = state.profiles
        this.activeProfileId = state.activeProfileId
        if (state.activeProfileId) {
          const active = this.findProfile(state.activeProfileId)
          if (active) {
            this.applySnapshotToPage(active.snapshot)
          }
        } else {
          this.mode = NetworkProxySettings.MODE_OFF
          this.saveCurrent(false)
        }
        this.closeEditor()
        this.showToast('已删除')
      })
      .catch((error: Error) => { this.showToast(error.message || '删除失败') })
  }

  private findProfile(id: string): NetworkProxyProfile | undefined {
    for (const profile of this.profiles) {
      if (profile.id === id) {
        return profile
      }
    }
    return undefined
  }

  private applySnapshotToPage(snapshot: NetworkProxySettingsSnapshot): void {
    const normalized = NetworkProxySettings.normalize(snapshot)
    this.mode = normalized.mode
    this.host = normalized.host
    this.port = normalized.port
    this.portText = normalized.port > 0 ? `${normalized.port}` : ''
    this.username = normalized.username
    this.password = normalized.password
    this.exclusionListText = NetworkProxySettings.exclusionListText(normalized)
  }

  private editorProfileName(snapshot: NetworkProxySettingsSnapshot): string {
    const name = this.editorName.trim()
    if (name) {
      return name
    }
    const normalized = NetworkProxySettings.normalize(snapshot)
    if (normalized.host && normalized.port > 0) {
      return `${normalized.host}:${normalized.port}`
    }
    return '代理配置'
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
