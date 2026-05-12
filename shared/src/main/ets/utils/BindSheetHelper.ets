interface BindSheetOptions {
  height: SheetSize
  preferType: SheetType
  detents: [SheetSize, SheetSize]
  showClose: boolean
  blurStyle: BlurStyle
  onDisappear: () => void
  keyboardAvoidMode: SheetKeyboardAvoidMode
}

export function defaultSheetOptions(height: SheetSize, onDisappear: () => void): BindSheetOptions {
  const detents: [SheetSize, SheetSize] = [SheetSize.MEDIUM, SheetSize.LARGE]
  return {
    height: height,
    preferType: SheetType.BOTTOM,
    detents: detents,
    showClose: false,
    blurStyle: BlurStyle.Thick,
    onDisappear: onDisappear,
    keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE,
  }
}
