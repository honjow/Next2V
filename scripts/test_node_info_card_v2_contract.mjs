#!/usr/bin/env node
// Static contract for the node-info header card + scroll-reveal app-bar title (feat/node-info-card).
//
// Mirrors the user-profile scroll-reveal pattern: NodeTopicPage hosts a NodeInfoCard as the first list
// item, reports the node-name Text's bottom global Y, and publishes an icon+name reveal identity into
// the NodeTopicAppbarState mirror that Index renders via a ComponentContent. This check pins:
//   - the new files exist and are V2 (@ComponentV2 / no V1 component-state decorators)
//   - NodeInfoCard reports the name area + gates the optional `header` description
//   - NodeTopicPage wires onDidScroll + the reveal publish + keeps the favorite/follow actions intact
//   - NodeTopicAppbarState carries the reveal fields and Index renders the icon+name CC
// Run: node scripts/test_node_info_card_v2_contract.mjs
import { readFileSync } from 'node:fs'
import assert from 'node:assert/strict'

function read(rel) {
  return readFileSync(rel, 'utf8')
}

function mustContain(text, needle, label = needle) {
  assert.notEqual(text.indexOf(needle), -1, `MISSING: ${label}`)
}

const V1_DECORATORS = [
  '@State', '@Prop', '@Link', '@Watch', '@StorageLink', '@StorageProp',
  '@Provide', '@Consume', '@ObjectLink', '@Observed', '@Track',
  '@LocalStorageLink', '@LocalStorageProp',
]

function mustBeV2(text, rel) {
  for (const dec of V1_DECORATORS) {
    // @ObservedV2 must not trip the bare @Observed check.
    const re = new RegExp(`${dec.replace(/[$]/g, '\\$')}\\b(?!V2)`)
    assert.ok(!re.test(text), `${rel}: forbidden V1 decorator ${dec}`)
  }
}

// ── NodeInfoCard ────────────────────────────────────────────────────
const card = read('feature/node/src/main/ets/components/NodeInfoCard.ets')
mustBeV2(card, 'NodeInfoCard')
mustContain(card, '@ComponentV2', 'NodeInfoCard is @ComponentV2')
mustContain(card, 'export struct NodeInfoCard', 'NodeInfoCard struct')
mustContain(card, '@Event onNodeNameAreaChange', 'NodeInfoCard reports name area up via @Event')
mustContain(card, '.onAreaChange(', 'NodeInfoCard observes the name Text area')
mustContain(card, 'this.detail?.header', 'NodeInfoCard reads the optional node header description')
mustContain(card, 'this.topicCount() > 0', 'NodeInfoCard gates topic count')
mustContain(card, "$r('app.string.node_topics_count')", 'NodeInfoCard reuses the node topics-count i18n key')
assert.ok(!/\bAvatar\(\{[^}]*\bcolor\s*:/.test(card), 'NodeInfoCard should not hardcode avatar color')

// ── NodeTopicPageCoordinator ────────────────────────────────────────
const coord = read('feature/node/src/main/ets/model/NodeTopicPageCoordinator.ets')
mustContain(coord, 'static shouldShowAppbarTitle(', 'coordinator gates reveal')
mustContain(coord, 'static appbarIdentity(', 'coordinator builds the reveal identity')
mustContain(coord, 'static nextStringState(', 'coordinator keeps a per-route ledger')

// ── NodeTopicPage ───────────────────────────────────────────────────
const page = read('feature/node/src/main/ets/pages/NodeTopicPage.ets')
mustBeV2(page, 'NodeTopicPage')
mustContain(page, 'NodeInfoCard({', 'NodeTopicPage renders NodeInfoCard')
mustContain(page, 'this.NodeHeaderCard()', 'NodeInfoCard hosted as a list item builder')
mustContain(page, 'onDidScroll:', 'NodeTopicPage tracks scroll offset')
mustContain(page, 'this.evaluateAppbarReveal()', 'NodeTopicPage evaluates the reveal threshold')
mustContain(page, 'this.publishAppbarReveal(', 'NodeTopicPage publishes the reveal identity')
mustContain(page, 'nodeNameContentBottom', 'NodeTopicPage stores the name bottom in content space')
// Favorite + follow node actions must remain wired (UI preservation).
mustContain(page, 'prepareSiteNodeFavoriteToggle', 'site favorite still wired')
mustContain(page, 'toggleSavedNode', 'follow/save node still wired')

// ── NodeTopicAppbarState ────────────────────────────────────────────
const state = read('shared/src/main/ets/state/NodeTopicAppbarState.ets')
for (const f of ['titleNodeName', 'titleNodeAvatarUrl', 'titleRouteNodeName', 'titleNameStates', 'titleAvatarStates']) {
  mustContain(state, `@Trace ${f}`, `NodeTopicAppbarState.${f} is @Trace`)
}
mustContain(state, 'publishNodeTopicAppbarTitleNodeName', 'reveal publish helper exported')
mustContain(state, 'publishNodeTopicAppbarTitleNameStates', 'per-route name ledger publish helper')

// barrel export
const barrel = read('shared/src/main/ets/Index.ets')
mustContain(barrel, 'publishNodeTopicAppbarTitleNodeName', 'shared barrel exports reveal helpers')

// ── Index wiring ────────────────────────────────────────────────────
const index = read('entry/src/main/ets/pages/Index.ets')
mustContain(index, 'NodeTopicIdentityCCBuilder', 'Index uses the node identity CC builder')
mustContain(index, 'IndexTitleBarCoordinator.nodeTopicIdentity(', 'Index resolves the reveal identity')
mustContain(index, 'this.sendNodeTopicAction(nodeName, \'siteFavorite\')', 'Index keeps the site-favorite action')
mustContain(index, 'this.sendNodeTopicAction(nodeName, \'saveNode\')', 'Index keeps the save/follow action')

const titleComponents = read('entry/src/main/ets/components/IndexTitleBarComponents.ets')
mustContain(titleComponents, 'struct NodeTopicAppbarIdentity', 'node identity title component exists')
mustContain(titleComponents, 'export function NodeTopicIdentityCCBuilder', 'node identity CC builder exported')

const titleCoord = read('entry/src/main/ets/model/IndexTitleBarCoordinator.ets')
mustContain(titleCoord, 'static nodeTopicIdentity(', 'title coordinator resolves the node reveal identity')

console.log('test_node_info_card_v2_contract: PASS')
