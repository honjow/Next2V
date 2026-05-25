import { display } from '@kit.ArkUI'

/**
 * Foldable screen state utility
 * Determines foldable screen fold state and display mode
 */
export class FoldScreenUtil {
  private static instance: FoldScreenUtil
  private isFoldedAndOuterScreen: boolean = false
  private callbacks: Array<(value: boolean) => void> = []
  private isInitialized: boolean = false

  private constructor() {}

  /**
   * Get singleton instance
   */
  static getInstance(): FoldScreenUtil {
    if (!FoldScreenUtil.instance) {
      FoldScreenUtil.instance = new FoldScreenUtil()
    }
    return FoldScreenUtil.instance
  }

  /**
   * Initialize listeners
   * Call once at app startup
   */
  init(): void {
    if (this.isInitialized) {
      return
    }
    
    this.isInitialized = true
    
    // Initialize state
    this.updateState()
    
    // Listen for fold state changes
    display.on('foldStatusChange', () => {
      this.updateState()
    })
    
    // Listen for display mode changes (inner/outer screen switch)
    display.on('foldDisplayModeChange', () => {
      this.updateState()
    })
  }

  /**
   * Update foldable screen state
   */
  private updateState(): void {
    let newState = false
    
    try {
      const isFoldable = display.isFoldable()
      
      if (isFoldable) {
        const foldStatus = display.getFoldStatus()
        const foldDisplayMode = display.getFoldDisplayMode()
        
        // Only return true when folded + outer screen display
        newState = 
          foldStatus === display.FoldStatus.FOLD_STATUS_FOLDED &&
          foldDisplayMode === display.FoldDisplayMode.FOLD_DISPLAY_MODE_MAIN
      }
    } catch (error) {
      console.error('FoldScreenUtil updateState error:', error)
      newState = false
    }
    
    // Notify all listeners on state change
    if (this.isFoldedAndOuterScreen !== newState) {
      this.isFoldedAndOuterScreen = newState
      this.notifyCallbacks()
    }
  }

  /**
   * Notify all callbacks
   */
  private notifyCallbacks(): void {
    this.callbacks.forEach(callback => {
      try {
        callback(this.isFoldedAndOuterScreen)
      } catch (error) {
        console.error('FoldScreenUtil callback error:', error)
      }
    })
  }

  /**
   * Check if device is foldable
   */
  isFoldable(): boolean {
    try {
      return display.isFoldable()
    } catch (error) {
      console.error('FoldScreenUtil isFoldable error:', error)
      return false
    }
  }

  /**
   * Get current fold state
   */
  getFoldStatus(): display.FoldStatus {
    try {
      return display.getFoldStatus()
    } catch (error) {
      console.error('FoldScreenUtil getFoldStatus error:', error)
      return display.FoldStatus.FOLD_STATUS_UNKNOWN
    }
  }

  /**
   * Get current display mode
   */
  getFoldDisplayMode(): display.FoldDisplayMode {
    try {
      return display.getFoldDisplayMode()
    } catch (error) {
      console.error('FoldScreenUtil getFoldDisplayMode error:', error)
      return display.FoldDisplayMode.FOLD_DISPLAY_MODE_UNKNOWN
    }
  }

  /**
   * Check if folded and using outer screen
   * Core method, controls hideTitleArea
   */
  isFoldedAndUseOuterScreen(): boolean {
    return this.isFoldedAndOuterScreen
  }

  /**
   * Register state change callback
   * @param callback Callback when state changes
   */
  registerCallback(callback: (value: boolean) => void): void {
    this.callbacks.push(callback)
  }

  /**
   * Unregister callback
   * @param callback Callback to unregister
   */
  unregisterCallback(callback: (value: boolean) => void): void {
    const index = this.callbacks.indexOf(callback)
    if (index > -1) {
      this.callbacks.splice(index, 1)
    }
  }

  /**
   * Clear all callbacks
   */
  clearCallbacks(): void {
    this.callbacks = []
  }

  /**
   * Get fold state description (for debugging)
   */
  getStatusDescription(): string {
    const isFoldable = this.isFoldable()
    const foldStatus = this.getFoldStatus()
    const displayMode = this.getFoldDisplayMode()
    
    let statusStr = ''
    switch (foldStatus) {
      case display.FoldStatus.FOLD_STATUS_UNKNOWN:
        statusStr = 'unknown'
        break
      case display.FoldStatus.FOLD_STATUS_EXPANDED:
        statusStr = 'expanded'
        break
      case display.FoldStatus.FOLD_STATUS_FOLDED:
        statusStr = 'folded'
        break
      case display.FoldStatus.FOLD_STATUS_HALF_FOLDED:
        statusStr = 'half-folded'
        break
      default:
        statusStr = 'other'
    }
    
    let modeStr = ''
    switch (displayMode) {
      case display.FoldDisplayMode.FOLD_DISPLAY_MODE_UNKNOWN:
        modeStr = 'unknown'
        break
      case display.FoldDisplayMode.FOLD_DISPLAY_MODE_FULL:
        modeStr = 'full-screen'
        break
      case display.FoldDisplayMode.FOLD_DISPLAY_MODE_MAIN:
        modeStr = 'main screen (outer)'
        break
      case display.FoldDisplayMode.FOLD_DISPLAY_MODE_SUB:
        modeStr = 'sub screen'
        break
      case display.FoldDisplayMode.FOLD_DISPLAY_MODE_COORDINATION:
        modeStr = 'collaboration'
        break
      default:
        modeStr = 'other'
    }
    
    return `foldable:${isFoldable}, status:${statusStr}, mode:${modeStr}, hideTitleBar:${this.isFoldedAndOuterScreen}`
  }
}
