import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AppStrings,
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
  type NetworkProxyProfilesState,
  type NetworkProxySettingsSnapshot,
  type NetworkProxyValidationResult,
} from 'shared'
import { SettingsSectionHeader } from '../components/SettingsPageComponents'

@Component
export struct NetworkProxySettingsPage {
  @StorageLink(StorageKeys.NETWORK_PROXY_MODE) mode: string = NetworkProxySettings.MODE_OFF
  @StorageLink(StorageKeys.NETWORK_PROXY_HOST) host: string = ''
  @StorageLink(StorageKeys.NETWORK_PROXY_PORT) port: number = 0
  @StorageLink(StorageKeys.NETWORK_PROXY_SCHEME) proxyScheme: string = NetworkProxySettings.MODE_HTTP_PROXY
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
  @State private editorProxyScheme: string = NetworkProxySettings.MODE_HTTP_PROXY
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
          SettingsSectionHeader({ title: AppStrings.R_PROXY_CONNECTION })
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
        title: AppStrings.R_USE_PROXY,
        subtitle: this.proxyEnabled() ? this.activeSummary() : AppStrings.R_COMMON_CLOSED,
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
        title: AppStrings.R_SYSTEM_PROXY,
        showChevron: false,
        prefixBuilderParam: (): void => this.ProxySelectionRadio(NetworkProxySettings.MODE_SYSTEM),
        action: () => { this.selectSystemProxy() },
      })
      ForEach(this.profiles, (profile: NetworkProxyProfile) => {
        this.ManualProfileRow(profile)
      }, (profile: NetworkProxyProfile) => `${profile.id}-${profile.updatedAt}`)
      ConciseListRow({
        title: AppStrings.R_ADD_PROXY,
        showChevron: true,
        action: () => { this.openNewProfileEditor() },
      })
    }
  }

  @Builder
  ActionSection() {
    GroupedListSection() {
      ConciseListRow({
        title: this.testing ? AppStrings.R_TESTING_CONNECTION : AppStrings.R_TEST_CONNECTION,
        subtitle: this.testStatus,
        showChevron: false,
        action: () => { this.testConnection() },
      })
    }
  }

  @Builder
  ManualProfileRow(profile: NetworkProxyProfile) {
    ConciseListRow({
      title: this.profileDisplayTitle(profile),
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
      title: AppStrings.R_PROXY_INFO,
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
      this.EditorSectionLabel(AppStrings.R_PROXY_TYPE)
      GroupedListSection() {
        ConciseListRow({
          title: AppStrings.R_HTTP_PROXY,
          showChevron: false,
          suffixBuilderParam: (): void => this.ProtocolRadio(NetworkProxySettings.MODE_HTTP_PROXY),
          action: () => { this.updateEditorProtocol(NetworkProxySettings.MODE_HTTP_PROXY) },
        })
        ConciseListRow({
          title: AppStrings.R_HTTPS_PROXY_ENTRY,
          showChevron: false,
          suffixBuilderParam: (): void => this.ProtocolRadio(NetworkProxySettings.MODE_HTTPS_PROXY),
          action: () => { this.updateEditorProtocol(NetworkProxySettings.MODE_HTTPS_PROXY) },
        })
        ConciseListRow({
          title: AppStrings.R_SOCKS5_PROXY,
          showChevron: false,
          suffixBuilderParam: (): void => this.ProtocolRadio(NetworkProxySettings.MODE_SOCKS5),
          action: () => { this.updateEditorProtocol(NetworkProxySettings.MODE_SOCKS5) },
        })
      }
    }
    .width('100%')
  }

  @Builder
  ProtocolRadio(protocol: string) {
    Radio({ value: protocol, group: 'networkProxyEditorProtocol' })
      .checked(this.editorCurrentProtocol() === protocol)
      .onChange((checked: boolean) => {
        if (checked) {
          this.updateEditorProtocol(protocol)
        }
      })
  }

  @Builder
  ProfileEditorFields() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.EditorSectionLabel(AppStrings.R_PROXY_PARAMETERS)
      GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
        Column({ space: ThemeConstants.SPACE_LG }) {
          this.EditorHostFieldRow()
          this.EditorPortFieldRow()
          if (this.editorCurrentMode() === NetworkProxySettings.MODE_HTTP || this.editorCurrentMode() === NetworkProxySettings.MODE_SOCKS5) {
            this.EditorUsernameFieldRow()
            this.EditorPasswordFieldRow()
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
      this.EditorSectionLabel(AppStrings.R_ACTIONS)
      GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Button(AppStrings.R_COMMON_SAVE)
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
              title: AppStrings.R_DELETE_PROXY,
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
  EditorSectionLabel(label: ResourceStr) {
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
  FieldLabel(label: ResourceStr) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
  }

  @Builder
  EditorNameFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel(AppStrings.R_PROXY_NAME_PLACEHOLDER)
      AppTextField({
        text: $editorName,
        placeholder: AppStrings.R_DEFAULT_SERVER_PORT,
        onTextChange: (value: string) => { this.editorName = value }
      })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  EditorHostFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel(AppStrings.R_SERVER)
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
      this.FieldLabel(AppStrings.R_PORT)
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
      this.FieldLabel(AppStrings.R_USERNAME_OPTIONAL)
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
      this.FieldLabel(AppStrings.R_PASSWORD_OPTIONAL)
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
      this.FieldLabel(AppStrings.R_BYPASS_LIST_OPTIONAL)
      TextArea({ placeholder: AppStrings.R_ONE_DOMAIN_OR_IP_PER_LINE, text: this.editorExclusionListText })
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

  private activeSummary(): ResourceStr {
    if (this.currentMode() === NetworkProxySettings.MODE_SYSTEM) {
      return AppStrings.R_SYSTEM_PROXY
    }
    return NetworkProxySettings.summary(this.snapshot())
  }

  private profileDisplayTitle(profile: NetworkProxyProfile): ResourceStr {
    const name = (profile.name || '').trim()
    if (name) {
      return name
    }
    const snapshot = NetworkProxySettings.normalize(profile.snapshot)
    if (snapshot.host && snapshot.port > 0) {
      return `${snapshot.host}:${snapshot.port}`
    }
    return AppStrings.R_PROXY_CONFIG_TITLE
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
    return AppStrings.text(AppStrings.R_PROXY_CONFIG_TITLE, 'Proxy configuration')
  }

  private profileSubtitle(profile: NetworkProxyProfile): ResourceStr {
    return NetworkProxySettings.summary(profile.snapshot)
  }

  private snapshot(): NetworkProxySettingsSnapshot {
    return NetworkProxySettings.normalize({
      mode: this.currentMode(),
      host: this.host,
      port: this.port,
      proxyScheme: this.currentMode() === NetworkProxySettings.MODE_HTTP ? NetworkProxySettings.normalizeProxyScheme(this.proxyScheme) : NetworkProxySettings.MODE_HTTP_PROXY,
      username: this.currentMode() === NetworkProxySettings.MODE_HTTP || this.currentMode() === NetworkProxySettings.MODE_SOCKS5 ? this.username : '',
      password: this.currentMode() === NetworkProxySettings.MODE_HTTP || this.currentMode() === NetworkProxySettings.MODE_SOCKS5 ? this.password : '',
      exclusionList: NetworkProxySettings.parseExclusionList(this.exclusionListText),
    })
  }

  private editorSnapshot(): NetworkProxySettingsSnapshot {
    return NetworkProxySettings.normalize({
      mode: this.editorCurrentMode(),
      host: this.editorHost,
      port: this.editorPort,
      proxyScheme: this.editorCurrentMode() === NetworkProxySettings.MODE_HTTP ? NetworkProxySettings.normalizeProxyScheme(this.editorProxyScheme) : NetworkProxySettings.MODE_HTTP_PROXY,
      username: this.editorCurrentMode() === NetworkProxySettings.MODE_HTTP || this.editorCurrentMode() === NetworkProxySettings.MODE_SOCKS5 ? this.editorUsername : '',
      password: this.editorCurrentMode() === NetworkProxySettings.MODE_HTTP || this.editorCurrentMode() === NetworkProxySettings.MODE_SOCKS5 ? this.editorPassword : '',
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

  private editorCurrentProtocol(): string {
    if (this.editorCurrentMode() === NetworkProxySettings.MODE_SOCKS5) {
      return NetworkProxySettings.MODE_SOCKS5
    }
    return NetworkProxySettings.normalizeProxyScheme(this.editorProxyScheme)
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

  private updateEditorProtocol(value: string): void {
    if (value === NetworkProxySettings.MODE_SOCKS5) {
      this.editorMode = NetworkProxySettings.MODE_SOCKS5
      this.editorProxyScheme = NetworkProxySettings.MODE_HTTP_PROXY
      return
    }
    this.editorMode = NetworkProxySettings.MODE_HTTP
    this.editorProxyScheme = NetworkProxySettings.normalizeProxyScheme(value)
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
          this.showToast(error.message || AppStrings.text(AppStrings.R_COMMON_SAVE_FAILED, 'Save failed'))
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
        this.applyProfilesState(state)
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

    this.testing = true
    this.testStatus = AppStrings.text(AppStrings.R_TESTING, 'Testing…')
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxySettings.save(context, snapshot)
      .then(() => NetworkProxyRequest.testConnection(HttpClient.getInstance().getBaseUrl()))
      .then((response) => {
        this.testing = false
        if (response.responseCode >= 200 && response.responseCode < 300) {
          this.testStatus = AppStrings.format(AppStrings.text(AppStrings.R_CONNECTION_TEST_SUCCESS, 'Connection succeeded (HTTP {0})'), [`${response.responseCode}`])
        } else {
          this.testStatus = AppStrings.format(AppStrings.text(AppStrings.R_CONNECTION_TEST_FAILED, 'Connection failed: HTTP {0}'), [`${response.responseCode}`])
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
        this.applyProfilesState(state)
      })
      .catch((error: Error) => {
        console.error('load network proxy profiles failed: ' + (error.message || 'unknown'))
      })
  }

  private applyProfile(profile: NetworkProxyProfile): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxyProfileSettings.setActiveProfile(context, profile.id)
      .then((state) => {
        this.applyProfilesState(state)
        this.applySnapshotToPage(profile.snapshot)
        this.testStatus = ''
        this.showToast(AppStrings.text(AppStrings.R_PROFILE_SWITCHED, 'Profile switched'))
      })
      .catch((error: Error) => { this.showToast(this.profileSwitchErrorMessage(error)) })
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
      proxyScheme: NetworkProxySettings.MODE_HTTP_PROXY,
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
    this.editorProxyScheme = normalized.mode === NetworkProxySettings.MODE_HTTP ? NetworkProxySettings.normalizeProxyScheme(normalized.proxyScheme || NetworkProxySettings.MODE_HTTP_PROXY) : NetworkProxySettings.MODE_HTTP_PROXY
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
        this.applyProfilesState(state)
        return NetworkProxyProfileSettings.setActiveProfile(context, profile.id)
      })
      .then((state) => {
        this.applyProfilesState(state)
        this.applySnapshotToPage(profile.snapshot)
        this.closeEditor()
        this.showToast(AppStrings.text(AppStrings.R_COMMON_SAVED, 'Saved'))
      })
      .catch((error: Error) => { this.showToast(this.profileSaveErrorMessage(error)) })
  }

  private confirmDeleteProfile(): void {
    const profile = this.findProfile(this.editingProfileId)
    if (!profile) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.text(AppStrings.R_DELETE_PROXY, 'Delete proxy'),
      message: AppStrings.format(AppStrings.text(AppStrings.R_CONFIRM_DELETE_PROXY_MESSAGE, 'Delete “{0}”?'), [this.profileTitle(profile)]),
      primaryButton: { value: AppStrings.text(AppStrings.R_COMMON_CANCEL, 'Cancel'), action: () => { } },
      secondaryButton: {
        value: AppStrings.text(AppStrings.R_COMMON_DELETE, 'Delete'),
        action: () => { this.deleteProfile(profile) }
      }
    })
  }

  private deleteProfile(profile: NetworkProxyProfile): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxyProfileSettings.deleteProfile(context, profile.id)
      .then((state) => {
        this.applyProfilesState(state)
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
        this.showToast(AppStrings.text(AppStrings.R_COMMON_DELETED, 'Deleted'))
      })
      .catch((error: Error) => { this.showToast(error.message || AppStrings.text(AppStrings.R_COMMON_DELETE_FAILED, 'Delete failed')) })
  }

  private applyProfilesState(state: NetworkProxyProfilesState): void {
    this.profiles = this.cloneProfiles(state.profiles)
    this.activeProfileId = state.activeProfileId
  }

  private profileSwitchErrorMessage(error: Error): string {
    if (error.message === 'PROFILE_NOT_FOUND') {
      return AppStrings.text(AppStrings.R_PROXY_PROFILE_NOT_FOUND, 'Profile does not exist')
    }
    return error.message || AppStrings.text(AppStrings.R_SWITCH_FAILED, 'Switch failed')
  }

  private profileSaveErrorMessage(error: Error): string {
    if (error.message === 'PROFILE_NOT_FOUND') {
      return AppStrings.text(AppStrings.R_PROXY_PROFILE_NOT_FOUND, 'Profile does not exist')
    }
    return error.message || AppStrings.text(AppStrings.R_COMMON_SAVE_FAILED, 'Save failed')
  }

  private cloneProfiles(profiles: NetworkProxyProfile[]): NetworkProxyProfile[] {
    return profiles.map((profile: NetworkProxyProfile): NetworkProxyProfile => {
      const snapshot = NetworkProxySettings.normalize(profile.snapshot)
      return {
        id: profile.id,
        name: profile.name,
        snapshot: {
          mode: snapshot.mode,
          host: snapshot.host,
          port: snapshot.port,
          proxyScheme: snapshot.proxyScheme,
          username: snapshot.username,
          password: snapshot.password,
          exclusionList: [...snapshot.exclusionList],
        },
        updatedAt: profile.updatedAt,
      }
    })
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
    this.proxyScheme = normalized.proxyScheme || NetworkProxySettings.MODE_HTTP_PROXY
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
    return AppStrings.text(AppStrings.R_PROXY_CONFIG_TITLE, 'Proxy configuration')
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
    const rawMessage = (error.message || AppStrings.text(AppStrings.R_TEST_FAILED, 'Test failed')).trim()
    const message = rawMessage.replace(/(https?|socks5):\/\/[^\s/@:]+(:[^\s/@]*)?@/g, '$1://<credentials>@')
    if (message.length > 80) {
      return message.substring(0, 80)
    }
    return message
  }

  private showToast(message: string): void {
    promptAction.openToast({ message }).catch((_error: Error) => {})
  }
}
