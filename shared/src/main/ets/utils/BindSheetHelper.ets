import { AppPrompt } from './AppPrompt'

type SheetDetents = [(SheetSize | Length), (SheetSize | Length)?, (SheetSize | Length)?]

export function defaultSheetOptions(height: SheetSize, onDisappear: () => void, detents?: SheetDetents): SheetOptions {
  const kDetents: SheetDetents = [SheetSize.MEDIUM, SheetSize.LARGE]
  return {
    height: height,
    detents: detents ?? kDetents,
    showClose: false,
    blurStyle: BlurStyle.Thick,
    onDisappear: onDisappear,
    keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE,
    systemMaterial: AppPrompt.surfaceSystemMaterial(),
  }
}

export function towFASheetOptions(height: SheetSize, onDisappear: () => void): SheetOptions {
  const detents: SheetDetents = [SheetSize.LARGE]
  return {
    height: height,
    detents: detents,
    showClose: false,
    blurStyle: BlurStyle.Thick,
    onDisappear: onDisappear,
    systemMaterial: AppPrompt.surfaceSystemMaterial(),
    // keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE,
  }
}
