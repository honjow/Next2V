import type { V2exNode } from '../network/NetworkTypes'

export interface NodeSearchMatch {
  node: V2exNode
  score: number
}

export class NodeSearchUtils {
  static sortByPopularity(nodes: V2exNode[]): V2exNode[] {
    return nodes.slice().sort((a: V2exNode, b: V2exNode) => {
      if (b.topics !== a.topics) {
        return b.topics - a.topics
      }
      return NodeSearchUtils.compareText(a.name, b.name)
    })
  }

  static filter(nodes: V2exNode[], keyword: string): V2exNode[] {
    const cleanKeyword = NodeSearchUtils.clean(keyword)
    if (!cleanKeyword) {
      return NodeSearchUtils.sortByPopularity(nodes)
    }
    return NodeSearchUtils.search(nodes, cleanKeyword).map((item: NodeSearchMatch) => item.node)
  }

  static search(nodes: V2exNode[], keyword: string): NodeSearchMatch[] {
    const cleanKeyword = NodeSearchUtils.clean(keyword)
    if (!cleanKeyword) {
      return []
    }
    const matches: NodeSearchMatch[] = []
    for (const node of nodes) {
      const score = NodeSearchUtils.scoreNode(node, cleanKeyword)
      if (score > 0) {
        matches.push({ node, score })
      }
    }
    return matches.sort((a: NodeSearchMatch, b: NodeSearchMatch) => {
      if (b.score !== a.score) {
        return b.score - a.score
      }
      if (b.node.topics !== a.node.topics) {
        return b.node.topics - a.node.topics
      }
      return NodeSearchUtils.compareText(a.node.name, b.node.name)
    })
  }

  static scoreNode(node: V2exNode, keyword: string): number {
    const q = NodeSearchUtils.clean(keyword)
    if (!q) {
      return 0
    }

    const name = NodeSearchUtils.clean(node.name)
    const title = NodeSearchUtils.clean(node.title)
    const alternative = NodeSearchUtils.clean(node.title_alternative)
    const header = NodeSearchUtils.clean(node.header || '')
    const fields: string[] = [name, title, alternative, header]
    const tokens = NodeSearchUtils.tokens(q)
    if (!NodeSearchUtils.allTokensMatch(fields, tokens)) {
      return 0
    }

    let score = 0
    score = Math.max(score, NodeSearchUtils.fieldScore(name, q, 1000, 820, 560))
    score = Math.max(score, NodeSearchUtils.fieldScore(title, q, 900, 740, 500))
    score = Math.max(score, NodeSearchUtils.fieldScore(alternative, q, 860, 700, 460))
    score = Math.max(score, NodeSearchUtils.fieldScore(header, q, 320, 260, 180))
    if (score <= 0) {
      if (tokens.length <= 1) {
        return 0
      }
      score = 220
    }

    if (tokens.length > 1) {
      score += tokens.length * 30
    }
    if (node.topics > 0) {
      score += Math.min(120, Math.floor(node.topics / 250))
    }
    return score
  }

  private static fieldScore(value: string, keyword: string, exact: number, prefix: number, contains: number): number {
    if (!value) {
      return 0
    }
    if (value === keyword) {
      return exact
    }
    if (value.startsWith(keyword)) {
      return prefix
    }
    if (value.includes(keyword)) {
      return contains
    }
    return 0
  }

  private static allTokensMatch(fields: string[], tokens: string[]): boolean {
    if (tokens.length <= 1) {
      return true
    }
    for (const token of tokens) {
      let matched = false
      for (const field of fields) {
        if (field.includes(token)) {
          matched = true
          break
        }
      }
      if (!matched) {
        return false
      }
    }
    return true
  }

  private static tokens(value: string): string[] {
    return value.split(' ').map((item: string) => item.trim()).filter((item: string) => item.length > 0)
  }

  private static clean(value: string): string {
    return (value || '').trim().toLowerCase().replace(/\s+/g, ' ')
  }

  private static compareText(left: string, right: string): number {
    const a = NodeSearchUtils.clean(left)
    const b = NodeSearchUtils.clean(right)
    if (a === b) {
      return 0
    }
    return a > b ? 1 : -1
  }
}
