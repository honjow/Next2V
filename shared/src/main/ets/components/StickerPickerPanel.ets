import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'

/**
 * One selectable sticker = a display name + an image URL. V2EX has no native sticker system, so a
 * "sticker" is just an image: tapping one inserts a readable placeholder code "[name]" while editing, and
 * the composer expands codes to the bare image URL on submit (V2EX auto-embeds whitelisted hosts such as
 * i.imgur.com) — see ReplyComposerBar.insertSticker / expandStickerCodes.
 */
export interface StickerItem {
  name: string
  url: string
}

/**
 * A visually-separated section of the picker. The panel renders one auto-stretch grid and inserts a
 * full-row separator (see GridLayoutOptions.irregularIndexes below) between groups, so each group after the
 * first starts on a fresh row with a little breathing room — no group titles, just a hairline break.
 */
export interface StickerGroup {
  key: string
  stickers: StickerItem[]
}

/**
 * Built-in packs (URL-referenced imgur images, nothing bundled). Two visually distinct sets:
 *  1) the classic V2EX 黄豆 / 表情党 set (huage2580/v2ex_emoji, names per its map.txt) — small, text-sized
 *     emoji that read alongside a sentence. The 13 names this set shares with the B站 set were dropped here
 *     and kept only in the B站 set (a "[name]" code maps to exactly one URL, so a name can live in one group
 *     only); the huage links are the verified-live re-hosts (a dead imgur link 302s to i.imgur.com/removed.png).
 *  2) the real Bilibili emote set (re-hosted from i0.hdslb.com PNGs to imgur via our own client) — larger,
 *     full-color stickers. This replaced the old, blurry V2EX_Polish set.
 * NOTE: imgur is GFW-restricted in mainland China — picker rendering depends on the network; a domestic
 * re-host (sinaimg.cn) is the planned Phase-2 durability improvement.
 */
const CLASSIC_STICKERS: StickerItem[] = [
  { name: '二哈', url: 'https://i.imgur.com/PbW6ITD.png' },
  { name: '亲亲', url: 'https://i.imgur.com/gtymJtC.png' },
  { name: '假哭', url: 'https://i.imgur.com/e2k7tYF.png' },
  { name: '假笑', url: 'https://i.imgur.com/GPhngD6.png' },
  { name: '发怒', url: 'https://i.imgur.com/6r8ShJP.png' },
  { name: '变态滑稽', url: 'https://i.imgur.com/wvmCA5o.png' },
  { name: '可怜', url: 'https://i.imgur.com/zJzEBlM.png' },
  { name: '吐血', url: 'https://i.imgur.com/EEszOmC.png' },
  { name: '吨吨吨', url: 'https://i.imgur.com/kjfEmYE.png' },
  { name: '咖啡', url: 'https://i.imgur.com/OhQ6tFu.png' },
  { name: '哈哈', url: 'https://i.imgur.com/jEq60iX.png' },
  { name: '哭了', url: 'https://i.imgur.com/KqBmD6k.png' },
  { name: '喜', url: 'https://i.imgur.com/efdSKYi.png' },
  { name: '喷', url: 'https://i.imgur.com/UhQBulZ.png' },
  { name: '嘿哈', url: 'https://i.imgur.com/Fbis1BP.png' },
  { name: '坏笑', url: 'https://i.imgur.com/PzEqUKD.png' },
  { name: '奥特曼', url: 'https://i.imgur.com/3UgIUCZ.png' },
  { name: '心碎', url: 'https://i.imgur.com/LMcbPfS.png' },
  { name: '打脸', url: 'https://i.imgur.com/hePLVvZ.png' },
  { name: '打脸滑稽', url: 'https://i.imgur.com/xgNoo8x.png' },
  { name: '托腮', url: 'https://i.imgur.com/rdq8HCd.png' },
  { name: '捂嘴笑', url: 'https://i.imgur.com/zhwu7Iu.png' },
  { name: '机智', url: 'https://i.imgur.com/PwcbJI4.png' },
  { name: '流汗滑稽', url: 'https://i.imgur.com/P5gN5BH.png' },
  { name: '流泪', url: 'https://i.imgur.com/ZTr5z44.png' },
  { name: '牛啤', url: 'https://i.imgur.com/jP8z9va.png' },
  { name: '疑问', url: 'https://i.imgur.com/sOgSspk.png' },
  { name: '看戏', url: 'https://i.imgur.com/FiTQUcO.png' },
  { name: '瞌睡', url: 'https://i.imgur.com/5eC6nLz.png' },
  { name: '绿帽doge', url: 'https://i.imgur.com/NyRxtpF.png' },
  { name: '花', url: 'https://i.imgur.com/i02mU8N.png' },
  { name: '菜刀', url: 'https://i.imgur.com/rp1OaQW.png' },
  { name: '蛋糕', url: 'https://i.imgur.com/5Jmbs5y.png' },
  { name: '蜡烛', url: 'https://i.imgur.com/l7ZxZec.png' },
  { name: '鄙视', url: 'https://i.imgur.com/MQFgdh9.png' },
  { name: '酷', url: 'https://i.imgur.com/eq6tPW7.png' },
  { name: '香蕉', url: 'https://i.imgur.com/fy7FxE8.png' },
]

const BILI_STICKERS: StickerItem[] = [
  { name: 'doge_金箍', url: 'https://i.imgur.com/hINUr3S.png' },
  { name: '笑哭', url: 'https://i.imgur.com/uWnpJvW.png' },
  { name: '蹲蹲', url: 'https://i.imgur.com/hJ4NoKZ.png' },
  { name: '星星眼', url: 'https://i.imgur.com/nmlBhJd.png' },
  { name: '微笑', url: 'https://i.imgur.com/2yopJ5P.png' },
  { name: '吃瓜', url: 'https://i.imgur.com/o6b4bud.png' },
  { name: '打call', url: 'https://i.imgur.com/oiDGnqk.png' },
  { name: 'OK', url: 'https://i.imgur.com/XpMTVln.png' },
  { name: 'doge', url: 'https://i.imgur.com/bxGSOpE.png' },
  { name: '大哭', url: 'https://i.imgur.com/3LKa7C6.png' },
  { name: '辣眼睛', url: 'https://i.imgur.com/vww3vt2.png' },
  { name: '滑稽', url: 'https://i.imgur.com/g52hDYO.png' },
  { name: '喜极而泣', url: 'https://i.imgur.com/G1u3CXJ.png' },
  { name: '呲牙', url: 'https://i.imgur.com/BXkHp6m.png' },
  { name: '歪嘴', url: 'https://i.imgur.com/77Pj4VX.png' },
  { name: '调皮', url: 'https://i.imgur.com/85KJ2rD.png' },
  { name: '妙啊', url: 'https://i.imgur.com/DgB2pPJ.png' },
  { name: '嗑瓜子', url: 'https://i.imgur.com/b65O63K.png' },
  { name: '藏狐', url: 'https://i.imgur.com/TSfNWEO.png' },
  { name: '脱单doge', url: 'https://i.imgur.com/YnITzQ9.png' },
  { name: '笑', url: 'https://i.imgur.com/gdhVAlW.png' },
  { name: '给心心', url: 'https://i.imgur.com/SkkpyJo.png' },
  { name: '脸红', url: 'https://i.imgur.com/GaXrXWS.png' },
  { name: '嘟嘟', url: 'https://i.imgur.com/RLj1hw9.png' },
  { name: '哦呼', url: 'https://i.imgur.com/lqw5FQL.png' },
  { name: '喜欢', url: 'https://i.imgur.com/q4oIWLo.png' },
  { name: '酸了', url: 'https://i.imgur.com/8LUjiTw.png' },
  { name: '害羞', url: 'https://i.imgur.com/iDEnCDj.png' },
  { name: '嫌弃', url: 'https://i.imgur.com/Dfk9iWs.png' },
  { name: '疑惑', url: 'https://i.imgur.com/VCMMkiZ.png' },
  { name: '偷笑', url: 'https://i.imgur.com/aFc7hfi.png' },
  { name: '惊讶', url: 'https://i.imgur.com/79mgK20.png' },
  { name: '捂脸', url: 'https://i.imgur.com/cj4JQ07.png' },
  { name: '阴险', url: 'https://i.imgur.com/FCRRIcy.png' },
  { name: '呆', url: 'https://i.imgur.com/4Zzuv2D.png' },
  { name: '抠鼻', url: 'https://i.imgur.com/UwZzRKC.png' },
  { name: '大笑', url: 'https://i.imgur.com/M1cHGCs.png' },
  { name: '惊喜', url: 'https://i.imgur.com/R3d38mL.png' },
  { name: '点赞', url: 'https://i.imgur.com/eXwQFx3.png' },
  { name: '无语', url: 'https://i.imgur.com/OOptXub.png' },
  { name: '鼓掌', url: 'https://i.imgur.com/PpCCsaC.png' },
  { name: '尴尬', url: 'https://i.imgur.com/g9E5Brk.png' },
  { name: '灵魂出窍', url: 'https://i.imgur.com/WdCEfLX.png' },
  { name: '傲娇', url: 'https://i.imgur.com/3hIA6fZ.png' },
  { name: '委屈', url: 'https://i.imgur.com/KCv3LPb.png' },
  { name: '疼', url: 'https://i.imgur.com/qYjrJCJ.png' },
  { name: '冷', url: 'https://i.imgur.com/oGUR0b0.png' },
  { name: '热', url: 'https://i.imgur.com/z7lXut3.png' },
  { name: '生病', url: 'https://i.imgur.com/fPqiAgg.png' },
  { name: '生气', url: 'https://i.imgur.com/LJDBBPh.png' },
  { name: '捂眼', url: 'https://i.imgur.com/chHllSG.png' },
  { name: '嘘声', url: 'https://i.imgur.com/vY7xdZD.png' },
  { name: '思考', url: 'https://i.imgur.com/UdLWDqs.png' },
  { name: '再见', url: 'https://i.imgur.com/gbSA6JT.png' },
  { name: '翻白眼', url: 'https://i.imgur.com/rJv2M5K.png' },
  { name: '抓狂', url: 'https://i.imgur.com/k3IzRxN.png' },
  { name: '哈欠', url: 'https://i.imgur.com/2y1N2r8.png' },
  { name: '奋斗', url: 'https://i.imgur.com/Wj1sTC1.png' },
  { name: '墨镜', url: 'https://i.imgur.com/OFR2wCJ.png' },
  { name: '难过', url: 'https://i.imgur.com/ldmbK7B.png' },
  { name: '口罩', url: 'https://i.imgur.com/S2l3Jaw.png' },
  { name: '撇嘴', url: 'https://i.imgur.com/BuRkhBl.png' },
  { name: '黑眼圈_金箍', url: 'https://i.imgur.com/VrxJMD0.png' },
  { name: '猴哥', url: 'https://i.imgur.com/t05IEl9.png' },
  { name: '鸭科夫_流汗鸭', url: 'https://i.imgur.com/fYdFGmV.png' },
  { name: '鸭科夫_干嘛鸭', url: 'https://i.imgur.com/NW3y9o3.png' },
  { name: '鸭科夫_红温鸭', url: 'https://i.imgur.com/VbTwBju.png' },
  { name: '黑猫', url: 'https://i.imgur.com/Mv0gBtn.png' },
  { name: '三花猫', url: 'https://i.imgur.com/PB1PHUj.png' },
  { name: '折耳猫', url: 'https://i.imgur.com/q7nWxTu.png' },
  { name: '银魂_justaway', url: 'https://i.imgur.com/fKdRLqa.png' },
  { name: '我独自升级_疑惑', url: 'https://i.imgur.com/oHVsKDB.png' },
  { name: '怪兽8号_奇可露', url: 'https://i.imgur.com/74xxSXk.png' },
  { name: '颂乐人偶_眯眼笑', url: 'https://i.imgur.com/dgDybwg.png' },
  { name: '坂本_佛系', url: 'https://i.imgur.com/GGMSi5q.png' },
  { name: '生气_金箍', url: 'https://i.imgur.com/rgVijtZ.png' },
  { name: '龙年', url: 'https://i.imgur.com/tUfa4Qg.png' },
  { name: '豹富', url: 'https://i.imgur.com/QaETLBO.png' },
  { name: '兔兔岛_开心', url: 'https://i.imgur.com/VW7pKRP.png' },
  { name: '兔兔岛_吃面', url: 'https://i.imgur.com/5Kl2IfH.png' },
  { name: '兔兔岛_睡觉', url: 'https://i.imgur.com/ErrBESF.png' },
  { name: '重返未来1999_喂', url: 'https://i.imgur.com/DOx7MNt.png' },
  { name: '重返未来1999_赞', url: 'https://i.imgur.com/jptRXiH.png' },
  { name: '重返未来1999_谢谢老板', url: 'https://i.imgur.com/pgc3ojA.png' },
  { name: '重返未来1999_什么', url: 'https://i.imgur.com/En1XMgR.png' },
  { name: '胆大党_微笑', url: 'https://i.imgur.com/BSwFIYL.png' },
  { name: '水稻', url: 'https://i.imgur.com/K8FFlbT.png' },
  { name: '奶茶干杯', url: 'https://i.imgur.com/d3fIsMC.png' },
  { name: '汤圆', url: 'https://i.imgur.com/fdMfs7f.png' },
  { name: '锦鲤', url: 'https://i.imgur.com/S9Y3W7N.png' },
  { name: '福到了', url: 'https://i.imgur.com/M5YhgU0.png' },
  { name: '鸡腿', url: 'https://i.imgur.com/9pYDNRP.png' },
  { name: '雪花', url: 'https://i.imgur.com/D3pkwWW.png' },
  { name: '视频卫星', url: 'https://i.imgur.com/pNXL1sT.png' },
  { name: '干杯', url: 'https://i.imgur.com/tHOaDg0.png' },
  { name: '黑洞', url: 'https://i.imgur.com/H9d6AkM.png' },
  { name: '爱心', url: 'https://i.imgur.com/OLjLCKp.png' },
  { name: '胜利', url: 'https://i.imgur.com/c8h8lAX.png' },
  { name: '加油', url: 'https://i.imgur.com/pl9VNf2.png' },
  { name: '抱拳', url: 'https://i.imgur.com/BuDn06m.png' },
  { name: '响指', url: 'https://i.imgur.com/it6XwnX.png' },
  { name: '保佑', url: 'https://i.imgur.com/25axqv6.png' },
  { name: '福', url: 'https://i.imgur.com/kNTna91.png' },
  { name: '支持', url: 'https://i.imgur.com/e6YaGr9.png' },
  { name: '拥抱', url: 'https://i.imgur.com/tXWREz1.png' },
  { name: '跪了', url: 'https://i.imgur.com/qRWCZX4.png' },
  { name: '怪我咯', url: 'https://i.imgur.com/P1lci3b.png' },
]

export const BUILTIN_STICKER_GROUPS: StickerGroup[] = [
  { key: 'classic', stickers: CLASSIC_STICKERS },
  { key: 'bili', stickers: BILI_STICKERS },
]

/**
 * Flat view of every built-in sticker, in group order. ReplyComposerBar.expandStickerCodes walks this to
 * turn "[name]" codes into bare URLs at submit; group display structure is irrelevant there. Names are
 * unique across groups (overlaps were resolved to one group), so the flattened name->url map has no clashes.
 */
function flattenStickerGroups(groups: StickerGroup[]): StickerItem[] {
  const out: StickerItem[] = []
  for (const group of groups) {
    for (const sticker of group.stickers) {
      out.push(sticker)
    }
  }
  return out
}

export const BUILTIN_STICKERS: StickerItem[] = flattenStickerGroups(BUILTIN_STICKER_GROUPS)

/**
 * Sticker cell side (vp). Grounded in the body text, not picked arbitrarily: the inner emoji is the cell
 * minus its SPACE_XS padding on each side (36 - 8 = 28vp), which is ~1.5x the ~18vp body-text line — these
 * are small 黄豆/微博-style emoji that read alongside text, NOT large stickers. The same physical size renders
 * on every device because the column COUNT (not the cell size) adapts to the screen width (auto-stretch).
 */
const STICKER_CELL_VP: number = 36

/**
 * Height of the full-row separator row between groups (vp). Clearly larger than the inter-row rowsGap so the
 * break reads as a section divider rather than just a wider gap. The grid's rowsGap still applies above and
 * below it, so the total visual break is rowsGap + this + rowsGap.
 */
const GROUP_SEPARATOR_VP: number = 24

/**
 * One grid entry. Either a sticker cell (carrying its own @Trace loaded so each tile can show a skeleton
 * until its network image arrives) or a full-row separator between groups. Modeled as one class (not a union)
 * because ArkTS ForEach iterates a single typed array.
 */
@ObservedV2
class GridEntry {
  isSeparator: boolean = false
  name: string = ''
  url: string = ''
  // Stable ForEach key: the image URL for stickers (unique across groups), "sep-N" for separators.
  key: string = ''
  @Trace loaded: boolean = false
}

/**
 * Chat-app style sticker grid, shown in place of the soft keyboard (the host collapses the IME and gives
 * this panel the keyboard's footprint). Tapping a sticker emits its name; the host inserts "[name]" at the
 * caret. Each cell shows a skeleton tile until its image loads. Groups are separated by a full-row hairline.
 */
@ComponentV2
export struct StickerPickerPanel {
  @Param groups: StickerGroup[] = [];
  @Param panelHeight: number = 300;
  // Emits the sticker's NAME (the readable code, e.g. "doge"); the host inserts "[doge]" while editing and
  // expands codes to the bare image URL only on submit (keeps the text field readable).
  @Event onPick?: (name: string) => void;
  // Flattened render list: group-1 cells, a separator, group-2 cells, ... Rebuilt on each open (the panel is
  // conditionally mounted, so aboutToAppear runs every time it is shown and the skeletons reset).
  @Local private entries: GridEntry[] = [];
  // Bottom safe-area inset so the last sticker row clears the gesture bar when the panel fills to the edge.
  @Local private layout: LayoutSafeAreaState = connectLayoutSafeArea();
  private scroller: Scroller = new Scroller();
  // regularSize keeps normal cells 1x1; irregularIndexes marks the separator rows, which then default to a
  // full row of a vertically-scrolling Grid (only columnsTemplate set) — that is what makes the next group
  // start on a fresh row. Filled in aboutToAppear from the actual group sizes.
  private gridOptions: GridLayoutOptions = { regularSize: [1, 1], irregularIndexes: [] };

  aboutToAppear(): void {
    const list: GridEntry[] = []
    const separators: number[] = []
    this.groups.forEach((group: StickerGroup, groupIndex: number) => {
      // Separator only BETWEEN two non-empty groups: it needs preceding cells (list.length > 0) and at least
      // one cell of its own to follow (group.stickers.length > 0). Guarding on groupIndex alone would leave a
      // dangling/leading hairline when any group is empty.
      if (list.length > 0 && group.stickers.length > 0) {
        const sep = new GridEntry()
        sep.isSeparator = true
        sep.key = `sep-${groupIndex}`
        separators.push(list.length)
        list.push(sep)
      }
      group.stickers.forEach((sticker: StickerItem) => {
        const cell = new GridEntry()
        cell.name = sticker.name
        cell.url = sticker.url
        cell.key = sticker.url
        list.push(cell)
      })
    })
    this.entries = list
    this.gridOptions = { regularSize: [1, 1], irregularIndexes: separators }
  }

  build() {
    Grid(this.scroller, this.gridOptions) {
      ForEach(
        this.entries,
        (entry: GridEntry) => {
          if (entry.isSeparator) {
            // Full-row break between groups (spans every column via irregularIndexes). A short centered
            // hairline + extra height reads as a section divider; no group title by design.
            GridItem() {
              Column() {
                Divider()
                  .strokeWidth(0.5)
                  .width('36%')
                  .color($r('sys.color.ohos_id_color_list_separator'))
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            }.height(GROUP_SEPARATOR_VP)
          } else {
            GridItem() {
              Stack() {
                // Skeleton tile shown until the image loads; hidden afterwards so a transparent emoji isn't
                // left sitting on a grey chip.
                Column()
                  .width('100%')
                  .aspectRatio(1)
                  .borderRadius(ThemeConstants.RADIUS_SM)
                  .backgroundColor(ThemeConstants.BG_SUB)
                  .visibility(entry.loaded ? Visibility.Hidden : Visibility.Visible)
                Image(entry.url)
                  .width('100%')
                  .aspectRatio(1)
                  .objectFit(ImageFit.Contain)
                  .draggable(false)
                  .borderRadius(ThemeConstants.RADIUS_SM)
                  .onComplete(() => {
                    entry.loaded = true
                  })
                  .onError(() => {
                    entry.loaded = true
                  })
              }
            }
            // Small inset so the sticker has breathing room inside its fixed-size cell.
            .padding(ThemeConstants.SPACE_XS)
            .onClick(() => {
              if (this.onPick) {
                this.onPick(entry.name)
              }
            })
          }
        },
        (entry: GridEntry) => entry.key,
      )
    }
    // Responsive + text-scaled: fixed 36vp cells (the ~28vp emoji inside is ~1.5x the 14vp/~18vp body-text
    // line — a small emoji, not a big sticker), column count auto-computed for the screen width via
    // auto-stretch (same physical size on every device; leftover width goes into the gaps), instead of a
    // fixed 8/row that shrank stickers on narrow/high-density screens and ballooned them on tablets/wide ones.
    .columnsTemplate(`repeat(auto-stretch, ${STICKER_CELL_VP})`)
    .columnsGap(ThemeConstants.SPACE_SM)
    .rowsGap(ThemeConstants.SPACE_SM)
    // Side gutters (SPACE_LG) keep the grid from crowding the screen edges; the panel BACKGROUND is still
    // full-bleed (width 100%, set below) — only the cells are inset. The bottom inset = a row gap plus the
    // gesture-bar height, so the background bleeds under the nav bar (immersive) while the last sticker row
    // still scrolls to rest above it and stays tappable.
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_SM,
      bottom: ThemeConstants.SPACE_SM + this.layout.bottomAvoidHeight,
    })
    .width('100%')
    // Fixed height = the keyboard's footprint (panelHeight), NEVER content-fit. This is the invariant that
    // keeps the keyboard <-> panel swap from jumping: the host drops the bar to the bottom and the panel takes
    // exactly the space the keyboard vacated, so the bar lands at the same Y. The pack scrolls when it overflows
    // (narrow phone); when it doesn't fill the height (wide tablet) the leftover panel background is expected —
    // shrinking to content would reintroduce the jump.
    .height(this.panelHeight)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .scrollBar(BarState.Off)
  }
}
