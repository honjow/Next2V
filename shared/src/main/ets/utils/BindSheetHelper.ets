type SheetDetents = [(SheetSize | Length), (SheetSize | Length)?, (SheetSize | Length)?]

export function defaultSheetOptions(height: SheetSize, onDisappear: () => void): SheetOptions {
  const detents: SheetDetents = [SheetSize.MEDIUM, SheetSize.LARGE]
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

export function towFASheetOptions(height: SheetSize, onDisappear: () => void): SheetOptions {
  const detents: SheetDetents = [SheetSize.LARGE]
  return {
    height: height,
    preferType: SheetType.BOTTOM,
    detents: detents,
    showClose: false,
    blurStyle: BlurStyle.Thick,
    onDisappear: onDisappear,
    // keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE,
  }
}
