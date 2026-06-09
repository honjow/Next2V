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
const markdownContent = read('shared/src/main/ets/components/MarkdownContent.ets')

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
  assert.match(block, /build\(\) \{\s*Column\(\) \{\s*this\.ReplyCardContent\(\)\s*\}[\s\S]*\.padding\(ThemeConstants\.SPACE_MD\)[\s\S]*\.width\('100%'\)[\s\S]*\.borderRadius\(ThemeConstants\.RADIUS_CARD\)[\s\S]*\.backgroundColor\(\$r\('sys\.color\.ohos_id_color_card_bg'\)\)[\s\S]*\.alignItems\(HorizontalAlign\.Start\)[\s\S]*\.onClick\(\(\) => \{\s*this\.openPrimaryTopic\(\)\s*\}\)/, `${name} must expose the actual card root as a styled Column click surface so blank/padding areas are not lost inside Button composition`)
  assert.match(block, /@Builder private ReplyCardContent\(\) \{\s*Column\(\{ space: ThemeConstants\.SPACE_SM \}\)[\s\S]*Text\(this\.reply\.topic_title\)[\s\S]*\.onClick\(\(\) => \{\s*this\.openPrimaryTopic\(\)\s*\}\)[\s\S]*MarkdownContent\(\{[\s\S]*\}\)[\s\S]*\.alignItems\(HorizontalAlign\.Start\)\s*\}/, `${name} must keep visual content inside the card surface and give the real title text owner a primary action`)
  assert.doesNotMatch(block, /build\(\) \{\s*Button\(\)/, `${name} must not use Button as the outer card surface because device QA showed nested Markdown/Text taps are swallowed in that composition`)
  assert.match(block, /private replyBodySource\(\): string[\s\S]*this\.reply\.content_rendered[\s\S]*return this\.reply\.content \|\| ''/, `${name} must prefer content_rendered and fall back to content`)
  assert.match(block, /MarkdownContent\(\{[\s\S]*source: this\.replyBodySource\(\)[\s\S]*contentSelectable:\s*false[\s\S]*onContentClick:\s*\(\) => \{\s*this\.openPrimaryTopic\(\)\s*\}[\s\S]*onLinkClick:[\s\S]*this\.runInlineAction[\s\S]*onImageClick:[\s\S]*this\.runInlineAction[\s\S]*onMentionClick:[\s\S]*this\.runInlineAction/, `${name} must render reply body in non-selectable preview mode and route ordinary content taps through the primary topic action while guarding link/image/mention inline actions`)
  assert.match(block, /private primaryActionInFlight: boolean = false[\s\S]*private openPrimaryTopic\(\): void \{[\s\S]*this\.inlineActionInFlight \|\| this\.primaryActionInFlight[\s\S]*this\.primaryActionInFlight = true[\s\S]*setTimeout\(\(\) => \{\s*this\.primaryActionInFlight = false\s*\}, 0\)[\s\S]*this\.openTopic\(\)/, `${name} must de-duplicate primary route opens when body glyph/container/card surfaces all see one tap`)
  assert.doesNotMatch(block, /Stack\s*\(/, `${name} must not use Stack overlays`)
  assert.doesNotMatch(block, /HitTestMode\.Transparent|responseRegion|\.hitTestBehavior\(\s*HitTestMode\.Transparent/, `${name} must not use transparent hit-test hacks`)
  assert.doesNotMatch(block, /Color\.Transparent|opacity\(\s*0\s*\)|layoutWeight\(/, `${name} must not add transparent/fake/layout-weight hit surfaces`)
  assert.match(block, /Text\(this\.reply\.topic_title\)[\s\S]{0,260}\.onClick\(\(\) => \{\s*this\.openPrimaryTopic\(\)\s*\}\)[\s\S]*MarkdownContent\(\{[\s\S]*onContentClick:\s*\(\) => \{\s*this\.openPrimaryTopic\(\)\s*\}/, `${name} must keep title navigation while also routing the body Markdown surface to the same primary action`)
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
assert.match(markdownContent, /contentSelectable\?: boolean/, 'MarkdownOptions must expose selectable/detail vs preview/card mode')
assert.match(markdownContent, /@Param contentSelectable: boolean = true;[\s\S]*onContentClick\?: \(\) => void/, 'MarkdownContent default must preserve selectable detail mode and expose ordinary-content callback')
assert.match(markdownContent, /struct MarkdownInlineText[\s\S]*if \(this\.contentSelectable\)[\s\S]*\.textSelectable\(this\.textSelectable\)[\s\S]*else[\s\S]*\.onClick\(\(\) => \{\s*_openContent\(this\.options\);\s*\}\)/, 'MarkdownInlineText must make the text owner selectable in detail mode and tap-friendly in preview mode')
assert.match(markdownContent, /struct SelectableInlineTokenFlow[\s\S]*@Param contentSelectable: boolean = true;[\s\S]*if \(this\.contentSelectable\)[\s\S]*\.textSelectable\(this\.textSelectable\)[\s\S]*else[\s\S]*\.onClick\(\(\) => \{\s*_openContent\(this\.options\);\s*\}\)/, 'SelectableInlineTokenFlow must respect preview non-selectable ordinary content taps for base64 badge paths')
assert.match(markdownContent, /function SelectableTextWithMentions\(text: string, fontSize: number, options: MarkdownOptions, contentSelectable: boolean = true\)[\s\S]*if \(contentSelectable\) \{\s*Span\(part\)[\s\S]*\.fontColor\(ThemeConstants\.TEXT_PRIMARY\);\s*\} else \{[\s\S]*ordinary glyph tap belongs to the owning Text[\s\S]*Span\(part\)[\s\S]*\.fontColor\(ThemeConstants\.TEXT_PRIMARY\);\s*\}/, 'plain ordinary Span text must stay click-free in non-selectable preview mode so the real Text owner receives body glyph taps')
assert.doesNotMatch(markdownContent, /else \{\s*Span\(part\)[\s\S]{0,180}_openContent\(options\)/, 'ordinary preview Span must not install its own content click because device QA showed that deadens body glyph taps')
assert.match(markdownContent, /function SelectableInlineTokenSpans\([\s\S]*base64PopupScope: string = "inline",\s*contentSelectable: boolean = true,[\s\S]*SelectableTextWithMentions\(\(t as Tokens\.Text\)\.text \?\? t\.raw \?\? "", fontSize, options, contentSelectable\)/, 'plain text token render path must pass preview/selectable mode into the real Span owner')
assert.match(markdownContent, /struct MarkdownInlineText[\s\S]*SelectableInlineTokenSpans\([\s\S]*this\.base64PopupScope,\s*this\.contentSelectable,\s*\);/, 'MarkdownInlineText must pass card preview mode to SelectableInlineTokenSpans')
assert.match(markdownContent, /struct MarkdownInlineText[\s\S]*else \{\s*Text\(\) \{[\s\S]*this\.InlineSpans\(\);[\s\S]*\.onClick\(\(\) => \{\s*_openContent\(this\.options\);\s*\}\)/, 'MarkdownInlineText preview Text owner must open ordinary body glyph taps')
assert.match(markdownContent, /build\(\) \{\s*Column\(\{ space: this\.blockSpace\(\) \}\)[\s\S]*ForEach\(MarkdownContent\.processTokens\(this\.source, this\.inlineImageSizeRecords\)[\s\S]*this\.RenderProcessedToken\(token\);[\s\S]*\.onClick\(\(\) => \{\s*if \(!this\.contentSelectable\) \{\s*if \(this\.onContentClick\) \{\s*this\.onContentClick\(\);\s*\}\s*\}\s*\}\);/, 'MarkdownContent root preview container must route ordinary body whitespace/container taps while detail remains selectable')

const selectableInlineTokenFlowCalls = (source) => {
  const calls = []
  const needle = 'SelectableInlineTokenFlow('
  let searchFrom = 0
  while (true) {
    const start = source.indexOf(needle, searchFrom)
    if (start < 0) break
    const objectStart = source.indexOf('{', start + needle.length)
    assert.ok(objectStart >= 0, `SelectableInlineTokenFlow call at offset ${start} must pass an object literal`)
    let depth = 0
    let quote = null
    let escaped = false
    for (let i = objectStart; i < source.length; i++) {
      const ch = source[i]
      if (quote) {
        if (escaped) {
          escaped = false
        } else if (ch === '\\') {
          escaped = true
        } else if (ch === quote) {
          quote = null
        }
        continue
      }
      if (ch === '"' || ch === "'" || ch === '`') {
        quote = ch
        continue
      }
      if (ch === '{') depth++
      if (ch === '}') {
        depth--
        if (depth === 0) {
          calls.push({ start, body: source.slice(objectStart, i + 1) })
          searchFrom = i + 1
          break
        }
      }
    }
    assert.ok(searchFrom > start, `SelectableInlineTokenFlow call at offset ${start} must be parseable`)
  }
  return calls
}

const selectableInlineCalls = selectableInlineTokenFlowCalls(markdownContent)
assert.ok(selectableInlineCalls.length > 0, 'MarkdownContent must contain SelectableInlineTokenFlow calls')
for (const call of selectableInlineCalls) {
  assert.match(call.body, /contentSelectable:\s*_contentSelectable\(this\.(?:options|markdownOptions\(\))\)/, `SelectableInlineTokenFlow call at offset ${call.start} must pass contentSelectable from MarkdownOptions`)
}
assert.match(markdownContent, /SelectableInlineTokenFlow\(\{[\s\S]*contentSelectable:\s*_contentSelectable\(this\.options\)[\s\S]*base64PopupScope: `paragraph-block-\$\{tokenIdx\}`/, 'paragraph block/base64 badge branch must pass contentSelectable into SelectableInlineTokenFlow')
assert.match(markdownContent, /SelectableInlineTokenFlow\(\{[\s\S]*contentSelectable:\s*_contentSelectable\(this\.options\)[\s\S]*base64PopupScope: "paragraph-inline"/, 'mixed inline image/base64 badge branch must pass contentSelectable into SelectableInlineTokenFlow')
assert.match(markdownContent, /SelectableInlineTokenFlow\(\{[\s\S]*contentSelectable:\s*_contentSelectable\(this\.options\)[\s\S]*base64PopupScope: "paragraph-text"/, 'text/base64 badge branch must pass contentSelectable into SelectableInlineTokenFlow')
assert.match(markdownContent, /SelectableInlineTokenFlow\(\{[\s\S]*contentSelectable:\s*_contentSelectable\(this\.markdownOptions\(\)\)[\s\S]*base64PopupScope: `heading-\$\{String\(\(token as TokenRecord\)\.raw \?\? \(token as TokenRecord\)\.text \?\? ""\)\}`/, 'heading/base64 badge branch must pass contentSelectable into SelectableInlineTokenFlow')
assert.match(markdownContent, /ImageSpan\(_inlineImageRenderUrl\(t\)\)[\s\S]*\.onClick\(\(\) => \{\s*_openInlineImage\(options, _inlineImageRenderUrl\(t\)\);\s*\}\)[\s\S]*\.onComplete\([\s\S]*reportImageComplete[\s\S]*\.onError\([\s\S]*reportImageError/, 'inline ImageSpan must own image taps through imageClick while preserving load/error reporting')
assert.match(markdownContent, /function _openInlineImage\(options: MarkdownOptions, url: string\): void[\s\S]*MediaUrlUtils\.normalizeUrl\(url\)[\s\S]*options\?\.imageClick[\s\S]*click\(normalized\)/, 'inline image taps must route to the Markdown imageClick path, not ordinary contentClick')
assert.match(markdownContent, /@Param contentSelectable: boolean = true;[\s\S]*onContentClick\?: \(\) => void/, 'MarkdownContent default must preserve selectable detail mode and expose ordinary-content callback')
assert.match(markdownContent, /base64PopupScope: "paragraph-inline",[\s\S]*onMeasured: \(newValue: Area\) => \{ this\.updateParagraphAvailableWidth\(newValue\); \}/, 'mixed inline image/text paragraph path must use MarkdownInlineText instead of a non-selectable bare Text')
assert.match(markdownContent, /MarkdownInlineText\(\{\s*tokens: this\.cellTokens\(cell\),[\s\S]*contentSelectable:\s*_contentSelectable\(this\.options\),[\s\S]*base64PopupScope: `table-\$\{rowIndex\}-\$\{columnIndex\}`,[\s\S]*\}\)[\s\S]*\.width\(this\.columnWidth\(columnIndex\)\)[\s\S]*\.padding\(\{\s*left: ThemeConstants\.SPACE_SM,[\s\S]*bottom: ThemeConstants\.SPACE_XS,\s*\}\)/, 'non-base64 table cell ordinary text path must use MarkdownInlineText and propagate preview contentSelectable/onContentClick while preserving width and padding')
assert.doesNotMatch(markdownContent, /Text\(\) \{\s*SelectableInlineTokenSpans\(\s*this\.cellTokens\(cell\),[\s\S]{0,900}?`table-\$\{rowIndex\}-\$\{columnIndex\}`,[\s\S]{0,220}?\.textSelectable\(TextSelectableMode\.SELECTABLE_FOCUSABLE\)/, 'non-base64 table cells must not keep the old selectable Text owner without preview contentClick propagation')
assert.match(markdownContent, /MarkdownInlineText\(\{\s*tokens: this\.headingInlineTokens\(token\),[\s\S]*contentSelectable:\s*_contentSelectable\(this\.markdownOptions\(\)\),[\s\S]*base64PopupScope: `heading-\$\{String\(\(token as TokenRecord\)\.raw \?\? \(token as TokenRecord\)\.text \?\? ""\)\}`,[\s\S]*\}\)\s*\.width\("100%"\)/, 'non-base64 heading ordinary text path must use MarkdownInlineText and propagate preview contentSelectable/onContentClick while preserving heading width')
assert.doesNotMatch(markdownContent, /Text\(\) \{\s*SelectableInlineTokenSpans\(\s*this\.headingInlineTokens\(token\),[\s\S]{0,900}?`heading-\$\{String\(\(token as TokenRecord\)\.raw \?\? \(token as TokenRecord\)\.text \?\? ""\)\}`,[\s\S]{0,220}?\.textSelectable\(TextSelectableMode\.SELECTABLE_FOCUSABLE\)/, 'non-base64 headings must not keep the old selectable Text owner without preview contentClick propagation')

console.log('PASS user reply card surface static contract')
