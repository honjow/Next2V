import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { NodeViewModel } from '../viewmodel/NodeViewModel'
import { AppStrings, DraftSettings, V2exNode, SecondaryListScaffold } from 'shared'
import {
  NodePickerEmptyState,
  NodePickerErrorState,
  NodePickerHeader,
  NodePickerLoadingState,
  NodePickerRow
} from '../components/NodePickerComponents'

@Component
export struct NodePickerPage {
  @Consume('ns') stack: NavPathStack

  @State vm: NodeViewModel = new NodeViewModel()

  @State private selectedNodeName: string = ''
  @State private isSaving: boolean = false
  @State private errorMessage: string = ''

  aboutToAppear(): void {
    this.loadSelectedNode()
    this.vm.loadAllNodes()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          NodePickerHeader({
            selectedNodeName: this.selectedNodeName,
            isSaving: this.isSaving,
            errorMessage: this.errorMessage,
            keyword: this.vm.keyword,
            clearAction: () => { this.clearSelectedNode() },
            keywordChangeAction: (value: string) => { this.vm.setNodeFilter(value) }
          })
        }

        if (this.vm.isLoading && this.vm.nodeDataSource.totalCount() === 0) {
          ListItem() {
            NodePickerLoadingState()
          }
        } else if (this.vm.errorMessage && this.vm.nodeDataSource.totalCount() === 0) {
          ListItem() {
            NodePickerErrorState({
              message: this.vm.errorMessage,
              retryAction: () => { this.vm.loadAllNodes() }
            })
          }
        } else if (this.vm.nodeDataSource.totalCount() === 0) {
          ListItem() {
            NodePickerEmptyState()
          }
        } else {
          LazyForEach(this.vm.nodeDataSource, (node: V2exNode) => {
            ListItem() {
              this.NodeRow(node)
            }
          }, (node: V2exNode) => node.id.toString())
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder NodeRow(node: V2exNode) {
    NodePickerRow({
      node: node,
      selectedNodeName: this.selectedNodeName,
      selectAction: () => {
        this.selectNode(node.name)
      }
    })
  }

  private loadSelectedNode(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadTopicDraft(context)
      .then((draft) => {
        this.selectedNodeName = draft?.nodeName || ''
      })
      .catch((_error: Error) => {
        this.selectedNodeName = ''
      })
  }

  private selectNode(nodeName: string): void {
    const clean = nodeName.trim()
    if (!clean || this.isSaving) {
      return
    }
    this.isSaving = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadTopicDraft(context)
      .then((draft) => {
        return DraftSettings.saveTopicDraft(context, clean, draft?.title || '', draft?.content || '')
      })
      .then(() => {
        this.selectedNodeName = clean
        promptAction.openToast({ message: AppStrings.format(AppStrings.text($r('app.string.node_selected_format'), 'Selected node: {0}'), [clean]) }).catch((_error: Error) => { })
        this.stack.pop()
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '保存失败'
      })
      .finally(() => {
        this.isSaving = false
      })
  }

  private clearSelectedNode(): void {
    if (this.isSaving) {
      return
    }
    this.isSaving = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadTopicDraft(context)
      .then((draft) => {
        if (!draft) {
          return DraftSettings.saveTopicDraft(context, '', '', '')
        }
        return DraftSettings.saveTopicDraft(context, '', draft.title || '', draft.content || '')
      })
      .then(() => {
        this.selectedNodeName = ''
        promptAction.openToast({ message: $r('app.string.node_cleared') }).catch((_error: Error) => { })
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '清空失败'
      })
      .finally(() => {
        this.isSaving = false
      })
  }
}
