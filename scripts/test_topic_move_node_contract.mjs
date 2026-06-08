#!/usr/bin/env node
/**
 * Move-topic-node contract.
 *
 * Moving a topic to another node is SEPARATE from editing (the /edit form has no node field). Captured
 * live: under 管理功能 on the topic page, 移动主题到其他节点 → GET /move/topic/<id> (form has
 * <select name="destination"> + a page-level once, NO hidden once) → POST /move/topic/<id>?once=<v> with
 * destination=<nodeName>. Author-only, same 600s window as edit. The detail page picks the destination via
 * the shared NodePickerPage and CONFIRMS before the (destructive) move, so a stray bus pick can't move it.
 *
 * Run: node scripts/test_topic_move_node_contract.mjs
 */
import fs from 'node:fs'
import path from 'node:path'

const REPO = process.cwd()
const read = (rel) => fs.readFileSync(path.join(REPO, rel), 'utf8')
const failures = []
const ok = []
const check = (cond, label) => { (cond ? ok : failures).push(label) }

// ── API: moveTopicNodeWithCookie (mirrors edit's ?once mechanism) ────────────────
const api = read('shared/src/main/ets/network/ApiService.ets')
check(/async moveTopicNodeWithCookie\(/.test(api), 'ApiService.moveTopicNodeWithCookie defined')
const move = api.slice(api.indexOf('async moveTopicNodeWithCookie('), api.indexOf('async syncBlockedListsFromCookieHtmlSources('))
check(move.includes('/move/topic/${topicId}'), 'targets /move/topic/<id>')
check(move.includes("fields['destination']"), 'posts the destination node name')
check(move.includes('name="destination"') && move.includes('ApiErrors.editWindowClosed()'), 'no move form (window closed / not owner) → window-closed/not-owner')
check(move.includes('?once=') && move.includes('extractPageOnce'), 'move submit appends the page-level ?once= (no hidden once, same as edit)')
check(move.includes('ApiService.isTopicLocation(res.location, topicId)'), 'success = redirect back to /t/<id>')

// ── menu: moveTopic action gated by canEdit (move shares the edit window) ────────
const coord = read('entry/src/main/ets/model/TopicDetailTitleBarCoordinator.ets')
check(coord.includes("'moveTopic'") && /R_TOPIC_ACTION_MOVE/.test(coord), 'coordinator declares the moveTopic action')
const index = read('entry/src/main/ets/pages/Index.ets')
const visible = index.slice(index.indexOf('private isTopicActionVisible('), index.indexOf('private topicDetailTitleActionIcon('))
check(visible.includes("action === 'moveTopic'") && visible.includes('topicDetailOwnership.canEdit'), 'Index gates moveTopic by canEdit (the 600s move window)')

// ── detail: dispatch + the guarded node-pick → confirm → move flow ──────────────
const detail = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
check(detail.includes("action === 'moveTopic'") && detail.includes('openMoveNode('), 'detail dispatches moveTopic → openMoveNode')
check(detail.includes("this.movePending = true") && detail.includes("pushPathByName('NodePicker'"), 'openMoveNode arms movePending then opens the node picker')
check(/@Monitor\('nodePick\.command'\)/.test(detail) && /if \(!this\.movePending\)\s*\{\s*return/.test(detail), 'the node-pick handler only acts when a move was armed (movePending gate)')
check(detail.includes('this.movePending = false') && /showAlertDialog\([\s\S]{0,400}R_TOPIC_MOVE_CONFIRM_FORMAT/.test(detail.slice(detail.indexOf('onMoveNodePicked'))), 'a stray pick clears the flag and a confirm dialog guards the destructive move')
check(detail.includes('this.api.moveTopicNodeWithCookie(') && /executeMoveNode/.test(detail), 'confirmed move calls moveTopicNodeWithCookie then reloads')

for (const f of failures) console.error(`FAIL  ${f}`)
console.log(`\ntopic move-node contract: ${ok.length} checks passed, ${failures.length} failure(s)`)
if (failures.length) process.exit(1)
