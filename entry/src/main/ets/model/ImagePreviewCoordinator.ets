export type ImagePreviewAction = 'save' | ''

export class ImagePreviewCoordinator {
  // Zoom factor a double-tap jumps to (from fit). Kept below the clampScale ceiling (4) so a double-tapped
  // image can still be pinched larger.
  static readonly DOUBLE_TAP_SCALE: number = 2.5

  static clampScale(value: number): number {
    if (!Number.isFinite(value)) {
      return 1
    }
    if (value < 1) {
      return 1
    }
    if (value > 4) {
      return 4
    }
    return value
  }

  static imageWidth(viewportWidth: number, scaleValue: number): number | string {
    if (viewportWidth <= 0) {
      return '100%'
    }
    return viewportWidth * scaleValue
  }

  // Double-tap toggles: zoomed (>~fit) -> back to fit; at fit -> DOUBLE_TAP_SCALE.
  static doubleTapTarget(current: number): number {
    return current > 1.01 ? 1 : ImagePreviewCoordinator.DOUBLE_TAP_SCALE
  }

  // ImageFit.Contain letterboxes the bitmap inside the viewport-sized element: the DRAWN content size is the
  // intrinsic size times this fit-factor (min of the per-axis ratios). All pan/clamp math must use the drawn
  // (fitted) size, NOT the raw intrinsic size, or the bounds are off by the fit-factor.
  static fitScale(
    viewportW: number,
    viewportH: number,
    intrinsicW: number,
    intrinsicH: number,
  ): number {
    if (viewportW <= 0 || viewportH <= 0 || intrinsicW <= 0 || intrinsicH <= 0) {
      return 1
    }
    const f: number = Math.min(viewportW / intrinsicW, viewportH / intrinsicH)
    return f > 0 ? f : 1
  }

  // Half of how far the scaled image overflows the viewport on one axis = the max translate before a black
  // gap would show. 0 when the scaled image still fits (no pan, stays centered). Center-pivot transform, so
  // the overflow splits symmetrically to each side.
  static maxOffset(viewport: number, displaySize: number, scale: number): number {
    const scaled: number = displaySize * scale
    const over: number = scaled - viewport
    return over > 0 ? over / 2 : 0
  }

  static clampOffset(value: number, viewport: number, displaySize: number, scale: number): number {
    const m: number = ImagePreviewCoordinator.maxOffset(viewport, displaySize, scale)
    if (value > m) {
      return m
    }
    if (value < -m) {
      return -m
    }
    return value
  }

  static actionFromCommand(command: string): ImagePreviewAction {
    const raw = (command || '').trim()
    if (!raw) {
      return ''
    }
    const parts = raw.split(':')
    const action = parts.length > 0 ? parts[parts.length - 1] : ''
    return action === 'save' ? 'save' : ''
  }

  static extractHeaderValue(headers: Object, key: string): string {
    const cleanKey = (key || '').trim().toLowerCase()
    if (!cleanKey) {
      return ''
    }
    try {
      const bag = headers as Record<string, Object>
      const value =
        bag[cleanKey] || bag[key] || bag[cleanKey.toUpperCase()] || bag[key.toUpperCase()] || ''
      if (typeof value === 'string') {
        return value
      }
      if (Array.isArray(value)) {
        const items = value.filter((v: Object) => typeof v === 'string') as string[]
        return items.length > 0 ? items[0] : ''
      }
      return ''
    } catch (_error) {
      return ''
    }
  }
}
