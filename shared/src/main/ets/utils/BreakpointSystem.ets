import { mediaquery } from '@kit.ArkUI'

const BP_SM_MAX: number = 520
const BP_MD_MAX: number = 840

export type Breakpoint = 'sm' | 'md' | 'lg'

export class BreakpointSystem {
  private smListener?: mediaquery.MediaQueryListener
  private mdListener?: mediaquery.MediaQueryListener
  private lgListener?: mediaquery.MediaQueryListener
  private currentBreakpoint: Breakpoint = 'sm'

  register(uiContext: UIContext): void {
    const query = uiContext.getMediaQuery()
    this.smListener = query.matchMediaSync(`(320vp<=width<${BP_SM_MAX}vp)`)
    this.smListener.on('change', (r: mediaquery.MediaQueryResult) => {
      if (r.matches) this.update('sm')
    })
    this.mdListener = query.matchMediaSync(`(${BP_SM_MAX}vp<=width<${BP_MD_MAX}vp)`)
    this.mdListener.on('change', (r: mediaquery.MediaQueryResult) => {
      if (r.matches) this.update('md')
    })
    this.lgListener = query.matchMediaSync(`(${BP_MD_MAX}vp<=width)`)
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

  // Tracks the active breakpoint purely for the change-guard below. The former AppStorage dual-write
  // of a 'currentBreakpoint' key was removed: the State Management V2 migration retired its
  // @StorageProp('currentBreakpoint') consumers, leaving the key with no reader anywhere in the repo,
  // so the publish was dead. Layout consumers derive breakpoints from UIContext media queries directly.
  private update(bp: Breakpoint): void {
    if (this.currentBreakpoint !== bp) {
      this.currentBreakpoint = bp
    }
  }
}
