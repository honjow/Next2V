#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(path, 'utf8')
const profileCard = read('feature/user/src/main/ets/components/UserProfileComponents.ets')
const repliesCard = read('feature/user/src/main/ets/components/UserRepliesComponents.ets')
const profilePage = read('feature/user/src/main/ets/pages/UserProfilePage.ets')
const repliesPage = read('feature/user/src/main/ets/pages/UserRepliesPage.ets')
const memberParser = read('shared/src/main/ets/parser/V2exMemberPageParser.ets')
const networkTypes = read('shared/src/main/ets/network/NetworkTypes.ets')

const cardStruct = (source, name) => {
  const start = source.indexOf(`export struct ${name}`)
  assert.ok(start >= 0, `${name} missing`)
  const end = source.indexOf('\n}\n', start)
  assert.ok(end > start, `${name} block missing`)
  return source.slice(start, end + 3)
}

for (const [name, block] of [
  ['UserProfileReplyCard', cardStruct(profileCard, 'UserProfileReplyCard')],
  ['UserRepliesCard', cardStruct(repliesCard, 'UserRepliesCard')],
]) {
  assert.match(block, /openTopic\?: \(\) => void/, `${name} must expose one primary topic action`)
  assert.match(block, /build\(\) \{\s*Button\(\) \{\s*this\.ReplyCardContent\(\)\s*\}[\s\S]*\.type\(ButtonType\.Normal\)[\s\S]*\.padding\(ThemeConstants\.SPACE_MD\)[\s\S]*\.width\('100%'\)[\s\S]*\.borderRadius\(ThemeConstants\.RADIUS_CARD\)[\s\S]*\.backgroundColor\(\$r\('sys\.color\.ohos_id_color_card_bg'\)\)[\s\S]*\.onClick\(\(\) => \{\s*this\.openPrimaryTopic\(\)\s*\}\)/, `${name} must use a native custom-styled Button as the whole-card primary click surface`)
  assert.match(block, /@Builder private ReplyCardContent\(\) \{\s*Column\(\{ space: ThemeConstants\.SPACE_SM \}\)[\s\S]*MarkdownContent\(\{[\s\S]*\}\)[\s\S]*\.alignItems\(HorizontalAlign\.Start\)\s*\}/, `${name} must keep visual content inside the Button surface, not on a clickable parent Column`)
  const contentBuilder = block.slice(block.indexOf('@Builder private ReplyCardContent()'), block.indexOf('  build() {'))
  assert.doesNotMatch(contentBuilder, /\.backgroundColor\(\$r\('sys\.color\.ohos_id_color_card_bg'\)\)|\.onClick\(/, `${name} must reject the old parent Column-onClick-only implementation`)
  assert.match(block, /private replyBodySource\(\): string[\s\S]*this\.reply\.content_rendered[\s\S]*return this\.reply\.content \|\| ''/, `${name} must prefer content_rendered and fall back to content`)
  assert.match(block, /MarkdownContent\(\{[\s\S]*source: this\.replyBodySource\(\)[\s\S]*onLinkClick:[\s\S]*this\.runInlineAction[\s\S]*onImageClick:[\s\S]*this\.runInlineAction[\s\S]*onMentionClick:[\s\S]*this\.runInlineAction/, `${name} must keep link/image/mention as guarded inline actions`)
  assert.doesNotMatch(block, /Stack\s*\(/, `${name} must not use Stack overlays`)
  assert.doesNotMatch(block, /HitTestMode\.Transparent|responseRegion|\.hitTestBehavior\(\s*HitTestMode\.Transparent/, `${name} must not use transparent hit-test hacks`)
  assert.doesNotMatch(block, /Color\.Transparent|opacity\(\s*0\s*\)|layoutWeight\(/, `${name} must not add transparent/fake/layout-weight hit surfaces`)
  assert.doesNotMatch(block, /Text\(this\.reply\.topic_title\)[\s\S]{0,220}\.onClick\(/, `${name} must not be title-only navigation`)
  assert.doesNotMatch(block, /Span\([^\n]*\)[\s\S]{0,160}openPrimaryTopic|onImageClick:[\s\S]{0,160}openPrimaryTopic/, `${name} must not implement primary navigation as glyph/image-only patches`)
}

assert.match(profilePage, /openTopic:\s*\(\) => \{\s*this\.openReplyTopic\(reply\)\s*\}/, 'profile recent replies must pass primary navigation to card')
assert.match(repliesPage, /openTopic:\s*\(\) => \{ this\.openReplyTopic\(reply\) \}/, 'all-replies page must pass primary navigation to card')
assert.match(profilePage, /ImagePreviewParams/, 'profile page must import ImagePreviewParams')
assert.match(repliesPage, /ImagePreviewParams/, 'all-replies page must import ImagePreviewParams')
assert.match(profilePage, /openImage:\s*\(url: string\) => \{\s*this\.openImagePreview\(url\)\s*\}/, 'profile recent replies must route inline images to ImagePreview')
assert.match(repliesPage, /openImage:\s*\(url: string\) => \{ this\.openImagePreview\(url\) \}/, 'all-replies must route inline images to ImagePreview')
assert.match(profilePage, /private openImagePreview\(url: string\): void[\s\S]*ImagePreviewParams[\s\S]*pushPathByName\('ImagePreview'/, 'profile page must push ImagePreview with ImagePreviewParams')
assert.match(repliesPage, /private openImagePreview\(url: string\): void[\s\S]*ImagePreviewParams[\s\S]*pushPathByName\('ImagePreview'/, 'all-replies page must push ImagePreview with ImagePreviewParams')
assert.doesNotMatch(profilePage, /openImage:\s*\(url: string\) => \{\s*this\.openContentLink\(url\)\s*\}/, 'profile inline image taps must not use generic link routing')
assert.doesNotMatch(repliesPage, /openImage:\s*\(url: string\) => \{ this\.openContentLink\(url\) \}/, 'all-replies inline image taps must not use generic link routing')
assert.doesNotMatch(profilePage, /ListItem\(\) \{\s*this\.ReplyItem\(reply\)\s*\}\s*\.onClick/, 'profile recent replies must not rely on ListItem-only click handling')
assert.doesNotMatch(repliesPage, /ListItem\(\) \{\s*this\.ReplyItem\(reply\)\s*\}\s*\.onClick/, 'all-replies must not rely on ListItem-only click handling')
assert.match(networkTypes, /content_rendered\?: string/, 'V2exUserReply must carry content_rendered')
assert.match(networkTypes, /reply_key\?: string/, 'V2exUserReply must carry a stable reply_key')
assert.match(networkTypes, /created_text\?: string/, 'V2exUserReply must carry display time fallback text')
assert.match(memberParser, /created_text:\s*meta\.createdText/, 'member reply parser must carry created_text into V2exUserReply')
assert.match(memberParser, /createdText:\s*time\.text/, 'member reply parser meta must preserve parsed display time text')
assert.match(memberParser, /const text = V2exMemberPageParser\.compactText\(m\[2\] \|\| ''\)[\s\S]*return \{ created: 0, text \}/, 'created extractor must preserve visible title-span time text even when no absolute timestamp parses')
assert.match(memberParser, /const fade = \(html \|\| ''\)\.match\([\s\S]*\\bfade\\b[\s\S]*return \{ created: 0, text: V2exMemberPageParser\.compactText\(fade\[1\] \|\| ''\) \}/, 'created extractor must fall back to span.fade display time text without fabricating epoch timestamps')
assert.match(profileCard, /private replyTimeText\(\): string[\s\S]*this\.reply\.created > 0[\s\S]*DateUtils\.toDateString\(this\.reply\.created\)[\s\S]*this\.reply\.created_text/, 'profile reply card must display created_text fallback when created is zero')
assert.match(repliesCard, /private replyTimeText\(\): string[\s\S]*this\.reply\.created > 0[\s\S]*DateUtils\.toDateString\(this\.reply\.created\)[\s\S]*this\.reply\.created_text/, 'all-replies card must display created_text fallback when created is zero')
assert.match(profileCard, /if \(this\.replyTimeText\(\)\) \{\s*Text\(this\.replyTimeText\(\)\)/, 'profile reply card must render fallback time in the existing meta row')
assert.match(repliesCard, /if \(this\.replyTimeText\(\)\) \{\s*Text\(this\.replyTimeText\(\)\)/, 'all-replies card must render fallback time in the existing meta row')
assert.match(memberParser, /content_rendered:\s*contentRendered/, 'member reply parser must preserve rendered reply HTML')
assert.doesNotMatch(memberParser, /replyKey\s*:/, 'member reply parser must not precompute reply keys from dock metadata before body content is known')
assert.doesNotMatch(memberParser, /meta\.replyKey/, 'member reply parser must not prefer dock-only reply keys over body-derived keys')
assert.match(memberParser, /let rowIndex = 0[\s\S]*reply_key:\s*V2exMemberPageParser\.buildReplyKey\(meta, contentRendered, rowIndex\)[\s\S]*rowIndex\+\+/, 'member reply parser must build reply_key at row push time from meta, rendered body, and row index')
assert.match(memberParser, /private static buildReplyKey\(meta: ReplyMeta, content: string, rowIndex: number\): string/, 'member reply parser must build stable reply keys with row uniqueness')
assert.match(memberParser, /const seed = \[[\s\S]*meta\.topicId\.toString\(\)[\s\S]*meta\.targetFloor\.toString\(\)[\s\S]*meta\.created\.toString\(\)[\s\S]*rowIndex\.toString\(\)[\s\S]*V2exMemberPageParser\.compactText\(content \|\| ''\)/, 'reply_key seed must include row uniqueness and actual rendered/body content')
assert.match(memberParser, /private static stableHash\(value: string\): string/, 'member reply parser must hash stable reply-key seeds')
assert.doesNotMatch(memberParser, /#\(\?:reply\|r_\?\)/, 'member parser must not treat DOM #reply/#r anchors as floor numbers')
assert.match(memberParser, /match\(\/\^#\(\\d\+\)\$\//, 'member parser may only parse explicit numeric floor anchors')
assert.match(profilePage, /LazyForEach\([\s\S]*this\.vm\.replyDataSource[\s\S]*\(reply: V2exUserReply\) => this\.replyStableKey\(reply\)/, 'profile recent replies must use replyStableKey as LazyForEach key')
assert.match(repliesPage, /LazyForEach\(this\.vm\.replyDataSource[\s\S]*\(reply: V2exUserReply\) => this\.replyStableKey\(reply\)/, 'all-replies must use replyStableKey as LazyForEach key')
assert.match(profilePage, /private replyStableKey\(reply: V2exUserReply\): string[\s\S]*reply\.reply_key[\s\S]*return parsedKey[\s\S]*return `\$\{reply\.topic_id\}-\$\{reply\.target_floor\}-\$\{reply\.created\}/, 'profile reply key must prefer reply_key with fallback')
assert.match(repliesPage, /private replyStableKey\(reply: V2exUserReply\): string[\s\S]*reply\.reply_key[\s\S]*return parsedKey[\s\S]*return `\$\{reply\.topic_id\}-\$\{reply\.target_floor\}-\$\{reply\.created\}/, 'all-replies reply key must prefer reply_key with fallback')

console.log('PASS user reply card surface static contract')
