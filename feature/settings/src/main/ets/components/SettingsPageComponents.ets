import {
  ConciseListRow,
  ListDivider as SharedListDivider,
  SectionHeader as SharedSectionHeader,
  ThemeConstants
} from 'shared'
import { SymbolGlyphModifier } from '@kit.ArkUI'

@Component
export struct SettingsSectionHeader {
  @Prop title: string = ''

  build() {
    SharedSectionHeader({ title: this.title })
      .margin({ top: ThemeConstants.SPACE_MD })
  }
}

@Component
export struct SettingsDivider {
  build() {
    SharedListDivider()
  }
}

@Component
export struct SettingsToggleRow {
  @Prop title: string = ''
  @Prop checked: boolean = false
  @Prop isEnabled: boolean = true
  changeAction?: (value: boolean) => void

  build() {
    ConciseListRow({
      title: this.title,
      showChevron: false,
      hasSwitch: true,
      checked: this.checked,
      isEnabled: this.isEnabled,
      switchAction: (value: boolean) => {
        if (this.changeAction) {
          this.changeAction(value)
        }
      }
    })
  }
}

@Component
export struct SettingsDropdownRow {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop trailingText: string = ''
  openAction?: () => void

  build() {
    ConciseListRow({
      title: this.title,
      subtitle: this.subtitle,
      trailingText: this.trailingText,
      showChevron: false,
      trailingDropdown: true,
      action: () => {
        if (this.openAction) {
          this.openAction()
        }
      }
    })
  }
}

@Component
export struct SettingsCheckedMenuItem {
  @Prop label: string = ''
  @Prop selected: boolean = false
  selectAction?: () => void

  build() {
    MenuItem({
      content: this.label,
      symbolEndIcon: this.selected ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
    }).onClick(() => {
      if (this.selectAction) {
        this.selectAction()
      }
    })
  }
}
