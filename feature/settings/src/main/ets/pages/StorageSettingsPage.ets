import { AppPrompt } from 'shared'
import { common } from '@kit.AbilityKit'
import type {
  BackupEnvelopeV1,
  BackupExportOptions,
  BackupParseResult,
  CacheDeviceQaSeedResult,
  CacheStats,
} from 'shared'
import {
  AppStrings,
  AppModalScaffold,
  AppTextField,
  BackupService,
  CacheDeviceQaSeed,
  CacheSettings,
  ConciseListRow,
  defaultSheetOptions,
  GroupedListSection,
  LocalDataSettings,
  SecondaryListScaffold,
  ThemeConstants,
  AccountStoreQaSeed,
} from 'shared'
import BuildProfile from '../../../../BuildProfile'
import { SettingsDivider, SettingsSectionHeader } from '../components/SettingsPageComponents'
import {
  StorageSettingsCoordinator,
  type StorageConfirmDialogCopy,
} from '../model/StorageSettingsCoordinator'
import { BackupFilePickerCoordinator } from '../model/BackupFilePickerCoordinator'
@ComponentV2
export struct StorageSettingsPage {
  @Local private cacheStats: CacheStats = { topicListCount: 0, topicDetailCount: 0, updatedAt: 0 };
  @Local private cacheMessage: string = '';
  @Local private seedMessage: string = '';
  @Local private localDataMessage: string = '';
  @Local private backupMessage: string = '';
  @Local private pendingBackupEnvelope: BackupEnvelopeV1 | null = null;
  @Local private accountSeedMessage: string = '';
  // Export sheet: toggle for including accounts/credentials + the two password fields. These hold
  // the password only while the sheet is open; they are cleared the moment the sheet closes and
  // are never persisted, logged, or sent to diagnostics.
  @Local private exportSheetVisible: boolean = false;
  @Local private exportIncludeUserInfo: boolean = false;
  @Local private exportPassword: string = '';
  @Local private exportPasswordConfirm: string = '';
  @Local private exportPasswordError: string = '';
  // Import password sheet: shown when the selected file is an encrypted Next2V backup.
  @Local private importSheetVisible: boolean = false;
  @Local private importPassword: string = '';
  @Local private importPasswordError: string = '';
  @Local private pendingEncryptedRaw: string = '';

  aboutToAppear(): void {
    this.loadCacheStats()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.offline_cache') })
        }
        ListItem() {
          this.CacheSection()
        }

        if (BuildProfile.DEBUG && CacheDeviceQaSeed.isEnabled()) {
          ListItem() {
            SettingsSectionHeader({ title: $r('app.string.cache_qa_seed') })
          }

          ListItem() {
            this.CacheQaSeedSection()
          }
        }

        if (BuildProfile.DEBUG && AccountStoreQaSeed.isEnabled()) {
          ListItem() {
            SettingsSectionHeader({ title: $r('app.string.account_qa_seed') })
          }

          ListItem() {
            this.AccountQaSeedSection()
          }
        }
        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.backup_section') })
        }
        ListItem() {
          this.BackupSection()
        }
        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.local_data') })
        }
        ListItem() {
          this.LocalDataSection()
        }
      }
      // Each sheet must bind to its OWN element. Chaining two .bindSheet() on one container makes
      // the second (import) shadow the first (export), so the export sheet never opened. Hosting each
      // on its own 1x1 Blank (the TopicDetailPage reply-sheet pattern) keeps both independently
      // presentable.
      this.ExportSheetHost()
      this.ImportSheetHost()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  ExportSheetHost() {
    Blank()
      .width(1)
      .height(1)
      .bindSheet(
        $$this.exportSheetVisible,
        this.ExportBackupSheet(),
        defaultSheetOptions(
          SheetSize.LARGE,
          () => {
            this.closeExportSheet()
          },
          [SheetSize.LARGE],
        ),
      )
  }

  @Builder
  ImportSheetHost() {
    Blank()
      .width(1)
      .height(1)
      .bindSheet(
        $$this.importSheetVisible,
        this.ImportPasswordSheet(),
        defaultSheetOptions(
          SheetSize.LARGE,
          () => {
            this.closeImportSheet()
          },
          [SheetSize.LARGE],
        ),
      )
  }

  @Builder
  CacheSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.offline_cache'),
        subtitle: StorageSettingsCoordinator.cacheSubtitle(this.cacheStats),
        showChevron: false,
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.refresh_cache_status'),
        showChevron: false,
        action: () => {
          this.loadCacheStats()
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.clear_cache'),
        subtitle: this.cacheMessage,
        destructive: true,
        showChevron: false,
        action: () => {
          this.confirmClearCache()
        },
      })
    }
  }

  @Builder
  BackupSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.export_backup'),
        subtitle:
          this.backupMessage ||
          $r('app.string.backup_export_subtitle'),
        showChevron: false,
        action: () => {
          this.openExportSheet()
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.import_backup'),
        subtitle: $r('app.string.backup_import_subtitle'),
        showChevron: false,
        action: () => {
          this.selectImportBackup()
        },
      })
    }
  }

  @Builder
  LocalDataSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.clear_local_data'),
        subtitle: this.localDataMessage,
        destructive: true,
        showChevron: false,
        action: () => {
          this.confirmClearLocalData()
        },
      })
    }
  }

  @Builder
  ExportBackupSheet() {
    AppModalScaffold({
      title: $r('app.string.export_backup'),
      includeKeyboardPadding: true,
      contentBackgroundColor: $r('sys.color.ohos_id_color_sub_background'),
      closeAction: () => {
        this.closeExportSheet()
      },
    }) {
      ListItem() {
        this.ExportUserInfoToggleSection()
      }
      if (this.exportIncludeUserInfo) {
        ListItem() {
          this.ExportPasswordSection()
        }
      }
      ListItem() {
        this.ExportActionSection()
      }
    }
  }

  @Builder
  ExportUserInfoToggleSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.backup_include_user_info'),
        subtitle: $r('app.string.backup_include_user_info_hint'),
        hasSwitch: true,
        checked: this.exportIncludeUserInfo,
        showChevron: false,
        switchAction: (value: boolean) => {
          this.exportIncludeUserInfo = value
          if (!value) {
            this.exportPassword = ''
            this.exportPasswordConfirm = ''
            this.exportPasswordError = ''
          }
        },
      })
    }
  }

  @Builder
  ExportPasswordSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.SheetSectionLabel($r('app.string.backup_set_password'))
      GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
        Column({ space: ThemeConstants.SPACE_LG }) {
          this.SheetPasswordField(
            $r('app.string.backup_password_label'),
            this.exportPassword,
            (value: string) => {
              this.exportPassword = value
              this.exportPasswordError = ''
            },
          )
          this.SheetPasswordField(
            $r('app.string.backup_password_confirm_label'),
            this.exportPasswordConfirm,
            (value: string) => {
              this.exportPasswordConfirm = value
              this.exportPasswordError = ''
            },
          )
          if (this.exportPasswordError) {
            Text(this.exportPasswordError)
              .fontSize(ThemeConstants.FONT_SIZE_TAG)
              .fontColor(Color.Red)
              .width('100%')
          }
        }.width('100%')
      }
    }.width('100%')
  }

  @Builder
  ExportActionSection() {
    GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
      Button($r('app.string.export_backup'))
        .type(ButtonType.Normal)
        .height(ThemeConstants.TOUCH_TARGET_SM)
        .width('100%')
        .borderRadius(ThemeConstants.RADIUS_MD)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
        .onClick(() => {
          this.confirmExportFromSheet()
        })
    }
  }

  @Builder
  ImportPasswordSheet() {
    AppModalScaffold({
      title: $r('app.string.import_backup'),
      includeKeyboardPadding: true,
      contentBackgroundColor: $r('sys.color.ohos_id_color_sub_background'),
      closeAction: () => {
        this.closeImportSheet()
      },
    }) {
      ListItem() {
        this.ImportPasswordSection()
      }
      ListItem() {
        this.ImportActionSection()
      }
    }
  }

  @Builder
  ImportPasswordSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.SheetSectionLabel($r('app.string.backup_enter_password'))
      GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
        Column({ space: ThemeConstants.SPACE_LG }) {
          this.SheetPasswordField(
            $r('app.string.backup_password_label'),
            this.importPassword,
            (value: string) => {
              this.importPassword = value
              this.importPasswordError = ''
            },
          )
          if (this.importPasswordError) {
            Text(this.importPasswordError)
              .fontSize(ThemeConstants.FONT_SIZE_TAG)
              .fontColor(Color.Red)
              .width('100%')
          }
        }.width('100%')
      }
    }.width('100%')
  }

  @Builder
  ImportActionSection() {
    GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
      Button($r('app.string.backup_unlock'))
        .type(ButtonType.Normal)
        .height(ThemeConstants.TOUCH_TARGET_SM)
        .width('100%')
        .borderRadius(ThemeConstants.RADIUS_MD)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
        .onClick(() => {
          this.confirmDecryptImport()
        })
    }
  }

  @Builder
  SheetSectionLabel(label: ResourceStr) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_SECTION_TITLE)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
  }

  @Builder
  SheetPasswordField(label: ResourceStr, value: string, onChange: (value: string) => void) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      AppTextField({
        text: value,
        placeholder: '',
        inputType: InputType.Password,
        onTextChange: (next: string) => {
          onChange(next)
        },
      }).width('100%')
    }.width('100%')
  }

  @Builder
  CacheQaSeedSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.seed_all_cache_scenarios'),
        subtitle: this.seedMessage,
        showChevron: false,
        action: () => {
          this.runSeedAll()
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.seed_large_list_file_cache'),
        showChevron: false,
        action: () => {
          this.runSeedAction('large', () =>
            CacheDeviceQaSeed.seedLargeFileBackedList(this.hostContext()),
          )
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.seed_mixed_row_cache'),
        showChevron: false,
        action: () => {
          this.runSeedAction('mixed', () =>
            CacheDeviceQaSeed.seedMixedInlineFile(this.hostContext()),
          )
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.seed_invalid_path_row'),
        showChevron: false,
        action: () => {
          this.runSeedAction('invalid', () =>
            CacheDeviceQaSeed.seedInvalidPathRow(this.hostContext()),
          )
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.seed_orphan_file'),
        showChevron: false,
        action: () => {
          this.runSeedAction('orphan', () =>
            CacheDeviceQaSeed.seedOrphanPayloadFile(this.hostContext()),
          )
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.seed_missing_file_row'),
        showChevron: false,
        action: () => {
          this.runSeedAction('missing', () =>
            CacheDeviceQaSeed.seedMissingFileRow(this.hostContext()),
          )
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.seed_hash_mismatch_row'),
        showChevron: false,
        action: () => {
          this.runSeedAction('hash', () =>
            CacheDeviceQaSeed.seedHashMismatchRow(this.hostContext()),
          )
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.verify_hash_repair'),
        showChevron: false,
        action: () => {
          this.runSeedAction('hash-read', () =>
            CacheDeviceQaSeed.validateHashMismatchRepair(this.hostContext()),
          )
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.seed_expired_row'),
        showChevron: false,
        action: () => {
          this.runSeedAction('expired', () => CacheDeviceQaSeed.seedExpiredRow(this.hostContext()))
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.reset_seed_cache'),
        destructive: true,
        showChevron: false,
        action: () => {
          this.runSeedAction('reset', () => CacheDeviceQaSeed.resetSeededCache(this.hostContext()))
        },
      })
    }
  }

  @Builder
  AccountQaSeedSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.seed_account_records'),
        subtitle: this.accountSeedMessage,
        showChevron: false,
        action: () => {
          this.runAccountSeedAction()
        },
      })
      SettingsDivider()
      ConciseListRow({
        title: $r('app.string.reset_seeded_accounts'),
        destructive: true,
        showChevron: false,
        action: () => {
          this.runAccountResetAction()
        },
      })
    }
  }

  private loadCacheStats(): void {
    const context = this.hostContext()
    CacheSettings.loadStats(context)
      .then((stats: CacheStats) => {
        this.cacheStats = stats
      })
      .catch((error: Error) => {
        this.cacheMessage = StorageSettingsCoordinator.readCacheErrorMessage(error)
        console.error('load cache stats failed: ' + error.message)
      })
  }

  private confirmClearCache(): void {
    const copy: StorageConfirmDialogCopy = StorageSettingsCoordinator.clearCacheDialogCopy()
    AppPrompt.showAlertDialog(this.getUIContext(), {
      title: copy.title,
      message: copy.message,
      primaryButton: {
        value: copy.cancelValue,
        action: () => {},
      },
      secondaryButton: {
        value: copy.confirmValue,
        fontColor: Color.Red,
        action: () => {
          this.clearCache()
        },
      },
    })
  }

  private clearCache(): void {
    const context = this.hostContext()
    CacheSettings.clear(context)
      .then(() => {
        this.cacheMessage = StorageSettingsCoordinator.clearSuccessMessage()
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.cacheMessage = StorageSettingsCoordinator.clearErrorMessage(error)
      })
  }

  private confirmClearLocalData(): void {
    const copy: StorageConfirmDialogCopy = StorageSettingsCoordinator.clearLocalDataDialogCopy()
    AppPrompt.showAlertDialog(this.getUIContext(), {
      title: copy.title,
      message: copy.message,
      primaryButton: {
        value: copy.cancelValue,
        action: () => {},
      },
      secondaryButton: {
        value: copy.confirmValue,
        fontColor: Color.Red,
        action: () => {
          this.clearLocalData()
        },
      },
    })
  }

  private clearLocalData(): void {
    const context = this.hostContext()
    LocalDataSettings.clearAll(context)
      .then(() => {
        this.cacheMessage = StorageSettingsCoordinator.clearSuccessMessage()
        this.localDataMessage = StorageSettingsCoordinator.clearSuccessMessage()
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.localDataMessage = StorageSettingsCoordinator.clearErrorMessage(error)
      })
  }

  private openExportSheet(): void {
    this.exportIncludeUserInfo = false
    this.exportPassword = ''
    this.exportPasswordConfirm = ''
    this.exportPasswordError = ''
    this.exportSheetVisible = true
  }

  private closeExportSheet(): void {
    this.exportSheetVisible = false
    // Drop any typed password the instant the sheet closes; it never outlives the export.
    this.exportPassword = ''
    this.exportPasswordConfirm = ''
    this.exportPasswordError = ''
  }

  private confirmExportFromSheet(): void {
    let options: BackupExportOptions | undefined = undefined
    if (this.exportIncludeUserInfo) {
      const error = StorageSettingsCoordinator.validateExportPassword(
        this.exportPassword,
        this.exportPasswordConfirm,
      )
      if (error) {
        this.exportPasswordError = error
        return
      }
      options = { includeUserInfo: true, password: this.exportPassword }
    }
    this.exportSheetVisible = false
    this.runExportBackup(options)
    // Clear the password buffers after handing the value to the export call.
    this.exportPassword = ''
    this.exportPasswordConfirm = ''
    this.exportPasswordError = ''
  }

  private runExportBackup(options?: BackupExportOptions): void {
    BackupFilePickerCoordinator.exportBackup(
      this.hostContext(),
      { versionName: '1.0.6', versionCode: 19 },
      options,
    )
      .then((_uri: string) => {
        this.backupMessage = StorageSettingsCoordinator.backupSuccessMessage(true)
      })
      .catch((error: Error) => {
        this.backupMessage = StorageSettingsCoordinator.backupErrorMessage(error.message)
      })
  }

  private selectImportBackup(): void {
    BackupFilePickerCoordinator.selectImport(this.hostContext())
      .then((selection) => {
        // Encrypted backups parse as not-ok with code 'password_required'. Stash the raw bytes and
        // prompt for the password instead of treating it as an invalid file.
        if (selection.parseResult.encrypted === true) {
          this.pendingEncryptedRaw = selection.raw
          this.importPassword = ''
          this.importPasswordError = ''
          this.importSheetVisible = true
          return
        }
        if (!selection.parseResult.ok || !selection.parseResult.envelope) {
          this.showBackupToast(
            StorageSettingsCoordinator.backupErrorMessage(
              selection.parseResult.code || selection.parseResult.message,
            ),
          )
          return
        }
        this.showImportPreview(selection.parseResult.envelope)
      })
      .catch((error: Error) => {
        this.showBackupToast(StorageSettingsCoordinator.backupErrorMessage(error.message))
      })
  }

  private closeImportSheet(): void {
    this.importSheetVisible = false
    // Discard both the typed password and the raw encrypted blob when the sheet closes.
    this.importPassword = ''
    this.importPasswordError = ''
    this.pendingEncryptedRaw = ''
  }

  private confirmDecryptImport(): void {
    if (!this.pendingEncryptedRaw || !this.importPassword) {
      this.importPasswordError = AppStrings.text(
        $r('app.string.backup_password_required'),
        'Enter the backup password.',
      )
      return
    }
    const raw = this.pendingEncryptedRaw
    const password = this.importPassword
    BackupFilePickerCoordinator.decryptSelected(raw, password)
      .then((parseResult: BackupParseResult) => {
        if (!parseResult.ok || !parseResult.envelope) {
          this.importPasswordError = StorageSettingsCoordinator.backupErrorMessage(
            parseResult.code || parseResult.message,
          )
          return
        }
        this.importSheetVisible = false
        this.importPassword = ''
        this.importPasswordError = ''
        this.pendingEncryptedRaw = ''
        this.showImportPreview(parseResult.envelope)
      })
      .catch((error: Error) => {
        this.importPasswordError = StorageSettingsCoordinator.backupErrorMessage(error.message)
      })
  }

  private showImportPreview(envelope: BackupEnvelopeV1): void {
    this.pendingBackupEnvelope = envelope
    const preview = BackupService.preview(envelope)
    const copy: StorageConfirmDialogCopy =
      StorageSettingsCoordinator.backupImportPreviewCopy(preview)
    AppPrompt.showAlertDialog(this.getUIContext(), {
      title: copy.title,
      message: copy.message,
      primaryButton: { value: copy.cancelValue, action: () => {} },
      secondaryButton: {
        value: copy.confirmValue,
        action: () => {
          this.confirmImportBackup()
        },
      },
    })
  }

  private confirmImportBackup(): void {
    if (!this.pendingBackupEnvelope) {
      return
    }
    const preview = BackupService.preview(this.pendingBackupEnvelope)
    const copy: StorageConfirmDialogCopy =
      StorageSettingsCoordinator.backupImportConfirmDialogCopy(preview)
    AppPrompt.showAlertDialog(this.getUIContext(), {
      title: copy.title,
      message: copy.message,
      primaryButton: { value: copy.cancelValue, action: () => {} },
      secondaryButton: {
        value: copy.confirmValue,
        fontColor: Color.Red,
        action: () => {
          this.restorePendingBackup()
        },
      },
    })
  }

  private restorePendingBackup(): void {
    const envelope = this.pendingBackupEnvelope
    if (!envelope) {
      return
    }
    BackupFilePickerCoordinator.restoreSelected(this.hostContext(), envelope)
      .then(() => {
        this.showBackupToast(StorageSettingsCoordinator.backupSuccessMessage(false))
        this.pendingBackupEnvelope = null
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.showBackupToast(StorageSettingsCoordinator.backupErrorMessage(error.message))
      })
  }

  // Import outcomes are shown as a toast, not the export-row subtitle: the user tapped 导入备份, so
  // the result shouldn't land under the unrelated 导出备份 row (export still uses backupMessage there).
  private showBackupToast(message: string): void {
    AppPrompt.openToast({ message: message }).catch((_error: Error) => {})
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private runSeedAll(): void {
    if (!BuildProfile.DEBUG || !CacheDeviceQaSeed.isEnabled()) {
      this.seedMessage = StorageSettingsCoordinator.seedUnavailableMessage()
      return
    }
    CacheDeviceQaSeed.seedAll(this.hostContext())
      .then((results: CacheDeviceQaSeedResult[]) => {
        this.seedMessage = StorageSettingsCoordinator.seedAllSuccessMessage(results)
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.seedMessage = StorageSettingsCoordinator.seedErrorMessage(error)
      })
  }

  private runSeedAction(label: string, action: () => Promise<CacheDeviceQaSeedResult>): void {
    if (!BuildProfile.DEBUG || !CacheDeviceQaSeed.isEnabled()) {
      this.seedMessage = StorageSettingsCoordinator.seedUnavailableMessage()
      return
    }
    action()
      .then((result: CacheDeviceQaSeedResult) => {
        this.seedMessage = StorageSettingsCoordinator.seedActionSuccessMessage(label, result)
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.seedMessage = StorageSettingsCoordinator.seedErrorMessage(error)
      })
  }

  private runAccountSeedAction(): void {
    if (!BuildProfile.DEBUG || !AccountStoreQaSeed.isEnabled()) {
      this.accountSeedMessage = StorageSettingsCoordinator.seedUnavailableMessage()
      return
    }
    AccountStoreQaSeed.seedFakeAccounts(this.hostContext())
      .then((count: number) => {
        this.accountSeedMessage = `Seeded ${count} account record(s)`
      })
      .catch((error: Error) => {
        this.accountSeedMessage = StorageSettingsCoordinator.seedErrorMessage(error)
      })
  }

  private runAccountResetAction(): void {
    if (!BuildProfile.DEBUG || !AccountStoreQaSeed.isEnabled()) {
      this.accountSeedMessage = StorageSettingsCoordinator.seedUnavailableMessage()
      return
    }
    AccountStoreQaSeed.resetSeededAccounts(this.hostContext())
      .then(() => {
        this.accountSeedMessage = StorageSettingsCoordinator.clearSuccessMessage()
      })
      .catch((error: Error) => {
        this.accountSeedMessage = StorageSettingsCoordinator.clearErrorMessage(error)
      })
  }
}
