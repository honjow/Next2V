import mediaquery from '@ohos.mediaquery'

const BP_SM_MAX: number = 520
const BP_MD_MAX: number = 840

export type Breakpoint = 'sm' | 'md' | 'lg'

export class BreakpointSystem {
  private smListener?: mediaquery.MediaQueryListener
  private mdListener?: mediaquery.MediaQueryListener
  private lgListener?: mediaquery.MediaQueryListener
  private currentBreakpoint: Breakpoint = 'sm'

  register(): void {
    this.smListener = mediaquery.matchMediaSync(`(320vp<=width<${BP_SM_MAX}vp)`)
    this.smListener.on('change', (r: mediaquery.MediaQueryResult) => {
      if (r.matches) this.update('sm')
    })
    this.mdListener = mediaquery.matchMediaSync(`(${BP_SM_MAX}vp<=width<${BP_MD_MAX}vp)`)
    this.mdListener.on('change', (r: mediaquery.MediaQueryResult) => {
      if (r.matches) this.update('md')
    })
    this.lgListener = mediaquery.matchMediaSync(`(${BP_MD_MAX}vp<=width)`)
    this.lgListener.on('change', (r: mediaquery.MediaQueryResult) => {
      if (r.matches) this.update('lg')
    })

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
