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
 * Built-in pack. Two URL-referenced imgur packs (no assets bundled): the classic V2EX "滑稽 / 表情党" set
 * (huage2580/v2ex_emoji, names per its map.txt) plus V2EX_Polish's maintained B站 / 小红薯 set. Names that
 * appear in both (doge·吃瓜·惊讶·跪了) use the V2EX_Polish image. The huage2580 set's dead imgur links were
 * re-hosted to fresh imgur URLs (uploaded from the repo's 42×42 source PNGs). Every URL here is
 * liveness-verified (a dead imgur link 302-redirects to i.imgur.com/removed.png).
 * NOTE: imgur is GFW-restricted in mainland China — picker rendering depends on the network; a domestic
 * re-host (sinaimg.cn) is the planned Phase-2 durability improvement.
 */
export const BUILTIN_STICKERS: StickerItem[] = [
  // 经典 V2EX 滑稽 / 表情党 (huage2580/v2ex_emoji)。Names follow the repo's canonical map.txt; dead
  // imgur links were re-hosted to fresh imgur URLs (same 42×42 source). All verified live.
  { name: '二哈', url: 'https://i.imgur.com/PbW6ITD.png' },
  { name: '亲亲', url: 'https://i.imgur.com/gtymJtC.png' },
  { name: '假哭', url: 'https://i.imgur.com/e2k7tYF.png' },
  { name: '假笑', url: 'https://i.imgur.com/GPhngD6.png' },
  { name: '再见', url: 'https://i.imgur.com/4WEcFPB.png' },
  { name: '发怒', url: 'https://i.imgur.com/6r8ShJP.png' },
  { name: '变态滑稽', url: 'https://i.imgur.com/wvmCA5o.png' },
  { name: '可怜', url: 'https://i.imgur.com/zJzEBlM.png' },
  { name: '吐血', url: 'https://i.imgur.com/EEszOmC.png' },
  { name: '吨吨吨', url: 'https://i.imgur.com/kjfEmYE.png' },
  { name: '呲牙', url: 'https://i.imgur.com/WSVntmW.png' },
  { name: '咖啡', url: 'https://i.imgur.com/OhQ6tFu.png' },
  { name: '哈哈', url: 'https://i.imgur.com/jEq60iX.png' },
  { name: '哭了', url: 'https://i.imgur.com/KqBmD6k.png' },
  { name: '喜', url: 'https://i.imgur.com/efdSKYi.png' },
  { name: '喷', url: 'https://i.imgur.com/UhQBulZ.png' },
  { name: '嘿哈', url: 'https://i.imgur.com/Fbis1BP.png' },
  { name: '坏笑', url: 'https://i.imgur.com/PzEqUKD.png' },
  { name: '大笑', url: 'https://i.imgur.com/E5Uqqfk.png' },
  { name: '奥特曼', url: 'https://i.imgur.com/3UgIUCZ.png' },
  { name: '委屈', url: 'https://i.imgur.com/z1UStbV.png' },
  { name: '干杯', url: 'https://i.imgur.com/savTxnM.png' },
  { name: '心碎', url: 'https://i.imgur.com/LMcbPfS.png' },
  { name: '打脸', url: 'https://i.imgur.com/hePLVvZ.png' },
  { name: '打脸滑稽', url: 'https://i.imgur.com/xgNoo8x.png' },
  { name: '托腮', url: 'https://i.imgur.com/rdq8HCd.png' },
  { name: '抱拳', url: 'https://i.imgur.com/NpZz2rJ.png' },
  { name: '捂嘴笑', url: 'https://i.imgur.com/zhwu7Iu.png' },
  { name: '机智', url: 'https://i.imgur.com/PwcbJI4.png' },
  { name: '流汗滑稽', url: 'https://i.imgur.com/P5gN5BH.png' },
  { name: '流泪', url: 'https://i.imgur.com/ZTr5z44.png' },
  { name: '滑稽', url: 'https://i.imgur.com/zRwC7aD.png' },
  { name: '牛啤', url: 'https://i.imgur.com/jP8z9va.png' },
  { name: '生气', url: 'https://i.imgur.com/36KFRac.png' },
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
  { name: '阴险', url: 'https://i.imgur.com/UdCZ5hH.png' },
  { name: '香蕉', url: 'https://i.imgur.com/fy7FxE8.png' },
  // B站 / 小红薯表情 (V2EX_Polish,维护中,全部存活)。
  { name: '脱单doge', url: 'https://i.imgur.com/L62ZP7V.png' },
  { name: 'doge', url: 'https://i.imgur.com/agAJ0Rd.png' },
  { name: '辣眼睛', url: 'https://i.imgur.com/n119Wvk.png' },
  { name: '疑惑', url: 'https://i.imgur.com/U3hKhrT.png' },
  { name: '捂脸', url: 'https://i.imgur.com/14cwgsI.png' },
  { name: '哦呼', url: 'https://i.imgur.com/km62MY2.png' },
  { name: '傲娇', url: 'https://i.imgur.com/TkdeN49.png' },
  { name: '思考', url: 'https://i.imgur.com/MAyk5GN.png' },
  { name: '吃瓜', url: 'https://i.imgur.com/Ug1iMq4.png' },
  { name: '无语', url: 'https://i.imgur.com/e1q9ScT.png' },
  { name: '大哭', url: 'https://i.imgur.com/YGIx7lh.png' },
  { name: '酸了', url: 'https://i.imgur.com/5FDsp6L.png' },
  { name: '打call', url: 'https://i.imgur.com/pmNOo2w.png' },
  { name: '歪嘴', url: 'https://i.imgur.com/XzEYBoY.png' },
  { name: '星星眼', url: 'https://i.imgur.com/2spsghH.png' },
  { name: 'OK', url: 'https://i.imgur.com/6DMydmQ.png' },
  { name: '跪了', url: 'https://i.imgur.com/TYtySHv.png' },
  { name: '响指', url: 'https://i.imgur.com/Ac88cMm.png' },
  { name: '调皮', url: 'https://i.imgur.com/O6ZZSLk.png' },
  { name: '笑哭', url: 'https://i.imgur.com/NIvxivj.png' },
  { name: '嗑瓜子', url: 'https://i.imgur.com/rjR4rdr.png' },
  { name: '喜极而泣', url: 'https://i.imgur.com/N9E3iZ2.png' },
  { name: '惊讶', url: 'https://i.imgur.com/aptfuiN.png' },
  { name: '给心心', url: 'https://i.imgur.com/4aXVwxJ.png' },
  { name: '呆', url: 'https://i.imgur.com/c1Q76Cd.png' },
  { name: '哭惹', url: 'https://i.imgur.com/HgxsUD2.png' },
  { name: '哇', url: 'https://i.imgur.com/OZySWIG.png' },
  { name: '汗颜', url: 'https://i.imgur.com/jrVZoLi.png' },
  { name: '害羞', url: 'https://i.imgur.com/OVQjxIr.png' },
  { name: '萌萌哒', url: 'https://i.imgur.com/Ue1kikn.png' },
  { name: '偷笑', url: 'https://i.imgur.com/aF7QiE5.png' },
]

/**
 * Sticker cell side (vp). Grounded in the body text, not picked arbitrarily: the inner emoji is the cell
 * minus its SPACE_XS padding on each side (36 - 8 = 28vp), which is ~1.5x the ~18vp body-text line — these
 * are small 黄豆/微博-style emoji that read alongside text, NOT large stickers. The same physical size renders
 * on every device because the column COUNT (not the cell size) adapts to the screen width (auto-stretch).
 */
const STICKER_CELL_VP: number = 36

/**
 * One sticker cell with its own load state, so each tile can show a skeleton placeholder until its network
 * image arrives. The built-in pack is imgur-hosted; on a cold cache the first open would otherwise render a
 * blank (no thumbnail, no spinner) which reads as "broken". @Trace loaded drives the per-cell skeleton.
 */
@ObservedV2
class StickerCell {
  name: string = ''
  url: string = ''
  @Trace loaded: boolean = false
}

/**
 * Chat-app style sticker grid, shown in place of the soft keyboard (the host collapses the IME and gives
 * this panel the keyboard's footprint). Tapping a sticker emits its name; the host inserts "[name]" at the
 * caret. Each cell shows a skeleton tile until its image loads. Phase 1 = one built-in pack.
 */
@ComponentV2
export struct StickerPickerPanel {
  @Param stickers: StickerItem[] = [];
  @Param panelHeight: number = 300;
  // Emits the sticker's NAME (the readable code, e.g. "doge"); the host inserts "[doge]" while editing and
  // expands codes to the bare image URL only on submit (keeps the text field readable).
  @Event onPick?: (name: string) => void;
  // Per-cell wrappers carrying @Trace loaded; rebuilt on each open (the panel is conditionally mounted, so
  // aboutToAppear runs every time it is shown and the skeletons reset).
  @Local private cells: StickerCell[] = [];
  // Bottom safe-area inset so the last sticker row clears the gesture bar when the panel fills to the edge.
  @Local private layout: LayoutSafeAreaState = connectLayoutSafeArea();

  aboutToAppear(): void {
    this.cells = this.stickers.map((s: StickerItem) => {
      const cell = new StickerCell()
      cell.name = s.name
      cell.url = s.url
      return cell
    })
  }

  build() {
    Grid() {
      ForEach(
        this.cells,
        (cell: StickerCell) => {
          GridItem() {
            Stack() {
              // Skeleton tile shown until the image loads; hidden afterwards so a transparent emoji isn't
              // left sitting on a grey chip.
              Column()
                .width('100%')
                .aspectRatio(1)
                .borderRadius(ThemeConstants.RADIUS_SM)
                .backgroundColor(ThemeConstants.BG_SUB)
                .visibility(cell.loaded ? Visibility.Hidden : Visibility.Visible)
              Image(cell.url)
                .width('100%')
                .aspectRatio(1)
                .objectFit(ImageFit.Contain)
                .draggable(false)
                .borderRadius(ThemeConstants.RADIUS_SM)
                .onComplete(() => {
                  cell.loaded = true
                })
                .onError(() => {
                  cell.loaded = true
                })
            }
          }
          // Small inset so the sticker has breathing room inside its fixed-size cell.
          .padding(ThemeConstants.SPACE_XS)
          .onClick(() => {
            if (this.onPick) {
              this.onPick(cell.name)
            }
          })
        },
        (cell: StickerCell) => cell.url,
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
