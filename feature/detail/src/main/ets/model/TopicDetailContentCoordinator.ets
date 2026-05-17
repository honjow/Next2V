import type { V2exTopic } from 'shared'

export interface TopicSupplementBlock {
  key: string
  meta: string
  bodyBlocks: string[]
}

export class TopicDetailContentCoordinator {
  static topicBodyBlocks(topic: V2exTopic | null): string[] {
    const source = TopicDetailContentCoordinator.topicBodySource(topic)
    if (((topic?.content_rendered || '').trim()).length > 0) {
      return [source]
    }
    return TopicDetailContentCoordinator.markdownBlocks(source)
  }

  static topicSupplementBlocks(source: string): TopicSupplementBlock[] {
    return TopicDetailContentCoordinator.supplementBlocks(source).map(
      (block: string, index: number): TopicSupplementBlock => {
        const body = TopicDetailContentCoordinator.supplementBody(block)
        return {
          key: `${index}-${block.length}-${block.slice(0, 16)}`,
          meta: TopicDetailContentCoordinator.supplementMeta(block),
          bodyBlocks: TopicDetailContentCoordinator.markdownBlocks(body),
        }
      },
    )
  }

  private static topicBodySource(topic: V2exTopic | null): string {
    const rendered = (topic?.content_rendered || '').trim()
    if (rendered.length > 0) {
      return topic?.content_rendered || ''
    }
    return topic?.content || ''
  }

  private static markdownBlocks(source: string): string[] {
    const normalized = (source || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n')
    const lines = normalized.split('\n')
    const blocks: string[] = []
    let buffer: string[] = []
    let tableBuffer: string[] = []
    let inTable = false
    const flushBuffer = (): void => {
      const text = buffer.join('\n').trim()
      if (text.length > 0) {
        blocks.push(text)
      }
      buffer = []
    }
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const trimmed = line.trim()
      if (inTable) {
        tableBuffer.push(line)
        if (/<\/table>/i.test(line)) {
          const table = tableBuffer.join('\n').trim()
          if (table.length > 0) {
            blocks.push(table)
          }
          tableBuffer = []
          inTable = false
        }
        continue
      }
      if (/<table\b/i.test(line)) {
        flushBuffer()
        tableBuffer = [line]
        inTable = !/<\/table>/i.test(line)
        if (!inTable) {
          blocks.push(tableBuffer.join('\n').trim())
          tableBuffer = []
        }
        continue
      }
      if (/^#{1,6}\s+/.test(trimmed)) {
        flushBuffer()
        blocks.push(trimmed)
        continue
      }
      if (trimmed.length === 0) {
        flushBuffer()
        continue
      }
      buffer.push(line)
    }
    flushBuffer()
    const trailingTable = tableBuffer.join('\n').trim()
    if (trailingTable.length > 0) {
      blocks.push(trailingTable)
    }
    return blocks
  }

  private static supplementBlocks(source: string): string[] {
    const normalized = (source || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim()
    if (normalized.length === 0) {
      return []
    }
    const lines = normalized.split('\n')
    const blocks: string[] = []
    let current: string[] = []
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      if (/^##\s+/.test(line.trim()) && current.length > 0) {
        blocks.push(current.join('\n').trim())
        current = []
      }
      current.push(line)
    }
    const last = current.join('\n').trim()
    if (last.length > 0) {
      blocks.push(last)
    }
    return blocks
  }

  private static supplementMeta(block: string): string {
    const first = ((block || '').split('\n')[0] || '').trim()
    return first.replace(/^##\s+/, '').trim()
  }

  private static supplementBody(block: string): string {
    const lines = (block || '').split('\n')
    if (lines.length <= 1) {
      return ''
    }
    return lines.slice(1).join('\n').trim()
  }
}
