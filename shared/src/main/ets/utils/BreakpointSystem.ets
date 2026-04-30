import mediaquery from '@ohos.mediaquery'

export type Breakpoint = 'sm' | 'md' | 'lg'

export class BreakpointSystem {
  private smListener?: mediaquery.MediaQueryListener
  private mdListener?: mediaquery.MediaQueryListener
  private lgListener?: mediaquery.MediaQueryListener
  private currentBreakpoint: Breakpoint = 'sm'

  register(): void {
    this.smListener = mediaquery.matchMediaSync('(320vp<=width<520vp)')
    this.smListener.on('change', (r: mediaquery.MediaQueryResult) => {
      if (r.matches) this.update('sm')
    })
    this.mdListener = mediaquery.matchMediaSync('(520vp<=width<840vp)')
    this.mdListener.on('change', (r: mediaquery.MediaQueryResult) => {
      if (r.matches) this.update('md')
    })
    this.lgListener = mediaquery.matchMediaSync('(840vp<=width)')
    this.lgListener.on('change', (r: mediaquery.MediaQueryResult) => {
      if (r.matches) this.update('lg')
    })

    // initial detection
    if (this.lgListener!.matches) this.update('lg')
    else if (this.mdListener!.matches) this.update('md')
    else this.update('sm')
  }

  unregister(): void {
    this.smListener?.off('change')
    this.mdListener?.off('change')
    this.lgListener?.off('change')
  }

  private update(bp: Breakpoint): void {
    if (this.currentBreakpoint !== bp) {
      this.currentBreakpoint = bp
      AppStorage.Set<string>('currentBreakpoint', bp)
    }
  }
}
