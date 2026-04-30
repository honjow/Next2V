export interface BreakPointOptions<T> {
  sm?: T
  md?: T
  lg?: T
}

export class BreakPointType<T> {
  private options: Record<string, T | undefined>

  constructor(options: BreakPointOptions<T>) {
    this.options = options as Record<string, T | undefined>
  }

  getValue(current: string): T | undefined {
    return this.options[current]
  }
}
