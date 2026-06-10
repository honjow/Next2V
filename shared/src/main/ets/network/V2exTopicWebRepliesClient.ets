import { HttpClient } from './HttpClient'
import { V2exTopicRepliesParser } from '../parser/V2exTopicRepliesParser'
import { HtmlEntityUtils } from '../utils/HtmlEntityUtils'
import type { V2exReply } from './NetworkTypes'

export interface V2exTopicWebRepliesPage {
  replies: V2exReply[]
  page: number
  pageCount: number
  hasMore: boolean
  topicSupplementMarkdown?: string
}

export interface V2exTopicWebRepliesAllResult {
  replies: V2exReply[]
  pageCount: number
  topicSupplementMarkdown?: string
}

type CookieHtmlLoader = (path: string, cookie: string) => Promise<string>

export class V2exTopicWebRepliesClient {
  private http: HttpClient
  private cookieHtmlLoader: CookieHtmlLoader

  constructor(httpClient: HttpClient, cookieHtmlLoader: CookieHtmlLoader) {
    this.http = httpClient
    this.cookieHtmlLoader = cookieHtmlLoader
  }

  async getPage(
    topicId: number,
    page: number = 1,
    cacheBuster: number = Date.now(),
    cookie: string = '',
  ): Promise<V2exTopicWebRepliesPage> {
    if (topicId <= 0) {
      throw new Error('Invalid topic ID')
    }
    const safePage = Math.max(1, Math.floor(page))
    const path = `/t/${topicId}?p=${safePage}&_=${cacheBuster}`
    const html = cookie ? await this.cookieHtmlLoader(path, cookie) : await this.http.getText(path)
    const pageCount = Math.max(1, V2exTopicRepliesParser.extractPageCount(html))
    return {
      replies: V2exTopicWebRepliesClient.normalizeReplies(V2exTopicRepliesParser.parseReplies(html)),
      page: safePage,
      pageCount: pageCount,
      hasMore: safePage < pageCount,
      topicSupplementMarkdown: V2exTopicWebRepliesClient.extractTopicSupplementMarkdown(html),
    }
  }

  async getReplies(topicId: number, cookie: string = ''): Promise<V2exReply[]> {
    const result = await this.getAll(topicId, cookie)
    return result.replies
  }

  async getAll(
    topicId: number,
    cookie: string = '',
    onProgress?: (loaded: number, total: number) => void,
  ): Promise<V2exTopicWebRepliesAllResult> {
    const cacheBuster = Date.now()
    const firstPage = await this.getPage(topicId, 1, cacheBuster, cookie)
    const pageCount = firstPage.pageCount
    if (onProgress) {
      onProgress(1, pageCount)
    }
    if (pageCount <= 1) {
      return {
        replies: V2exTopicWebRepliesClient.normalizeReplies(firstPage.replies),
        pageCount: pageCount,
        topicSupplementMarkdown: firstPage.topicSupplementMarkdown,
      }
    }

    const pageResults: V2exTopicWebRepliesPage[] = new Array<V2exTopicWebRepliesPage>(pageCount)
    pageResults[0] = firstPage
    const remaining: number[] = []
    for (let p = 2; p <= pageCount; p++) {
      remaining.push(p)
    }

    let loaded = 1
    const promises = remaining.map((page: number): Promise<void> => {
      return this.getPage(topicId, page, cacheBuster, cookie).then(
        (snapshot: V2exTopicWebRepliesPage) => {
          pageResults[page - 1] = snapshot
          loaded++
          if (onProgress) {
            onProgress(loaded, pageCount)
          }
        },
      )
    })
    await Promise.all(promises)

    const seen = new Set<number>()
    const merged: V2exReply[] = []
    for (let i = 0; i < pageCount; i++) {
      const page = pageResults[i]
      if (!page) {
        continue
      }
      page.replies.forEach((reply: V2exReply) => {
        if (reply.id > 0 && !seen.has(reply.id)) {
          seen.add(reply.id)
          merged.push(reply)
        }
      })
    }
    return {
      replies: V2exTopicWebRepliesClient.normalizeReplies(merged),
      pageCount: pageCount,
      topicSupplementMarkdown: firstPage.topicSupplementMarkdown,
    }
  }

  private static extractTopicSupplementMarkdown(html: string): string {
    const source = html || ''
    const supplements: string[] = []
    const re =
      /<div[^>]*class=['"][^'"]*\bsubtle\b[^'"]*['"][^>]*>[\s\S]*?<span[^>]*class=['"][^'"]*\bfade\b[^'"]*['"][^>]*>([\s\S]*?)<\/span>[\s\S]*?<div[^>]*class=['"][^'"]*\btopic_content\b[^'"]*['"][^>]*>([\s\S]*?)<\/div>[\s\S]*?<\/div>/gi
    let match: RegExpExecArray | null = re.exec(source)
    while (match) {
      const title = V2exTopicWebRepliesClient.htmlToPlainText(match[1] || '').trim()
      const body = V2exTopicWebRepliesClient.htmlToPlainText(match[2] || '').trim()
      if (body.length > 0) {
        supplements.push(`## ${title || 'Supplement'}\n\n${body}`)
      }
      match = re.exec(source)
    }
    return supplements.join('\n\n')
  }

  private static htmlToPlainText(html: string): string {
    return HtmlEntityUtils.decode(
      (html || '')
        .replace(/<img[^>]+src=['"]([^'"]+)['"][^>]*\/?>/gi, '![]($1)')
        .replace(/<br\s*\/?>/gi, '\n')
        .replace(/<\/p>/gi, '\n\n')
        .replace(/<\/div>/gi, '\n')
        .replace(/<[^>]+>/g, '')
        .replace(/\r/g, '')
        .replace(/\n{3,}/g, '\n\n')
        .trim(),
    )
  }

  private static normalizeReplies(replies: V2exReply[]): V2exReply[] {
    return (replies || []).map((reply: V2exReply) => V2exTopicWebRepliesClient.normalizeReply(reply))
  }

  private static normalizeReply(reply: V2exReply): V2exReply {
    if (!reply) {
      return reply
    }
    reply.content = HtmlEntityUtils.decode(reply.content)
    reply.content_rendered = HtmlEntityUtils.decode(reply.content_rendered)
    if (reply.member) {
      reply.member.tagline = HtmlEntityUtils.decode(reply.member.tagline)
    }
    return reply
  }
}
