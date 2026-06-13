import { AppPrompt } from 'shared'
import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import {
  AppStrings,
  connectDiagnostics,
  ConciseListRow,
  DiagnosticLogger,
  DiagnosticsLogFileSink,
  DiagnosticsSettings,
  DiagnosticsState,
  GroupedListSection,
  SecondaryListScaffold,
} from 'shared'
import type { DiagnosticsLogFileInfo } from 'shared'
import {
  SettingsDivider,
  SettingsSectionHeader,
  SettingsToggleRow,
} from '../components/SettingsPageComponents'
import { SettingsSaveCoordinator } from '../model/SettingsSaveCoordinator'

@ComponentV2
export struct DiagnosticsLogPage {
  // Diagnostics-enabled mirrored into AppStorageV2 by DiagnosticsSettings.apply()
  // (was @StorageLink(DIAGNOSTICS_ENABLED)); the toggle reroutes through saveDiagnostics().
  private diagnostics: DiagnosticsState = connectDiagnostics()
  @Local private logCount: number = 0
  @Local private logFiles: DiagnosticsLogFileInfo[] = []
  private diagnosticsShareController?: systemShare.ShareController

  aboutToAppear(): void {
    this.refreshLogState()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.diagnostics') })
        }

        ListItem() {
          this.DiagnosticsToggleSection()
        }

        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.logs') })
        }

        ListItem() {
          this.DiagnosticsActionsSection()
        }

        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.log_file') })
        }

        ListItem() {
          this.DiagnosticsLogFilesSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  DiagnosticsToggleSection() {
    GroupedListSection() {
      SettingsToggleRow({
        title: $r('app.string.nav_diagnostics'),
        checked: this.diagnostics.enabled,
        changeAction: (value: boolean) => {
          this.updateDiagnosticsEnabled(value)
        },
      })
    }
  }

  @Builder
  DiagnosticsActionsSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AppStrings.format(AppStrings.text($r('app.string.diagnostics_current_launch_recent_count'), 'Recent this launch {0}'), [`${this.logCount}`]),
        subtitle: this.logFiles.length > 0 ? this.formatRetainedLogFilesCount(this.logFiles.length) : $r('app.string.no_local_log_files'),
        showChevron: false,
        action: () => {
          this.refreshLogState()
        },
      })

      SettingsDivider()

      ConciseListRow({
        title: $r('app.string.clear_boot_records'),
        destructive: true,
        showChevron: false,
        action: () => {
          this.clearDiagnosticsText()
        },
      })
    }
  }

  @Builder
  DiagnosticsLogFilesSection() {
    GroupedListSection() {
      if (this.logFiles.length <= 0) {
        ConciseListRow({
          title: $r('app.string.no_log_files'),
          subtitle: $r('app.string.reopen_keeps_logs'),
          showChevron: false,
          action: () => {
            this.refreshLogState()
          },
        })
      } else {
        ForEach(this.logFiles, (file: DiagnosticsLogFileInfo, index: number) => {
          this.DiagnosticsLogFileRow(file)
          if (index < this.logFiles.length - 1) {
            SettingsDivider()
          }
        }, (file: DiagnosticsLogFileInfo) => file.fileName)
      }
    }
  }

  @Builder
  DiagnosticsLogFileRow(file: DiagnosticsLogFileInfo) {
    ConciseListRow({
      title: this.logFileTitle(file),
      subtitle: AppStrings.format(AppStrings.text($r('app.string.diagnostics_log_file_share_hint'), '{0} · Tap to share'), [this.formatFileSize(file.sizeBytes)]),
      showChevron: false,
      action: () => {
        this.handleShareLogFileClick(file)
      },
    })
  }

  private formatRetainedLogFilesCount(count: number): ResourceStr {
    return AppStrings.format(AppStrings.text($r('app.string.retained_local_log_files_count_arg'), 'Retained {0} local log files'), [`${count}`])
  }

  private updateDiagnosticsEnabled(enabled: boolean): void {
    // saveDiagnostics -> DiagnosticsSettings.apply() synchronously writes both AppStorage
    // and the V2 mirror, so the toggle (this.diagnostics.enabled) re-renders.
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveDiagnostics(context, enabled)
  }

  private refreshLogState(): void {
    this.logCount = DiagnosticsSettings.count()
    this.logFiles = DiagnosticsLogFileSink.listRetainedLogFiles()
  }

  private handleShareLogFileClick(file: DiagnosticsLogFileInfo): void {
    DiagnosticLogger.info('diagnostics', 'diagnostics_share_tap', {
      source: 'diagnostics_log_page',
      fileName: file.fileName,
      current: file.isCurrent,
    })
    setTimeout(() => {
      this.shareDiagnosticsLogFile(file)
    }, 0)
  }

  private shareDiagnosticsLogFile(file: DiagnosticsLogFileInfo): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    try {
      DiagnosticLogger.info('diagnostics', 'diagnostics_share_show_start', {
        source: 'diagnostics_log_page',
        fileName: file.fileName,
        current: file.isCurrent,
      })
      const data = new systemShare.SharedData({
        utd: utd.UniformDataType.FILE,
        title: file.fileName,
        label: file.fileName,
        description: 'Redacted local diagnostics log file',
        uri: file.uri,
      })
      this.diagnosticsShareController = new systemShare.ShareController(data)
      this.diagnosticsShareController
        .show(context, {
          selectionMode: systemShare.SelectionMode.SINGLE,
          previewMode: systemShare.SharePreviewMode.DEFAULT,
        })
        .then(() => {
          DiagnosticLogger.info('diagnostics', 'diagnostics_share_show_success', {
            source: 'diagnostics_log_page',
            fileName: file.fileName,
          })
        })
        .catch((error: Error) => {
          this.diagnosticsShareController = undefined
          DiagnosticLogger.warn('diagnostics', 'diagnostics_share_show_error', {
            source: 'diagnostics_log_page',
            fileName: file.fileName,
          }, error)
          this.copyDiagnosticsTextWithToast(AppStrings.text($r('app.string.share_file_unavailable_copied'), 'Share file unavailable; copied for manual paste'), AppStrings.text($r('app.string.share_failed'), 'Share failed'), DiagnosticsLogFileSink.readLogFileText(file.fileName))
        })
    } catch (_error) {
      DiagnosticLogger.warn('diagnostics', 'diagnostics_share_show_error', {
        source: 'diagnostics_log_page',
        fileName: file.fileName,
        phase: 'share_file',
        errorName: 'Error',
        errorMessage: 'share_failed',
      })
      this.copyDiagnosticsTextWithToast(AppStrings.text($r('app.string.share_file_unavailable_copied'), 'Share file unavailable; copied for manual paste'), AppStrings.text($r('app.string.share_failed'), 'Share failed'), DiagnosticsLogFileSink.readLogFileText(file.fileName))
    }
  }

  private copyDiagnosticsTextWithToast(successMessage: string, failureMessage: string, textOverride: string = ''): void {
    try {
      const text = textOverride || DiagnosticsSettings.exportText() || AppStrings.text($r('app.string.no_diagnostics_logs'), 'No diagnostics logs')
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      pasteboard.getSystemPasteboard().setDataSync(data)
      DiagnosticLogger.info('diagnostics', 'diagnostics_log_copy_success', { textLength: text.length })
      AppPrompt.openToast({ message: successMessage }).catch((_error: Error) => {})
    } catch (error) {
      DiagnosticLogger.warn('diagnostics', 'diagnostics_log_copy_error', {}, error as Error)
      AppPrompt.openToast({ message: failureMessage }).catch((_toastError: Error) => {})
    }
  }

  private clearDiagnosticsText(): void {
    DiagnosticsSettings.clearLogs()
    this.refreshLogState()
    AppPrompt.openToast({ message: AppStrings.text($r('app.string.boot_records_cleared'), 'This launch record has been cleared') }).catch((_error: Error) => {})
  }

  private logFileTitle(file: DiagnosticsLogFileInfo): ResourceStr {
    const timestamp = this.formatLogTimestamp(file.createdAtMs)
    return file.isCurrent
      ? AppStrings.format(AppStrings.text($r('app.string.current_log_with_time'), 'Current log · {0}'), [timestamp])
      : AppStrings.format(AppStrings.text($r('app.string.startup_log_with_time'), 'Startup log · {0}'), [timestamp])
  }

  private formatLogTimestamp(value: number): string {
    if (value <= 0) {
      return AppStrings.text($r('app.string.unknown_time'), 'Unknown time')
    }
    const date = new Date(value)
    const year = date.getFullYear().toString().padStart(4, '0')
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    return `${year}-${month}-${day} ${hour}:${minute}`
  }

  private formatFileSize(sizeBytes: number): string {
    if (sizeBytes < 1024) {
      return `${Math.max(0, sizeBytes)} B`
    }
    if (sizeBytes < 1024 * 1024) {
      return `${Math.round(sizeBytes / 102.4) / 10} KB`
    }
    return `${Math.round(sizeBytes / 1024 / 102.4) / 10} MB`
  }
}
