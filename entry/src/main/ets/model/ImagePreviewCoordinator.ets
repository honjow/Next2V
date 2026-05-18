export type ImagePreviewAction = 'save' | ''

export class ImagePreviewCoordinator {
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
      const value = bag[cleanKey] || bag[key] || bag[cleanKey.toUpperCase()] || bag[key.toUpperCase()] || ''
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
