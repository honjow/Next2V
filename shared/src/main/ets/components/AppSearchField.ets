import { ThemeConstants } from '../theme/ThemeConstants'

let appSearchFieldSeq: number = 0
@ComponentV2
export struct AppSearchField {
  // V2 two-way replacement for the former @Link text (see AppTextField for the pattern).
  @Param text: string = '';
  @Local fieldText: string = '';
  @Param placeholder: ResourceStr = '';
  // When true, the field requests focus on appear so the soft keyboard opens immediately (used by the
  // standalone Search page entered via the title-bar icon). Defaults off so existing inline fields are unchanged.
  @Param autoFocus: boolean = false;
  // When non-empty, render the Search component's built-in trailing action button with this label (the same
  // blue "搜索" + divider the system search uses). Tapping it fires onSubmit, so SOV2EX can be triggered
  // without reaching for the IME enter key. Empty = no button (default), unchanged for any other caller.
  @Param searchButtonText: string = '';
  @Event onTextChange?: (value: string) => void;
  @Event onSubmit?: (value: string) => void;
  // Unique id so getFocusController().requestFocus can target this specific Search instance.
  private fieldId: string = `appSearchField-${appSearchFieldSeq++}`;

  aboutToAppear(): void {
    this.fieldText = this.text
    if (this.autoFocus) {
      // Deferred a frame so the Search is mounted before requesting focus (mirrors ReplyComposerBar).
      setTimeout(() => {
        this.getUIContext().getFocusController().requestFocus(this.fieldId)
      }, 80)
    }
  }

  @Monitor('text')
  onExternalTextChange(): void {
    if (this.text !== this.fieldText) {
      this.fieldText = this.text
    }
  }

  build() {
    Search({ value: this.fieldText, placeholder: this.placeholder })
      .id(this.fieldId)
      .height(40)
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      // Built-in trailing search button (system style: blue label + divider). Empty label renders none.
      .searchButton(this.searchButtonText)
      .onChange((value: string) => {
        this.fieldText = value
        if (this.onTextChange) {
          this.onTextChange(value)
        }
      })
      .onSubmit((value: string) => {
        if (this.onSubmit) {
          this.onSubmit(value)
        }
      })
  }
}
