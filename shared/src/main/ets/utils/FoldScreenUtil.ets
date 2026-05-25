import { display } from '@kit.ArkUI'

/**
 * 折叠屏状态工具类
 * 用于判断折叠屏的折叠状态和显示模式
 */
export class FoldScreenUtil {
  private static instance: FoldScreenUtil
  private isFoldedAndOuterScreen: boolean = false
  private callbacks: Array<(value: boolean) => void> = []
  private isInitialized: boolean = false

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): FoldScreenUtil {
    if (!FoldScreenUtil.instance) {
      FoldScreenUtil.instance = new FoldScreenUtil()
    }
    return FoldScreenUtil.instance
  }

  /**
   * 初始化监听器
   * 建议在应用启动时调用一次
   */
  init(): void {
    if (this.isInitialized) {
      return
    }
    
    this.isInitialized = true
    
    // 初始化状态
    this.updateState()
    
    // 监听折叠状态变化
    display.on('foldStatusChange', () => {
      this.updateState()
    })
    
    // 监听显示模式变化（内屏/外屏切换）
    display.on('foldDisplayModeChange', () => {
      this.updateState()
    })
  }

  /**
   * 更新折叠屏状态
   */
  private updateState(): void {
    let newState = false
    
    try {
      const isFoldable = display.isFoldable()
      
      if (isFoldable) {
        const foldStatus = display.getFoldStatus()
        const foldDisplayMode = display.getFoldDisplayMode()
        
        // 只有在折叠状态 + 外屏显示时，才返回 true
        newState = 
          foldStatus === display.FoldStatus.FOLD_STATUS_FOLDED &&
          foldDisplayMode === display.FoldDisplayMode.FOLD_DISPLAY_MODE_MAIN
      }
    } catch (error) {
      console.error('FoldScreenUtil updateState error:', error)
      newState = false
    }
    
    // 状态变化时通知所有监听者
    if (this.isFoldedAndOuterScreen !== newState) {
      this.isFoldedAndOuterScreen = newState
      this.notifyCallbacks()
    }
  }

  /**
   * 通知所有回调
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
   * 判断是否为折叠屏设备
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
   * 获取当前折叠状态
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
   * 获取当前显示模式
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
   * 判断是否处于折叠状态且使用外屏
   * 这是核心方法，用于控制 hideTitleArea
   */
  isFoldedAndUseOuterScreen(): boolean {
    return this.isFoldedAndOuterScreen
  }

  /**
   * 注册状态变化回调
   * @param callback 状态变化时的回调函数
   */
  registerCallback(callback: (value: boolean) => void): void {
    this.callbacks.push(callback)
  }

  /**
   * 取消注册回调
   * @param callback 要取消的回调函数
   */
  unregisterCallback(callback: (value: boolean) => void): void {
    const index = this.callbacks.indexOf(callback)
    if (index > -1) {
      this.callbacks.splice(index, 1)
    }
  }

  /**
   * 清除所有回调
   */
  clearCallbacks(): void {
    this.callbacks = []
  }

  /**
   * 获取折叠状态描述（用于调试）
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
