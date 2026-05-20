import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { promptAction } from '@kit.ArkUI'
import { systemShare } from '@kit.ShareKit'
import {
  ConciseListRow,
  DiagnosticLogger,
  DiagnosticsLogFileSink,
  DiagnosticsSettings,
  GroupedListSection,
  SecondaryListScaffold,
  StorageKeys,
} from 'shared'
import type { DiagnosticsLogFileInfo } from 'shared'
import {
  SettingsDivider,
  SettingsSectionHeader,
  SettingsToggleRow,
} from '../components/SettingsPageComponents'
import { SettingsSaveCoordinator } from '../model/SettingsSaveCoordinator'

@Component
export struct DiagnosticsLogPage {
  @StorageLink(StorageKeys.DIAGNOSTICS_ENABLED) diagnosticsEnabled: boolean = true
  @State private logCount: number = 0
  @State private logFiles: DiagnosticsLogFileInfo[] = []
  private diagnosticsShareController?: systemShare.ShareController

  aboutToAppear(): void {
    this.refreshLogState()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          SettingsSectionHeader({ title: '诊断' })
        }

        ListItem() {
          this.DiagnosticsToggleSection()
        }

        ListItem() {
          SettingsSectionHeader({ title: '日志' })
        }

        ListItem() {
          this.DiagnosticsActionsSection()
        }

        ListItem() {
          SettingsSectionHeader({ title: '日志文件' })
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
        title: '诊断日志',
        checked: this.diagnosticsEnabled,
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
        title: `本次启动最近 ${this.logCount} 条`,
        subtitle: this.logFiles.length > 0 ? `已保留 ${this.logFiles.length} 个本机日志文件` : '暂无可分享的本机日志文件',
        showChevron: false,
        action: () => {
          this.refreshLogState()
        },
      })

      SettingsDivider()

      ConciseListRow({
        title: '清空本次启动记录',
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
          title: '暂无日志文件',
          subtitle: '重新打开应用后会保留最近启动日志',
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
      subtitle: `${this.formatFileSize(file.sizeBytes)} · 点按分享`,
      showChevron: false,
      action: () => {
        this.handleShareLogFileClick(file)
      },
    })
  }

  private updateDiagnosticsEnabled(enabled: boolean): void {
    this.diagnosticsEnabled = enabled
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
          this.copyDiagnosticsTextWithToast('分享文件不可用，已复制，可手动粘贴', '分享失败', DiagnosticsLogFileSink.readLogFileText(file.fileName))
        })
    } catch (_error) {
      DiagnosticLogger.warn('diagnostics', 'diagnostics_share_show_error', {
        source: 'diagnostics_log_page',
        fileName: file.fileName,
        phase: 'share_file',
        errorName: 'Error',
        errorMessage: 'share_failed',
      })
      this.copyDiagnosticsTextWithToast('分享文件不可用，已复制，可手动粘贴', '分享失败', DiagnosticsLogFileSink.readLogFileText(file.fileName))
    }
  }

  private copyDiagnosticsTextWithToast(successMessage: string, failureMessage: string, textOverride: string = ''): void {
    try {
      const text = textOverride || DiagnosticsSettings.exportText() || '暂无诊断日志'
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      pasteboard.getSystemPasteboard().setDataSync(data)
      DiagnosticLogger.info('diagnostics', 'diagnostics_log_copy_success', { textLength: text.length })
      promptAction.openToast({ message: successMessage }).catch((_error: Error) => {})
    } catch (error) {
      DiagnosticLogger.warn('diagnostics', 'diagnostics_log_copy_error', {}, error as Error)
      promptAction.openToast({ message: failureMessage }).catch((_toastError: Error) => {})
    }
  }

  private clearDiagnosticsText(): void {
    DiagnosticsSettings.clearLogs()
    this.refreshLogState()
    promptAction.openToast({ message: '本次启动记录已清空' }).catch((_error: Error) => {})
  }

  private logFileTitle(file: DiagnosticsLogFileInfo): string {
    const prefix = file.isCurrent ? '当前日志' : '启动日志'
    return `${prefix} · ${this.formatLogTimestamp(file.createdAtMs)}`
  }

  private formatLogTimestamp(value: number): string {
    if (value <= 0) {
      return '时间未知'
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
