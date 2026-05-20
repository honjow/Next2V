import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { promptAction } from '@kit.ArkUI'
import { systemShare } from '@kit.ShareKit'
import {
  ConciseListRow,
  DiagnosticLogger,
  DiagnosticsFileExport,
  DiagnosticsSettings,
  GroupedListSection,
  SecondaryListScaffold,
  StorageKeys,
} from 'shared'
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
  private diagnosticsShareController?: systemShare.ShareController

  aboutToAppear(): void {
    this.refreshLogCount()
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
        title: `最近 ${this.logCount} 条`,
        subtitle: '重启后清空',
        showChevron: false,
        action: () => {
          this.refreshLogCount()
        },
      })

      SettingsDivider()

      ConciseListRow({
        title: '分享日志文件',
        showChevron: false,
        action: () => {
          this.handleShareRowClick()
        },
      })

      SettingsDivider()

      ConciseListRow({
        title: '复制日志',
        showChevron: false,
        action: () => {
          this.copyDiagnosticsText()
        },
      })

      SettingsDivider()

      ConciseListRow({
        title: '清空日志',
        destructive: true,
        showChevron: false,
        action: () => {
          this.clearDiagnosticsText()
        },
      })
    }
  }

  private updateDiagnosticsEnabled(enabled: boolean): void {
    this.diagnosticsEnabled = enabled
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveDiagnostics(context, enabled)
  }

  private refreshLogCount(): void {
    this.logCount = DiagnosticsSettings.count()
  }

  private copyDiagnosticsText(): void {
    this.copyDiagnosticsTextWithToast('诊断日志已复制', '复制失败')
  }

  private handleShareRowClick(): void {
    DiagnosticLogger.info('diagnostics', 'diagnostics_share_tap', { source: 'diagnostics_log_page' })
    setTimeout(() => {
      this.shareDiagnosticsText()
    }, 0)
  }

  private shareDiagnosticsText(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    try {
      DiagnosticLogger.info('diagnostics', 'diagnostics_share_export_start', { source: 'diagnostics_log_page' })
      const exportFile = DiagnosticsFileExport.create(context)
      DiagnosticLogger.info('diagnostics', 'diagnostics_share_export_success', {
        source: 'diagnostics_log_page',
        fileName: exportFile.fileName,
        directoryKind: exportFile.directoryKind,
        textLength: exportFile.text.length,
      })
      const data = new systemShare.SharedData({
        utd: utd.UniformDataType.FILE,
        title: 'Next2V 诊断日志',
        label: exportFile.fileName,
        description: '已脱敏的本机诊断日志文件',
        uri: exportFile.uri,
      })
      DiagnosticLogger.info('diagnostics', 'diagnostics_share_show_start', {
        source: 'diagnostics_log_page',
        fileName: exportFile.fileName,
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
            fileName: exportFile.fileName,
          })
        })
        .catch((error: Error) => {
          this.diagnosticsShareController = undefined
          DiagnosticLogger.warn('diagnostics', 'diagnostics_share_show_error', {
            source: 'diagnostics_log_page',
            fileName: exportFile.fileName,
          }, error)
          this.copyDiagnosticsTextWithToast('分享文件不可用，已复制，可手动粘贴', '分享失败', exportFile.text)
        })
    } catch (_error) {
      DiagnosticLogger.warn('diagnostics', 'diagnostics_share_export_error', {
        source: 'diagnostics_log_page',
        phase: 'share_export',
        directoryKind: 'unknown',
        errorName: 'Error',
        errorMessage: 'export_failed',
      })
      this.copyDiagnosticsTextWithToast('分享文件不可用，已复制，可手动粘贴', '分享失败')
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
    this.refreshLogCount()
    promptAction.openToast({ message: '诊断日志已清空' }).catch((_error: Error) => {})
  }
}
