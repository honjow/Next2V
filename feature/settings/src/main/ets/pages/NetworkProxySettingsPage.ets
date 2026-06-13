import { AppPrompt } from 'shared'
import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  AppModalScaffold,
  AppTextField,
  connectNetworkProxy,
  ConciseListRow,
  defaultSheetOptions,
  GroupedListSection,
  HttpClient,
  NetworkProxyProfileSettings,
  NetworkProxyRequest,
  NetworkProxySettings,
  NetworkProxyState,
  SecondaryListScaffold,
  ThemeConstants,
  type NetworkProxyMode,
  type NetworkProxyProfile,
  type NetworkProxyProfilesState,
  type NetworkProxySettingsSnapshot,
  type NetworkProxyValidationResult,
} from 'shared'
import { SettingsSectionHeader } from '../components/SettingsPageComponents'

// State Management V2 row model for a network proxy profile. Identity is the
// profile `id`; `name` and the normalized `snapshot` are @Trace so editing a
// same-id profile refreshes its row in place. This is what lets the ForEach key
// stay a pure identity key instead of churning on `updatedAt`.
@ObservedV2
class NetworkProxyProfileRow {
  id: string = ''
  @Trace name: string = ''
  @Trace snapshot: NetworkProxySettingsSnapshot = NetworkProxySettings.defaultSnapshot()

  constructor(id: string) {
    this.id = id
  }

  applyProfile(profile: NetworkProxyProfile): void {
    this.name = profile.name || ''
    // normalize() returns a fresh normalized snapshot (new object + new
    // exclusionList array), so assigning it is a @Trace reference change.
    this.snapshot = NetworkProxySettings.normalize(profile.snapshot)
  }
}

// V2 row view. Selection/enabled are page-level state passed down as @Param
// (they are cross-row/global, not row state); select/edit/apply are @Event
// callbacks. Reading the @Trace fields here is what subscribes the row to
// in-place profile edits.
@ComponentV2
struct NetworkProxyProfileRowView {
  @Param row: NetworkProxyProfileRow = new NetworkProxyProfileRow('')
  @Param selected: boolean = false
  // Named `rowEnabled` (not `enabled`) because `enabled` collides with the
  // built-in CustomComponent `.enabled()` universal attribute.
  @Param rowEnabled: boolean = true
  @Event onSelect: () => void = () => {}
  @Event onEdit: () => void = () => {}
  @Event onApply: () => void = () => {}

  build() {
    ConciseListRow({
      title: this.rowTitle(),
      subtitle: this.rowSubtitle(),
      showChevron: false,
      isEnabled: this.rowEnabled,
      prefixBuilderParam: (): void => this.SelectionRadio(),
      suffixBuilderParam: (): void => this.EditButton(),
      action: () => { this.onApply() },
    })
  }

  @Builder
  SelectionRadio() {
    // Shares the 'networkProxyProfiles' radio group with the system-proxy radio
    // rendered by the page. Kept fully state-controlled via `selected` so group
    // exclusivity follows page state across the V1/V2 boundary.
    Radio({ value: this.row.id, group: 'networkProxyProfiles' })
      .checked(this.selected)
      .onChange((checked: boolean) => {
        if (!checked) {
          return
        }
        this.onSelect()
      })
  }

  @Builder
  EditButton() {
    Button() {
      SymbolGlyph($r('sys.symbol.gearshape'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([$r('sys.color.font_secondary')])
    }
    .width(40)
    .height(40)
    .borderRadius(ThemeConstants.RADIUS_ROUND)
    .backgroundColor(Color.Transparent)
    .onClick(() => { this.onEdit() })
  }

  private rowTitle(): ResourceStr {
    const name = (this.row.name || '').trim()
    if (name) {
      return name
    }
    const snapshot = NetworkProxySettings.normalize(this.row.snapshot)
    if (snapshot.host && snapshot.port > 0) {
      return `${snapshot.host}:${snapshot.port}`
    }
    return $r('app.string.proxy_config_title')
  }

  private rowSubtitle(): ResourceStr {
    return NetworkProxySettings.summary(this.row.snapshot)
  }
}

@ComponentV2
export struct NetworkProxySettingsPage {
  // Live proxy config mirrored into AppStorageV2 by NetworkProxySettings.apply() (replaces the
  // NETWORK_PROXY_* @StorageLink set). The page reads these @Trace fields and routes every write
  // through NetworkProxySettings.apply()/save() so AppStorage and the mirror stay in lockstep.
  // (A former unused keyboard-height @StorageProp was dead and has been dropped.)
  private proxy: NetworkProxyState = connectNetworkProxy()
  @Local private portText: string = ''
  @Local private testStatus: string = ''
  @Local private testing: boolean = false
  @Local private profiles: NetworkProxyProfileRow[] = []
  // One stable observed row object per profile id, reused across reloads and
  // edits so same-id rows update in place (no ForEach key churn).
  private profileRowsById: Map<string, NetworkProxyProfileRow> = new Map()
  @Local private activeProfileId: string = ''
  @Local private profileEditorVisible: boolean = false
  @Local private editingProfileId: string = ''
  @Local private editorName: string = ''
  @Local private editorMode: string = NetworkProxySettings.MODE_HTTP
  @Local private editorProxyScheme: string = NetworkProxySettings.MODE_HTTP_PROXY
  @Local private editorHost: string = ''
  @Local private editorPort: number = 0
  @Local private editorPortText: string = ''
  @Local private editorUsername: string = ''
  @Local private editorPassword: string = ''
  @Local private editorExclusionListText: string = ''

  aboutToAppear(): void {
    this.portText = this.proxy.port > 0 ? `${this.proxy.port}` : ''
    this.loadProfiles()
  }

  build() {
    Column() {
      SecondaryListScaffold({ includeKeyboardPadding: false }) {
        ListItem() {
          this.SwitchSection()
        }
        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.proxy_connection') })
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
        title: $r('app.string.use_proxy'),
        subtitle: this.proxyEnabled() ? this.activeSummary() : $r('app.string.common_closed'),
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
        title: $r('app.string.system_proxy'),
        showChevron: false,
        prefixBuilderParam: (): void => this.SystemProxyRadio(),
        action: () => { this.selectSystemProxy() },
      })
      ForEach(this.profiles, (row: NetworkProxyProfileRow) => {
        NetworkProxyProfileRowView({
          row: row,
          selected: this.isProfileSelected(row.id),
          rowEnabled: true,
          onSelect: () => { this.selectProfileById(row.id) },
          onEdit: () => { this.openProfileEditor(row) },
          onApply: () => { this.applyProfile(row) },
        })
      }, (row: NetworkProxyProfileRow) => `proxy-profile-${row.id}`)
      ConciseListRow({
        title: $r('app.string.add_proxy'),
        showChevron: true,
        action: () => { this.openNewProfileEditor() },
      })
    }
  }

  @Builder
  ActionSection() {
    GroupedListSection() {
      ConciseListRow({
        title: this.testing ? $r('app.string.testing_connection') : $r('app.string.test_connection'),
        subtitle: this.testStatus,
        showChevron: false,
        action: () => { this.testConnection() },
      })
    }
  }

  @Builder
  SystemProxyRadio() {
    Radio({ value: NetworkProxySettings.MODE_SYSTEM, group: 'networkProxyProfiles' })
      .checked(this.proxyEnabled() && this.selectedProfileId() === NetworkProxySettings.MODE_SYSTEM)
      .onChange((checked: boolean) => {
        if (!checked) {
          return
        }
        this.selectSystemProxy()
      })
  }

  @Builder
  ProfileEditorSheet() {
    AppModalScaffold({
      title: $r('app.string.proxy_info'),
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
      this.EditorSectionLabel($r('app.string.proxy_type'))
      GroupedListSection() {
        ConciseListRow({
          title: $r('app.string.http_proxy'),
          showChevron: false,
          suffixBuilderParam: (): void => this.ProtocolRadio(NetworkProxySettings.MODE_HTTP_PROXY),
          action: () => { this.updateEditorProtocol(NetworkProxySettings.MODE_HTTP_PROXY) },
        })
        ConciseListRow({
          title: $r('app.string.https_proxy_entry'),
          showChevron: false,
          suffixBuilderParam: (): void => this.ProtocolRadio(NetworkProxySettings.MODE_HTTPS_PROXY),
          action: () => { this.updateEditorProtocol(NetworkProxySettings.MODE_HTTPS_PROXY) },
        })
        ConciseListRow({
          title: $r('app.string.socks5_proxy'),
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
      this.EditorSectionLabel($r('app.string.proxy_parameters'))
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
      this.EditorSectionLabel($r('app.string.actions'))
      GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Button($r('app.string.common_save'))
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
              title: $r('app.string.delete_proxy'),
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
      this.FieldLabel($r('app.string.proxy_name_placeholder'))
      AppTextField({
        text: this.editorName,
        placeholder: $r('app.string.default_server_port'),
        onTextChange: (value: string) => { this.editorName = value }
      })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  EditorHostFieldRow() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.FieldLabel($r('app.string.server'))
      AppTextField({
        text: this.editorHost,
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
      this.FieldLabel($r('app.string.port'))
      AppTextField({
        text: this.editorPortText,
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
      this.FieldLabel($r('app.string.username_optional'))
      AppTextField({
        text: this.editorUsername,
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
      this.FieldLabel($r('app.string.password_optional'))
      AppTextField({
        text: this.editorPassword,
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
      this.FieldLabel($r('app.string.bypass_list_optional'))
      TextArea({ placeholder: $r('app.string.one_domain_or_ip_per_line'), text: this.editorExclusionListText })
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
    return NetworkProxySettings.normalizeMode(this.proxy.mode)
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
      return $r('app.string.system_proxy')
    }
    return NetworkProxySettings.summary(this.snapshot())
  }

  private profileTitle(profile: NetworkProxyProfileRow): string {
    const name = (profile.name || '').trim()
    if (name) {
      return name
    }
    const snapshot = NetworkProxySettings.normalize(profile.snapshot)
    if (snapshot.host && snapshot.port > 0) {
      return `${snapshot.host}:${snapshot.port}`
    }
    return AppStrings.text($r('app.string.proxy_config_title'), 'Proxy configuration')
  }

  private snapshot(): NetworkProxySettingsSnapshot {
    return NetworkProxySettings.normalize({
      mode: this.currentMode(),
      host: this.proxy.host,
      port: this.proxy.port,
      proxyScheme: this.currentMode() === NetworkProxySettings.MODE_HTTP ? NetworkProxySettings.normalizeProxyScheme(this.proxy.proxyScheme) : NetworkProxySettings.MODE_HTTP_PROXY,
      username: this.currentMode() === NetworkProxySettings.MODE_HTTP || this.currentMode() === NetworkProxySettings.MODE_SOCKS5 ? this.proxy.username : '',
      password: this.currentMode() === NetworkProxySettings.MODE_HTTP || this.currentMode() === NetworkProxySettings.MODE_SOCKS5 ? this.proxy.password : '',
      exclusionList: NetworkProxySettings.parseExclusionList(this.proxy.exclusionListText),
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
      // Optimistic mirror write so the toggle reflects immediately; saveCurrent() -> apply()
      // synchronously persists to AppStorage and re-writes the mirror.
      this.proxy.mode = NetworkProxySettings.MODE_OFF
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
    this.proxy.mode = NetworkProxySettings.MODE_SYSTEM
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
          this.showToast(error.message || AppStrings.text($r('app.string.common_save_failed'), 'Save failed'))
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
    this.testStatus = AppStrings.text($r('app.string.testing'), 'Testing…')
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxySettings.save(context, snapshot)
      .then(() => NetworkProxyRequest.testConnection(HttpClient.getInstance().getBaseUrl()))
      .then((response) => {
        this.testing = false
        if (response.responseCode >= 200 && response.responseCode < 300) {
          this.testStatus = AppStrings.format(AppStrings.text($r('app.string.connection_test_success'), 'Connection succeeded (HTTP {0})'), [`${response.responseCode}`])
        } else {
          this.testStatus = AppStrings.format(AppStrings.text($r('app.string.connection_test_failed'), 'Connection failed: HTTP {0}'), [`${response.responseCode}`])
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

  private applyProfile(profile: NetworkProxyProfileRow): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NetworkProxyProfileSettings.setActiveProfile(context, profile.id)
      .then((state) => {
        this.applyProfilesState(state)
        this.applySnapshotToPage(profile.snapshot)
        this.testStatus = ''
        this.showToast(AppStrings.text($r('app.string.profile_switched'), 'Profile switched'))
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

  private openProfileEditor(profile: NetworkProxyProfileRow): void {
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
        this.showToast(AppStrings.text($r('app.string.common_saved'), 'Saved'))
      })
      .catch((error: Error) => { this.showToast(this.profileSaveErrorMessage(error)) })
  }

  private confirmDeleteProfile(): void {
    const profile = this.findProfile(this.editingProfileId)
    if (!profile) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.text($r('app.string.delete_proxy'), 'Delete proxy'),
      message: AppStrings.format(AppStrings.text($r('app.string.confirm_delete_proxy_message'), 'Delete “{0}”?'), [this.profileTitle(profile)]),
      primaryButton: { value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'), action: () => { } },
      secondaryButton: {
        value: AppStrings.text($r('app.string.common_delete'), 'Delete'),
        action: () => { this.deleteProfile(profile) }
      }
    })
  }

  private deleteProfile(profile: NetworkProxyProfileRow): void {
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
          this.proxy.mode = NetworkProxySettings.MODE_OFF
          this.saveCurrent(false)
        }
        this.closeEditor()
        this.showToast(AppStrings.text($r('app.string.common_deleted'), 'Deleted'))
      })
      .catch((error: Error) => { this.showToast(error.message || AppStrings.text($r('app.string.common_delete_failed'), 'Delete failed')) })
  }

  private applyProfilesState(state: NetworkProxyProfilesState): void {
    this.applyProfiles(state.profiles)
    this.activeProfileId = state.activeProfileId
  }

  // Reuse/prune stable row objects by id, then apply latest name + normalized
  // snapshot in place. Reassigning this.profiles only re-keys membership/order;
  // unchanged-id rows keep their identity and refresh via @Trace.
  private applyProfiles(profiles: NetworkProxyProfile[]): void {
    const rows = this.ensureProfileRowsForIds(profiles.map((profile: NetworkProxyProfile) => profile.id))
    for (let index = 0; index < profiles.length; index++) {
      rows[index].applyProfile(profiles[index])
    }
    this.profiles = rows
  }

  private ensureProfileRowsForIds(ids: string[]): NetworkProxyProfileRow[] {
    const validIds: Set<string> = new Set(ids)
    const byId: Map<string, NetworkProxyProfileRow> = this.profileRowsById
    for (const existingId of Array.from(byId.keys())) {
      if (!validIds.has(existingId)) {
        byId.delete(existingId)
      }
    }
    return ids.map((id: string): NetworkProxyProfileRow => this.profileRowForId(id))
  }

  private profileRowForId(id: string): NetworkProxyProfileRow {
    const existing = this.profileRowsById.get(id)
    if (existing) {
      return existing
    }
    const row = new NetworkProxyProfileRow(id)
    this.profileRowsById.set(id, row)
    return row
  }

  // Selection/mode/active are page state, not row state; computed here and
  // passed to the V2 row as @Param so radio exclusivity tracks page state.
  private isProfileSelected(id: string): boolean {
    return this.proxyEnabled() && this.selectedProfileId() === id
  }

  private selectProfileById(id: string): void {
    const profile = this.findProfile(id)
    if (profile) {
      this.applyProfile(profile)
    }
  }

  private profileSwitchErrorMessage(error: Error): string {
    if (error.message === 'PROFILE_NOT_FOUND') {
      return AppStrings.text($r('app.string.proxy_profile_not_found'), 'Profile does not exist')
    }
    return error.message || AppStrings.text($r('app.string.switch_failed'), 'Switch failed')
  }

  private profileSaveErrorMessage(error: Error): string {
    if (error.message === 'PROFILE_NOT_FOUND') {
      return AppStrings.text($r('app.string.proxy_profile_not_found'), 'Profile does not exist')
    }
    return error.message || AppStrings.text($r('app.string.common_save_failed'), 'Save failed')
  }

  private findProfile(id: string): NetworkProxyProfileRow | undefined {
    for (const profile of this.profiles) {
      if (profile.id === id) {
        return profile
      }
    }
    return undefined
  }

  private applySnapshotToPage(snapshot: NetworkProxySettingsSnapshot): void {
    const normalized = NetworkProxySettings.normalize(snapshot)
    // Was a set of direct NETWORK_PROXY_* @StorageLink writes; apply() writes the same AppStorage
    // keys AND dual-writes the V2 mirror the page now reads, so the page reflects the active config.
    NetworkProxySettings.apply(normalized)
    this.portText = normalized.port > 0 ? `${normalized.port}` : ''
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
    return AppStrings.text($r('app.string.proxy_config_title'), 'Proxy configuration')
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
    const rawMessage = (error.message || AppStrings.text($r('app.string.test_failed'), 'Test failed')).trim()
    const message = rawMessage.replace(/(https?|socks5):\/\/[^\s/@:]+(:[^\s/@]*)?@/g, '$1://<credentials>@')
    if (message.length > 80) {
      return message.substring(0, 80)
    }
    return message
  }

  private showToast(message: string): void {
    AppPrompt.openToast({ message }).catch((_error: Error) => {})
  }
}
