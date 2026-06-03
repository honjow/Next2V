#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'

const parserSource = readFileSync('shared/src/main/ets/parser/V2exNodeParser.ets', 'utf8')

function stripInterfaceBlocks(source) {
  return source.replace(/export interface [^{]+\{[\s\S]*?\n\}/g, '')
}

function runnableParserClass(source) {
  let code = stripInterfaceBlocks(source)
    .replace(/^import[^\n]*\n/gm, '')
    .replace(/export class V2exNodeParser/, 'class V2exNodeParser')
    .replace(/private static /g, 'static ')
    .replace(/: V2exNodeTopicsPageSnapshot/g, '')
    .replace(/: V2exNodeNavigationSection\[\]/g, '')
    .replace(/: V2exNodeNavigationSection \| null/g, '')
    .replace(/: V2exFavoriteNode\[\]/g, '')
    .replace(/: V2exFavoriteNode/g, '')
    .replace(/: RegExpExecArray \| null/g, '')
    .replace(/: Set<string>/g, '')
    .replace(/: string\[\]/g, '')
    .replace(/: string/g, '')
    .replace(/: number/g, '')
    .replace(/: boolean/g, '')
    .replace(/\.map\(\(node\)\)/g, '.map((node)')
  code = code.replace(/\n\s*static parseNodeTopicsPage[\s\S]*?\n  \}/, '\n')
  return `${code}\nglobalThis.V2exNodeParser = V2exNodeParser;`
}

const structuredBodyStart = parserSource.indexOf('static extractStructuredNodeNavigationSections')
assert.notEqual(structuredBodyStart, -1, 'structured node navigation parser must exist')
const structuredBody = parserSource.slice(structuredBodyStart, parserSource.indexOf('private static normalizeNavigationSectionTitle', structuredBodyStart))
assert.equal(structuredBody.includes("html.indexOf('节点导航') < 0"), false, 'live /?tab=nodes no longer contains the legacy 节点导航 marker')

const sandbox = { globalThis: {} }
vm.runInNewContext(runnableParserClass(parserSource), sandbox, { filename: 'V2exNodeParser.ets.transformed.js' })
const { V2exNodeParser } = sandbox.globalThis

const liveShapeFixture = `
<div class="box">
  <div class="cell"><span class="fade"><strong>V2EX</strong> / 节点导航</span></div>
  <div class="cell">
    <table cellpadding="0" cellspacing="0" border="0" width="100%">
      <tr>
        <td width="120" align="right"><span class="fade">分享与探索</span></td>
        <td style="font-size: 14px; line-height: 150%;">
          <a href="/go/qna" class="item_node">问与答</a>
          <a href="/go/share" class="item_node">分享发现</a>
          <a href="/go/create" class="item_node">分享创造</a>
        </td>
      </tr>
    </table>
  </div>
  <div class="cell">
    <table cellpadding="0" cellspacing="0" border="0" width="100%">
      <tr>
        <td width="120" align="right"><span class="fade">iOS</span></td>
        <td style="font-size: 14px; line-height: 150%;">
          <a href="/go/ios" class="item_node">iOS</a>
          <a href="/go/idev" class="item_node">iDev</a>
          <a href="/go/icode" class="item_node">iCode</a>
          <a href="/go/imarketing" class="item_node">iMarketing</a>
          <a href="/go/iad" class="item_node">iAd</a>
        </td>
      </tr>
    </table>
  </div>
  <div class="cell">
    <table cellpadding="0" cellspacing="0" border="0" width="100%">
      <tr>
        <td width="120" align="right"><span class="fade">城市</span></td>
        <td style="font-size: 14px; line-height: 150%;">
          <a href="/go/beijing" class="item_node">北京</a>
          <a href="/go/shanghai" class="item_node">上海</a>
          <a href="/go/shenzhen" class="item_node">深圳</a>
          <a href="/go/hangzhou" class="item_node">杭州</a>
          <a href="/go/sanfrancisco" class="item_node">San Francisco</a>
          <a href="/go/newyork" class="item_node">New York</a>
          <a href="/go/singapore" class="item_node">Singapore</a>
          <a href="/go/la" class="item_node">Los Angeles</a>
        </td>
      </tr>
    </table>
  </div>
  <div class="inner">
    <table cellpadding="0" cellspacing="0" border="0" width="100%">
      <tr>
        <td width="120" align="right"><span class="fade">V2EX</span></td>
        <td style="font-size: 14px; line-height: 150%;">
          <a href="/go/v2ex" class="item_node">V2EX</a>
          <a href="/go/feedback" class="item_node">反馈</a>
          <a href="/go/status" class="item_node">站点状态</a>
          <a href="/go/guide" class="item_node">使用指南</a>
        </td>
      </tr>
    </table>
  </div>
</div>`

assert.equal(liveShapeFixture.includes('<span class="fade"><strong>V2EX</strong> / 节点导航</span>'), true, 'fixture must cover the Chinese V2EX / 节点导航 wrapper seen in live/header HTML')
const sections = V2exNodeParser.extractStructuredNodeNavigationSections(liveShapeFixture)
assert.equal(sections.length, 4, 'Chinese-wrapper node rows should become separate structured sections, not one merged section')
assert.equal(sections[0].title, '分享与探索', 'first structured group must be the first row, not omitted or replaced by the wrapper label')
assert.deepEqual(Array.from(sections[0].nodes.map((node) => node.name)), ['qna', 'share', 'create'])
assert.equal(sections[1].title, 'iOS')
assert.deepEqual(Array.from(sections[1].nodes.map((node) => node.name)), ['ios', 'idev', 'icode', 'imarketing', 'iad'])
assert.equal(sections[2].title, '城市')
assert.deepEqual(Array.from(sections[2].nodes.map((node) => node.name)), ['beijing', 'shanghai', 'shenzhen', 'hangzhou', 'sanfrancisco', 'newyork', 'singapore', 'la'])
assert.equal(sections[3].title, 'V2EX', 'final inner-wrapped V2EX row is a real section and must not be confused with the wrapper')
assert.deepEqual(Array.from(sections[3].nodes.map((node) => node.name)), ['v2ex', 'feedback', 'status', 'guide'])
assert.equal(sections.some((section) => section.title === '节点导航' || section.title === 'V2EX / 节点导航' || section.title === 'V2EX / Curated Nodes'), false, 'wrapper labels must not be emitted as node groups')

const englishWrapperFixture = liveShapeFixture.replace('V2EX</strong> / 节点导航', 'V2EX</strong> / Curated Nodes')
const englishSections = V2exNodeParser.extractStructuredNodeNavigationSections(englishWrapperFixture)
assert.deepEqual(Array.from(englishSections.map((section) => section.title)), ['分享与探索', 'iOS', '城市', 'V2EX'], 'English wrapper must parse the same row structure')

const homeBoxFixture = `
<div class="box">
  <div class="cell"><span class="fade">Hottest Nodes</span></div>
  <div class="cell"><a href="/go/qna" class="item_node">问与答</a><a href="/go/programmer" class="item_node">程序员</a></div>
</div><div class="sep20"></div>
<div class="box">
  <div class="cell"><span class="fade">Recently Created</span></div>
  <div class="cell"><a href="/go/claude" class="item_node">Claude</a></div>
</div><div class="sep20"></div>`
const homeSections = V2exNodeParser.extractNodeNavigationSections(homeBoxFixture)
assert.deepEqual(Array.from(homeSections.map((section) => section.title)), ['Hottest Nodes', 'Recently Created'], 'parser should preserve source home labels and leave localization to UI')
assert.deepEqual(Array.from(homeSections.map((section) => section.titleKey)), ['discover_node_navigation_hottest', 'discover_node_navigation_recently_created'], 'home sections should carry i18n title keys')
assert.deepEqual(Array.from(homeSections[0].nodes.map((node) => node.name)), ['qna', 'programmer'])
assert.deepEqual(Array.from(homeSections[1].nodes.map((node) => node.name)), ['claude'])
assert.equal(englishSections.some((section) => section.title === '最热节点'), false, 'structured row titles must not use the home-title localization path')

// Regression lock: V2EX serves the "recently added" sidebar box with a CHINESE heading (最近新增节点) even
// while "Hottest Nodes" stays English. The parser must map the Chinese heading to a title key, else the
// title&&titleKey guard drops the whole group (the bug the user reported: missing 最近新增节点 group).
const chineseHomeBoxFixture = `
<div class="box">
  <div class="cell"><span class="fade">Hottest Nodes</span></div>
  <div class="cell"><a href="/go/qna" class="item_node">问与答</a></div>
</div><div class="sep20"></div>
<div class="box">
  <div class="cell"><span class="fade">最近新增节点</span></div>
  <div class="cell"><a href="/go/claude" class="item_node">Claude</a><a href="/go/codex" class="item_node">Codex</a></div>
</div><div class="sep20"></div>`
const chineseHomeSections = V2exNodeParser.extractNodeNavigationSections(chineseHomeBoxFixture)
assert.deepEqual(Array.from(chineseHomeSections.map((section) => section.titleKey)), ['discover_node_navigation_hottest', 'discover_node_navigation_recently_created'], 'Chinese 最近新增节点 heading must still resolve a title key (not be dropped)')
assert.deepEqual(Array.from(chineseHomeSections[1].nodes.map((node) => node.name)), ['claude', 'codex'], 'recently-added box nodes survive')

console.log('test_discover_node_navigation_parser_contract: PASS')
