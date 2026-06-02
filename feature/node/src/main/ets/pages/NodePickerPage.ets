import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { NodeIndexViewModel } from '../viewmodel/NodeIndexViewModel'
import { AppStrings, connectNavStack, connectNodePickAction, DraftSettings, V2exNode, SecondaryListScaffold, translateApiError } from 'shared'
import {
  NodePickerEmptyState,
  NodePickerErrorState,
  NodePickerHeader,
  NodePickerLoadingState,
  NodePickerRow
} from '../components/NodePickerComponents'

@ComponentV2
export struct NodePickerPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); used purely
  // as a method target (pushPathByName / pop), so no V2 reactivity is needed on it.
  private stack: NavPathStack = connectNavStack().stack

  @Local vm: NodeIndexViewModel = new NodeIndexViewModel()

  @Local private selectedNodeName: string = ''
  @Local private isSaving: boolean = false
  @Local private errorMessage: string = ''

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
        this.selectNode(node.name, node.title)
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

  private selectNode(nodeName: string, nodeTitle: string): void {
    const clean = nodeName.trim()
    if (!clean || this.isSaving) {
      return
    }
    this.isSaving = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DraftSettings.loadTopicDraft(context)
      .then((draft) => {
        return DraftSettings.saveTopicDraft(context, clean, draft?.title || '', draft?.content || '', (nodeTitle || '').trim())
      })
      .then(() => {
        this.selectedNodeName = clean
        // Publish to the node-pick command bus so the already-mounted TopicEditorPage fills its node
        // field immediately on pop (it can't re-read the draft from aboutToAppear). title is for
        // display only; name is the submit value.
        const bus = connectNodePickAction()
        bus.name = clean
        bus.title = (nodeTitle || '').trim()
        bus.command = `${Date.now()}`
        promptAction.openToast({ message: AppStrings.format(AppStrings.text($r('app.string.node_selected_format'), 'Selected node: {0}'), [clean]) }).catch((_error: Error) => { })
        this.stack.pop()
      })
      .catch((error: Error) => {
        this.errorMessage = translateApiError(error)
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
        this.errorMessage = translateApiError(error)
      })
      .finally(() => {
        this.isSaving = false
      })
  }
}
