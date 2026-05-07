export type V2exRouteKind = 'topic' | 'member' | 'node'

export interface V2exRoute {
  kind: V2exRouteKind
  topicId?: number
  targetFloor?: number
  username?: string
  nodeName?: string
}

export class V2exUrlRouter {
  static parse(rawUrl: string): V2exRoute | null {
    const path = V2exUrlRouter.pathFromUrl(rawUrl)
    if (!path) {
      return null
    }

    const topicMatch = path.match(/^\/t\/(\d+)(?:\/[^#?]*)?(?:\?[^#]*)?(?:#(?:reply|r_?)?(\d+)|#(\d+))?$/i)
    if (topicMatch && topicMatch[1]) {
      const topicId = Number.parseInt(topicMatch[1])
      if (topicId > 0) {
        const floor = Number.parseInt(topicMatch[2] || topicMatch[3] || '0')
        return {
          kind: 'topic',
          topicId: topicId,
          targetFloor: Number.isFinite(floor) && floor > 0 ? floor : 0
        }
      }
    }

    const memberMatch = path.match(/^\/member\/([0-9A-Za-z_]+)\/?$/i)
    if (memberMatch && memberMatch[1]) {
      return { kind: 'member', username: memberMatch[1] }
    }

    const nodeMatch = path.match(/^\/go\/([0-9A-Za-z_-]+)\/?$/i)
    if (nodeMatch && nodeMatch[1]) {
      return { kind: 'node', nodeName: nodeMatch[1] }
    }

    return null
  }

  static pathFromUrl(rawUrl: string): string {
    const clean = (rawUrl || '').trim()
    if (!clean) {
      return ''
    }
    if (clean.startsWith('/')) {
      return clean
    }
    const match = clean.match(/^https?:\/\/(?:www\.)?v2ex\.(?:com|co)(\/[^]*)?$/i)
    if (!match) {
      return ''
    }
    return match[1] || '/'
  }
}
