import { display } from '@kit.ArkUI'
import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { StickerItem, StickerGroup } from '../model/StickerTypes'

/**
 * Built-in packs (URL-referenced imgur images, nothing bundled). Three groups:
 *  1) QQEMO_STICKERS — the QQ Face Telegram custom-emoji pack (t.me/addemoji/QQEmo), re-hosted as ANIMATED
 *     42px transparent GIFs (each source .webm transcoded via ffmpeg). GIF is the only animated format that
 *     works end-to-end: a V2EX REPLY auto-embeds a bare image only from a tiny host whitelist (imgur, in
 *     practice), and imgur rejects webp — so animation can only ride a GIF. The app's Image plays it inline.
 *  2) BILI_STICKERS — the real Bilibili emote set (re-hosted from i0.hdslb.com PNGs to imgur), 42px, static.
 *     Replaced the old, blurry V2EX_Polish set.
 *  3) CLASSIC_STICKERS — the classic V2EX 黄豆 / 表情党 set (huage2580/v2ex_emoji, names per its map.txt),
 *     42px, static. The 13 names it shares with the B站 set were dropped here and kept only in the B站 set
 *     (a "[name]" code maps to exactly one URL, so a name lives in one group only).
 * Names are unique across all groups so the flattened "[name]"->url map (BUILTIN_STICKERS) has no clash.
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
  { name: 'doge_金箍', url: 'https://i.imgur.com/vrOYBWq.png' },
  { name: '笑哭', url: 'https://i.imgur.com/fqkZvoG.png' },
  { name: '蹲蹲', url: 'https://i.imgur.com/z9q3bNd.png' },
  { name: '星星眼', url: 'https://i.imgur.com/xNBxKuw.png' },
  { name: '微笑', url: 'https://i.imgur.com/16aiU84.png' },
  { name: '吃瓜', url: 'https://i.imgur.com/YMwuW0B.png' },
  { name: '打call', url: 'https://i.imgur.com/3VgVdau.png' },
  { name: 'OK', url: 'https://i.imgur.com/ZpeGBwa.png' },
  { name: 'doge', url: 'https://i.imgur.com/lBaf5Br.png' },
  { name: '大哭', url: 'https://i.imgur.com/LTbXyAI.png' },
  { name: '辣眼睛', url: 'https://i.imgur.com/5luMqfL.png' },
  { name: '滑稽', url: 'https://i.imgur.com/sINJDvS.png' },
  { name: '喜极而泣', url: 'https://i.imgur.com/96PcESt.png' },
  { name: '呲牙', url: 'https://i.imgur.com/PIxxva5.png' },
  { name: '歪嘴', url: 'https://i.imgur.com/NWJ4Osz.png' },
  { name: '调皮', url: 'https://i.imgur.com/UER8JEQ.png' },
  { name: '妙啊', url: 'https://i.imgur.com/r93R6Jv.png' },
  { name: '嗑瓜子', url: 'https://i.imgur.com/2Hno1ER.png' },
  { name: '藏狐', url: 'https://i.imgur.com/qjDqR6k.png' },
  { name: '脱单doge', url: 'https://i.imgur.com/0mZd4Cb.png' },
  { name: '笑', url: 'https://i.imgur.com/SS0XVSG.png' },
  { name: '给心心', url: 'https://i.imgur.com/4D7bALq.png' },
  { name: '脸红', url: 'https://i.imgur.com/wnPpe0K.png' },
  { name: '嘟嘟', url: 'https://i.imgur.com/Skp2bD9.png' },
  { name: '哦呼', url: 'https://i.imgur.com/dHmVbpE.png' },
  { name: '喜欢', url: 'https://i.imgur.com/GVMFq3B.png' },
  { name: '酸了', url: 'https://i.imgur.com/40w5ity.png' },
  { name: '害羞', url: 'https://i.imgur.com/TBc3c2m.png' },
  { name: '嫌弃', url: 'https://i.imgur.com/uh0X0df.png' },
  { name: '疑惑', url: 'https://i.imgur.com/OZRpoFu.png' },
  { name: '偷笑', url: 'https://i.imgur.com/U2Odn6p.png' },
  { name: '惊讶', url: 'https://i.imgur.com/IZxwSyJ.png' },
  { name: '捂脸', url: 'https://i.imgur.com/K6IR3Za.png' },
  { name: '阴险', url: 'https://i.imgur.com/YUaYdBn.png' },
  { name: '呆', url: 'https://i.imgur.com/YnGpJKV.png' },
  { name: '抠鼻', url: 'https://i.imgur.com/0fywNMC.png' },
  { name: '大笑', url: 'https://i.imgur.com/Vr8taf1.png' },
  { name: '惊喜', url: 'https://i.imgur.com/PPCND8m.png' },
  { name: '点赞', url: 'https://i.imgur.com/uJkUrEX.png' },
  { name: '无语', url: 'https://i.imgur.com/KsYezmq.png' },
  { name: '鼓掌', url: 'https://i.imgur.com/pPhuTqT.png' },
  { name: '尴尬', url: 'https://i.imgur.com/sexfhiu.png' },
  { name: '灵魂出窍', url: 'https://i.imgur.com/yiEI6O5.png' },
  { name: '傲娇', url: 'https://i.imgur.com/eGhwCU2.png' },
  { name: '委屈', url: 'https://i.imgur.com/baPRQz7.png' },
  { name: '疼', url: 'https://i.imgur.com/dG2dSBg.png' },
  { name: '冷', url: 'https://i.imgur.com/JULoj3M.png' },
  { name: '热', url: 'https://i.imgur.com/M2AmwBt.png' },
  { name: '生病', url: 'https://i.imgur.com/44PjvHq.png' },
  { name: '生气', url: 'https://i.imgur.com/DZvAUoV.png' },
  { name: '捂眼', url: 'https://i.imgur.com/eEI5lRD.png' },
  { name: '嘘声', url: 'https://i.imgur.com/wkSGLxd.png' },
  { name: '思考', url: 'https://i.imgur.com/OeqwsGS.png' },
  { name: '再见', url: 'https://i.imgur.com/mDjHYF5.png' },
  { name: '翻白眼', url: 'https://i.imgur.com/d2M4kXh.png' },
  { name: '抓狂', url: 'https://i.imgur.com/iO4L5BC.png' },
  { name: '哈欠', url: 'https://i.imgur.com/ROD865T.png' },
  { name: '奋斗', url: 'https://i.imgur.com/5cQGDay.png' },
  { name: '墨镜', url: 'https://i.imgur.com/bKimyXL.png' },
  { name: '难过', url: 'https://i.imgur.com/cQyJuxX.png' },
  { name: '口罩', url: 'https://i.imgur.com/0flAEGX.png' },
  { name: '撇嘴', url: 'https://i.imgur.com/v1UNECM.png' },
  { name: '黑眼圈_金箍', url: 'https://i.imgur.com/fv52yWi.png' },
  { name: '猴哥', url: 'https://i.imgur.com/TYPzblB.png' },
  { name: '鸭科夫_流汗鸭', url: 'https://i.imgur.com/A7OSZYJ.png' },
  { name: '鸭科夫_干嘛鸭', url: 'https://i.imgur.com/8bYEbEk.png' },
  { name: '鸭科夫_红温鸭', url: 'https://i.imgur.com/IsLH9F2.png' },
  { name: '黑猫', url: 'https://i.imgur.com/I09CfQ6.png' },
  { name: '三花猫', url: 'https://i.imgur.com/BosgSlo.png' },
  { name: '折耳猫', url: 'https://i.imgur.com/D7pqnUM.png' },
  { name: '银魂_justaway', url: 'https://i.imgur.com/pehIqsw.png' },
  { name: '我独自升级_疑惑', url: 'https://i.imgur.com/iADPT9a.png' },
  { name: '怪兽8号_奇可露', url: 'https://i.imgur.com/iMIpiOK.png' },
  { name: '颂乐人偶_眯眼笑', url: 'https://i.imgur.com/rf4poU3.png' },
  { name: '坂本_佛系', url: 'https://i.imgur.com/HA3WKzJ.png' },
  { name: '生气_金箍', url: 'https://i.imgur.com/e5yhs7Z.png' },
  { name: '龙年', url: 'https://i.imgur.com/ORWYkoo.png' },
  { name: '豹富', url: 'https://i.imgur.com/VRudLdp.png' },
  { name: '兔兔岛_开心', url: 'https://i.imgur.com/VxEMUL5.png' },
  { name: '兔兔岛_吃面', url: 'https://i.imgur.com/OKsBFrm.png' },
  { name: '兔兔岛_睡觉', url: 'https://i.imgur.com/yHKsvLO.png' },
  { name: '重返未来1999_喂', url: 'https://i.imgur.com/UEhSRj2.png' },
  { name: '重返未来1999_赞', url: 'https://i.imgur.com/sEGulPn.png' },
  { name: '重返未来1999_谢谢老板', url: 'https://i.imgur.com/tYXOEuL.png' },
  { name: '重返未来1999_什么', url: 'https://i.imgur.com/pCaD9Lj.png' },
  { name: '胆大党_微笑', url: 'https://i.imgur.com/qLuHxcA.png' },
  { name: '水稻', url: 'https://i.imgur.com/omcU5Qg.png' },
  { name: '奶茶干杯', url: 'https://i.imgur.com/L6Tsq0c.png' },
  { name: '汤圆', url: 'https://i.imgur.com/F2IRYPd.png' },
  { name: '锦鲤', url: 'https://i.imgur.com/lb25JKH.png' },
  { name: '福到了', url: 'https://i.imgur.com/gpJAkkM.png' },
  { name: '鸡腿', url: 'https://i.imgur.com/fyw5DE5.png' },
  { name: '雪花', url: 'https://i.imgur.com/Rgy7p59.png' },
  { name: '视频卫星', url: 'https://i.imgur.com/KYZ2Psh.png' },
  { name: '干杯', url: 'https://i.imgur.com/OWBhSsX.png' },
  { name: '黑洞', url: 'https://i.imgur.com/adExHaO.png' },
  { name: '爱心', url: 'https://i.imgur.com/yknPzKv.png' },
  { name: '胜利', url: 'https://i.imgur.com/AwmdrQW.png' },
  { name: '加油', url: 'https://i.imgur.com/x91W7ir.png' },
  { name: '抱拳', url: 'https://i.imgur.com/KTbbmIo.png' },
  { name: '响指', url: 'https://i.imgur.com/6IbTvWN.png' },
  { name: '保佑', url: 'https://i.imgur.com/qGBmsA7.png' },
  { name: '福', url: 'https://i.imgur.com/VOiBEAA.png' },
  { name: '支持', url: 'https://i.imgur.com/IO564cS.png' },
  { name: '拥抱', url: 'https://i.imgur.com/eCLi1cL.png' },
  { name: '跪了', url: 'https://i.imgur.com/SbCyiHT.png' },
  { name: '怪我咯', url: 'https://i.imgur.com/gEkSsaP.png' },
]

const QQEMO_STICKERS: StickerItem[] = [
  { name: 'qqemo_001', url: 'https://i.imgur.com/mZfm2cj.gif' },
  { name: 'qqemo_002', url: 'https://i.imgur.com/rSTLxSf.gif' },
  { name: 'qqemo_003', url: 'https://i.imgur.com/3lnIm59.gif' },
  { name: 'qqemo_004', url: 'https://i.imgur.com/dA3cXbo.gif' },
  { name: 'qqemo_005', url: 'https://i.imgur.com/WLFqC6d.gif' },
  { name: 'qqemo_006', url: 'https://i.imgur.com/j8Vdcfw.gif' },
  { name: 'qqemo_007', url: 'https://i.imgur.com/mfbEQOb.gif' },
  { name: 'qqemo_008', url: 'https://i.imgur.com/MN8Tn2e.gif' },
  { name: 'qqemo_009', url: 'https://i.imgur.com/eaUwHlc.gif' },
  { name: 'qqemo_010', url: 'https://i.imgur.com/dMVOhCG.gif' },
  { name: 'qqemo_011', url: 'https://i.imgur.com/1JRvlPv.gif' },
  { name: 'qqemo_012', url: 'https://i.imgur.com/S9oDURA.gif' },
  { name: 'qqemo_013', url: 'https://i.imgur.com/826AJ3z.gif' },
  { name: 'qqemo_014', url: 'https://i.imgur.com/YVTwv8O.gif' },
  { name: 'qqemo_015', url: 'https://i.imgur.com/QZ5BNhL.gif' },
  { name: 'qqemo_016', url: 'https://i.imgur.com/0HfDMPq.gif' },
  { name: 'qqemo_017', url: 'https://i.imgur.com/fHjoLxV.gif' },
  { name: 'qqemo_018', url: 'https://i.imgur.com/WjlosCy.gif' },
  { name: 'qqemo_019', url: 'https://i.imgur.com/vl1bPbN.gif' },
  { name: 'qqemo_020', url: 'https://i.imgur.com/rQxnSXS.gif' },
  { name: 'qqemo_021', url: 'https://i.imgur.com/ZRjrFmc.gif' },
  { name: 'qqemo_022', url: 'https://i.imgur.com/qPTfTJX.gif' },
  { name: 'qqemo_023', url: 'https://i.imgur.com/U7bWwM1.gif' },
  { name: 'qqemo_024', url: 'https://i.imgur.com/mJQxgAN.gif' },
  { name: 'qqemo_025', url: 'https://i.imgur.com/IS4Tvlr.gif' },
  { name: 'qqemo_026', url: 'https://i.imgur.com/w7yapx5.gif' },
  { name: 'qqemo_027', url: 'https://i.imgur.com/t8sJXfR.gif' },
  { name: 'qqemo_028', url: 'https://i.imgur.com/GChTiKW.gif' },
  { name: 'qqemo_029', url: 'https://i.imgur.com/nR8PrEe.gif' },
  { name: 'qqemo_030', url: 'https://i.imgur.com/sa8sOvG.gif' },
  { name: 'qqemo_031', url: 'https://i.imgur.com/s7CSliR.gif' },
  { name: 'qqemo_032', url: 'https://i.imgur.com/ENloOaD.gif' },
  { name: 'qqemo_033', url: 'https://i.imgur.com/wstcXoC.gif' },
  { name: 'qqemo_034', url: 'https://i.imgur.com/sTYeCf1.gif' },
  { name: 'qqemo_035', url: 'https://i.imgur.com/KRJmLPu.gif' },
  { name: 'qqemo_036', url: 'https://i.imgur.com/POwpmb1.gif' },
  { name: 'qqemo_037', url: 'https://i.imgur.com/sdSCeaa.gif' },
  { name: 'qqemo_038', url: 'https://i.imgur.com/S6H9yQ4.gif' },
  { name: 'qqemo_039', url: 'https://i.imgur.com/syWGDtO.gif' },
  { name: 'qqemo_040', url: 'https://i.imgur.com/59r4JhO.gif' },
  { name: 'qqemo_041', url: 'https://i.imgur.com/1rU0PCU.gif' },
  { name: 'qqemo_042', url: 'https://i.imgur.com/0zlZJd6.gif' },
  { name: 'qqemo_043', url: 'https://i.imgur.com/Yz20Jfn.gif' },
  { name: 'qqemo_044', url: 'https://i.imgur.com/lCbgdok.gif' },
  { name: 'qqemo_045', url: 'https://i.imgur.com/3tCIXd4.gif' },
  { name: 'qqemo_046', url: 'https://i.imgur.com/gCa13lf.gif' },
  { name: 'qqemo_047', url: 'https://i.imgur.com/cRyzvmu.gif' },
  { name: 'qqemo_048', url: 'https://i.imgur.com/R13KQwJ.gif' },
  { name: 'qqemo_049', url: 'https://i.imgur.com/V7edtb5.gif' },
  { name: 'qqemo_050', url: 'https://i.imgur.com/pYscWaw.gif' },
  { name: 'qqemo_051', url: 'https://i.imgur.com/K2etVMj.gif' },
  { name: 'qqemo_052', url: 'https://i.imgur.com/GFFMrsd.gif' },
  { name: 'qqemo_053', url: 'https://i.imgur.com/7ceQcdV.gif' },
  { name: 'qqemo_054', url: 'https://i.imgur.com/ktDSnlg.gif' },
  { name: 'qqemo_055', url: 'https://i.imgur.com/d1n2BaF.gif' },
  { name: 'qqemo_056', url: 'https://i.imgur.com/pqedzYj.gif' },
  { name: 'qqemo_057', url: 'https://i.imgur.com/lJPRAuj.gif' },
  { name: 'qqemo_058', url: 'https://i.imgur.com/YdKjXYC.gif' },
  { name: 'qqemo_059', url: 'https://i.imgur.com/WuiLL89.gif' },
  { name: 'qqemo_060', url: 'https://i.imgur.com/v9iqKMG.gif' },
  { name: 'qqemo_061', url: 'https://i.imgur.com/fpzkhvj.gif' },
  { name: 'qqemo_062', url: 'https://i.imgur.com/cvk3FnY.gif' },
  { name: 'qqemo_063', url: 'https://i.imgur.com/jO5yGZb.gif' },
  { name: 'qqemo_064', url: 'https://i.imgur.com/npOmBYu.gif' },
  { name: 'qqemo_065', url: 'https://i.imgur.com/qxD6QcG.gif' },
  { name: 'qqemo_066', url: 'https://i.imgur.com/xJY3xmP.gif' },
  { name: 'qqemo_067', url: 'https://i.imgur.com/TBN4ZbY.gif' },
  { name: 'qqemo_068', url: 'https://i.imgur.com/mGS3Yt4.gif' },
  { name: 'qqemo_069', url: 'https://i.imgur.com/zleycJm.gif' },
  { name: 'qqemo_070', url: 'https://i.imgur.com/SvxM1jQ.gif' },
  { name: 'qqemo_071', url: 'https://i.imgur.com/5S65IPR.gif' },
  { name: 'qqemo_072', url: 'https://i.imgur.com/RtYZYeW.gif' },
  { name: 'qqemo_073', url: 'https://i.imgur.com/ZEhiqXS.gif' },
  { name: 'qqemo_074', url: 'https://i.imgur.com/n3TpjVS.gif' },
  { name: 'qqemo_075', url: 'https://i.imgur.com/FxHVNhP.gif' },
  { name: 'qqemo_076', url: 'https://i.imgur.com/dvMa83b.gif' },
  { name: 'qqemo_077', url: 'https://i.imgur.com/IITmNOj.gif' },
  { name: 'qqemo_078', url: 'https://i.imgur.com/X5R1j43.gif' },
  { name: 'qqemo_079', url: 'https://i.imgur.com/KXFNqhS.gif' },
  { name: 'qqemo_080', url: 'https://i.imgur.com/OUgvIdD.gif' },
  { name: 'qqemo_081', url: 'https://i.imgur.com/qaepr6B.gif' },
  { name: 'qqemo_082', url: 'https://i.imgur.com/eHZEYUQ.gif' },
  { name: 'qqemo_083', url: 'https://i.imgur.com/LVpBURN.gif' },
  { name: 'qqemo_084', url: 'https://i.imgur.com/yPY203q.gif' },
  { name: 'qqemo_085', url: 'https://i.imgur.com/37IrCZp.gif' },
  { name: 'qqemo_086', url: 'https://i.imgur.com/1DZZ7vM.gif' },
  { name: 'qqemo_087', url: 'https://i.imgur.com/jmcqKrt.gif' },
  { name: 'qqemo_088', url: 'https://i.imgur.com/4cCKwH8.gif' },
  { name: 'qqemo_089', url: 'https://i.imgur.com/MEWWuE3.gif' },
  { name: 'qqemo_090', url: 'https://i.imgur.com/KXxD9Tz.gif' },
  { name: 'qqemo_091', url: 'https://i.imgur.com/Ej41mXg.gif' },
  { name: 'qqemo_092', url: 'https://i.imgur.com/ECqJe6T.gif' },
  { name: 'qqemo_093', url: 'https://i.imgur.com/MItgw3c.gif' },
  { name: 'qqemo_094', url: 'https://i.imgur.com/rqwgytX.gif' },
  { name: 'qqemo_095', url: 'https://i.imgur.com/smYMuDH.gif' },
  { name: 'qqemo_096', url: 'https://i.imgur.com/qJPXnzV.gif' },
  { name: 'qqemo_097', url: 'https://i.imgur.com/uMfT3A9.gif' },
  { name: 'qqemo_098', url: 'https://i.imgur.com/sfakZ4o.gif' },
  { name: 'qqemo_099', url: 'https://i.imgur.com/MwrbPuw.gif' },
  { name: 'qqemo_100', url: 'https://i.imgur.com/6f0gLZ4.gif' },
  { name: 'qqemo_101', url: 'https://i.imgur.com/RtXDfLd.gif' },
  { name: 'qqemo_102', url: 'https://i.imgur.com/ZrVVNWU.gif' },
  { name: 'qqemo_103', url: 'https://i.imgur.com/nalPAey.gif' },
  { name: 'qqemo_104', url: 'https://i.imgur.com/94wX5CQ.gif' },
  { name: 'qqemo_105', url: 'https://i.imgur.com/Uyb4Thy.gif' },
  { name: 'qqemo_106', url: 'https://i.imgur.com/6FKxvcT.gif' },
  { name: 'qqemo_107', url: 'https://i.imgur.com/r1ZAe6G.gif' },
  { name: 'qqemo_108', url: 'https://i.imgur.com/B3itAgu.gif' },
  { name: 'qqemo_109', url: 'https://i.imgur.com/yGYQcJb.gif' },
  { name: 'qqemo_110', url: 'https://i.imgur.com/Rc8N0el.gif' },
  { name: 'qqemo_111', url: 'https://i.imgur.com/PiNDnT8.gif' },
  { name: 'qqemo_112', url: 'https://i.imgur.com/Q4CoCs6.gif' },
  { name: 'qqemo_113', url: 'https://i.imgur.com/NcQYMRp.gif' },
  { name: 'qqemo_114', url: 'https://i.imgur.com/E914pSj.gif' },
  { name: 'qqemo_115', url: 'https://i.imgur.com/ONqMe3M.gif' },
  { name: 'qqemo_116', url: 'https://i.imgur.com/QvEnkaw.gif' },
  { name: 'qqemo_117', url: 'https://i.imgur.com/QFpOIkG.gif' },
  { name: 'qqemo_118', url: 'https://i.imgur.com/8Db3Q8N.gif' },
  { name: 'qqemo_119', url: 'https://i.imgur.com/rPceTCu.gif' },
  { name: 'qqemo_120', url: 'https://i.imgur.com/s0MnoMY.gif' },
  { name: 'qqemo_121', url: 'https://i.imgur.com/AOrXVOq.gif' },
  { name: 'qqemo_122', url: 'https://i.imgur.com/j2cRDrV.gif' },
  { name: 'qqemo_123', url: 'https://i.imgur.com/hBF9qHx.gif' },
  { name: 'qqemo_124', url: 'https://i.imgur.com/l0rp13Z.gif' },
  { name: 'qqemo_125', url: 'https://i.imgur.com/TPf067n.gif' },
  { name: 'qqemo_126', url: 'https://i.imgur.com/nJKXXso.gif' },
  { name: 'qqemo_127', url: 'https://i.imgur.com/sSuLXDO.gif' },
  { name: 'qqemo_128', url: 'https://i.imgur.com/gt0oTHf.gif' },
  { name: 'qqemo_129', url: 'https://i.imgur.com/AND6DSF.gif' },
  { name: 'qqemo_130', url: 'https://i.imgur.com/N0fnMpB.gif' },
  { name: 'qqemo_131', url: 'https://i.imgur.com/JXEAKaQ.gif' },
  { name: 'qqemo_132', url: 'https://i.imgur.com/ATo4FgO.gif' },
  { name: 'qqemo_133', url: 'https://i.imgur.com/AZwMzRh.gif' },
  { name: 'qqemo_134', url: 'https://i.imgur.com/UYbq8GZ.gif' },
  { name: 'qqemo_135', url: 'https://i.imgur.com/tffgtNr.gif' },
  { name: 'qqemo_136', url: 'https://i.imgur.com/rRks05x.gif' },
  { name: 'qqemo_137', url: 'https://i.imgur.com/nJaxUhx.gif' },
  { name: 'qqemo_138', url: 'https://i.imgur.com/jYyALsl.gif' },
  { name: 'qqemo_139', url: 'https://i.imgur.com/FFtm3Ir.gif' },
  { name: 'qqemo_140', url: 'https://i.imgur.com/1iHiNTD.gif' },
  { name: 'qqemo_141', url: 'https://i.imgur.com/RhF6Vid.gif' },
  { name: 'qqemo_142', url: 'https://i.imgur.com/3yITDzJ.gif' },
  { name: 'qqemo_143', url: 'https://i.imgur.com/VU7DL3z.gif' },
  { name: 'qqemo_144', url: 'https://i.imgur.com/SrILDcq.gif' },
  { name: 'qqemo_145', url: 'https://i.imgur.com/ygWXRQT.gif' },
  { name: 'qqemo_146', url: 'https://i.imgur.com/xKzPrzW.gif' },
  { name: 'qqemo_147', url: 'https://i.imgur.com/1Qq5VaM.gif' },
  { name: 'qqemo_148', url: 'https://i.imgur.com/pIxYgjZ.gif' },
  { name: 'qqemo_149', url: 'https://i.imgur.com/foF2Slv.gif' },
  { name: 'qqemo_150', url: 'https://i.imgur.com/dynSupX.gif' },
  { name: 'qqemo_151', url: 'https://i.imgur.com/2zvL4Cd.gif' },
  { name: 'qqemo_152', url: 'https://i.imgur.com/D5V91An.gif' },
  { name: 'qqemo_153', url: 'https://i.imgur.com/b8Gquvx.gif' },
  { name: 'qqemo_154', url: 'https://i.imgur.com/tk8wdf4.gif' },
  { name: 'qqemo_155', url: 'https://i.imgur.com/mz2HXMG.gif' },
  { name: 'qqemo_156', url: 'https://i.imgur.com/ITjriqs.gif' },
  { name: 'qqemo_157', url: 'https://i.imgur.com/MP3FAPJ.gif' },
  { name: 'qqemo_158', url: 'https://i.imgur.com/JpcfhaR.gif' },
  { name: 'qqemo_159', url: 'https://i.imgur.com/kCRFjnV.gif' },
  { name: 'qqemo_160', url: 'https://i.imgur.com/6MMwJyX.gif' },
  { name: 'qqemo_161', url: 'https://i.imgur.com/s4EmgHi.gif' },
  { name: 'qqemo_162', url: 'https://i.imgur.com/Csts2tQ.gif' },
  { name: 'qqemo_163', url: 'https://i.imgur.com/MXbU4gP.gif' },
  { name: 'qqemo_164', url: 'https://i.imgur.com/atiKq1Q.gif' },
  { name: 'qqemo_165', url: 'https://i.imgur.com/3wfSPGf.gif' },
  { name: 'qqemo_166', url: 'https://i.imgur.com/Pn5fSVb.gif' },
  { name: 'qqemo_167', url: 'https://i.imgur.com/Oe0SoVN.gif' },
  { name: 'qqemo_168', url: 'https://i.imgur.com/Cch7lpU.gif' },
  { name: 'qqemo_169', url: 'https://i.imgur.com/O5rtYuX.gif' },
  { name: 'qqemo_170', url: 'https://i.imgur.com/oo3Yz0N.gif' },
  { name: 'qqemo_171', url: 'https://i.imgur.com/p6t72RK.gif' },
  { name: 'qqemo_172', url: 'https://i.imgur.com/rmvik80.gif' },
  { name: 'qqemo_173', url: 'https://i.imgur.com/RJOEMH5.gif' },
  { name: 'qqemo_174', url: 'https://i.imgur.com/Ro11JiO.gif' },
  { name: 'qqemo_175', url: 'https://i.imgur.com/v8zo20S.gif' },
  { name: 'qqemo_176', url: 'https://i.imgur.com/r1n585D.gif' },
  { name: 'qqemo_177', url: 'https://i.imgur.com/SN2SaS7.gif' },
  { name: 'qqemo_178', url: 'https://i.imgur.com/v4WA1sv.gif' },
  { name: 'qqemo_179', url: 'https://i.imgur.com/q4COPyD.gif' },
  { name: 'qqemo_180', url: 'https://i.imgur.com/G18WtB9.gif' },
  { name: 'qqemo_181', url: 'https://i.imgur.com/I9y0gPN.gif' },
  { name: 'qqemo_182', url: 'https://i.imgur.com/jRZI8Km.gif' },
  { name: 'qqemo_183', url: 'https://i.imgur.com/4h8bcpY.gif' },
  { name: 'qqemo_184', url: 'https://i.imgur.com/EhfuEjE.gif' },
  { name: 'qqemo_185', url: 'https://i.imgur.com/8QogRle.gif' },
  { name: 'qqemo_186', url: 'https://i.imgur.com/vcllVnS.gif' },
  { name: 'qqemo_187', url: 'https://i.imgur.com/PDf7dPg.gif' },
  { name: 'qqemo_188', url: 'https://i.imgur.com/TI8VmVw.gif' },
  { name: 'qqemo_189', url: 'https://i.imgur.com/iAlk7Ib.gif' },
]

export const BUILTIN_STICKER_GROUPS: StickerGroup[] = [
  { key: 'qqemo', stickers: QQEMO_STICKERS },
  { key: 'bili', stickers: BILI_STICKERS },
  { key: 'classic', stickers: CLASSIC_STICKERS },
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
 * Backs the picker's Grid via LazyForEach so only on-screen (+ a small cache) cells are built — critical now
 * that a pack can be 100+ ANIMATED GIFs: a plain ForEach mounts every cell, so all GIFs decode and animate at
 * once (~600MB RSS while open). LazyForEach keeps just the visible window alive, so off-screen GIFs are not
 * decoded or animated. Entries are a one-shot snapshot per open (set before build), so no incremental
 * mutations — setEntries simply reloads.
 */
class GridEntryDataSource implements IDataSource {
  private entries: GridEntry[] = []
  private listeners: DataChangeListener[] = []

  setEntries(entries: GridEntry[]): void {
    this.entries = entries
    this.listeners.forEach((listener: DataChangeListener) => listener.onDataReloaded())
  }

  totalCount(): number {
    return this.entries.length
  }

  getData(index: number): GridEntry {
    return this.entries[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }
}

/**
 * Chat-app style sticker grid, shown in place of the soft keyboard (the host collapses the IME and gives
 * this panel the keyboard's footprint). Tapping a sticker emits its name; the host inserts "[name]" at the
 * caret. Each cell shows a skeleton tile until its image loads. Groups are separated by a full-row hairline.
 */
@ComponentV2
export struct StickerPickerPanel {
  @Param groups: StickerGroup[] = [];
  // Most-recent-first recently-used stickers; the panel prepends a "recent" group capped to two rows (the
  // count is sliced to the live column count). Snapshotted at aboutToAppear so a pick does not reshuffle the
  // open grid; the next open reflects it. Empty -> no recent group (and no leading separator).
  @Param recent: StickerItem[] = [];
  @Param panelHeight: number = 300;
  // Emits the picked sticker (name + url); the host inserts "[name]" while editing, expands codes to the bare
  // URL only on submit (keeps the text field readable), and records the pick into the recent list.
  @Event onPick?: (item: StickerItem) => void;
  // Flattened render list (group-1 cells, a separator, group-2 cells, ...) behind a LazyForEach data source,
  // so only the on-screen window of cells is built (see GridEntryDataSource). Filled once in aboutToAppear;
  // the panel is conditionally mounted, so that runs on every open.
  private dataSource: GridEntryDataSource = new GridEntryDataSource();
  // Bottom safe-area inset so the last sticker row clears the gesture bar when the panel fills to the edge.
  @Local private layout: LayoutSafeAreaState = connectLayoutSafeArea();
  private scroller: Scroller = new Scroller();
  // regularSize keeps normal cells 1x1; irregularIndexes marks the separator rows, which then default to a
  // full row of a vertically-scrolling Grid (only columnsTemplate set) — that is what makes the next group
  // start on a fresh row. Filled in aboutToAppear from the actual group sizes.
  private gridOptions: GridLayoutOptions = { regularSize: [1, 1], irregularIndexes: [] };

  // The recent tray is a SNAPSHOT taken once per open (here), not live: a pick records into the holder but the
  // open grid does NOT reshuffle under the user's finger — the next open reflects it. (The panel is
  // conditionally mounted, so aboutToAppear runs on every open and re-reads the latest recent list.)
  aboutToAppear(): void {
    const list: GridEntry[] = []
    const separators: number[] = []
    this.effectiveGroups().forEach((group: StickerGroup) => {
      // Separator only BETWEEN two non-empty groups: it needs preceding cells (list.length > 0) and at least
      // one cell of its own to follow (group.stickers.length > 0). Guarding alone would leave a dangling /
      // leading hairline when any group is empty.
      if (list.length > 0 && group.stickers.length > 0) {
        const sep = new GridEntry()
        sep.isSeparator = true
        sep.key = `sep-${group.key}`
        separators.push(list.length)
        list.push(sep)
      }
      group.stickers.forEach((sticker: StickerItem) => {
        const cell = new GridEntry()
        cell.name = sticker.name
        cell.url = sticker.url
        // Key is group-scoped (not bare url): a recent sticker also lives in its origin group, so the same
        // url renders twice in the grid — bare-url keys would collide in ForEach.
        cell.key = `${group.key}:${sticker.url}`
        list.push(cell)
      })
    })
    this.dataSource.setEntries(list)
    this.gridOptions = { regularSize: [1, 1], irregularIndexes: separators }
  }

  // [recent (<=2 rows), ...groups]. The recent group is prepended only when non-empty (otherwise the
  // separator guard already drops it). Recent is sliced to exactly two rows for the live column count so it
  // stays a compact tray rather than growing without bound as the user picks more.
  private effectiveGroups(): StickerGroup[] {
    const result: StickerGroup[] = []
    const limit = 2 * this.maxColumns()
    const recentSlice =
      this.recent.length > limit ? this.recent.slice(0, limit) : this.recent.slice()
    if (recentSlice.length > 0) {
      result.push({ key: 'recent', stickers: recentSlice })
    }
    for (const group of this.groups) {
      result.push(group)
    }
    return result
  }

  // The auto-stretch column count the grid will compute for the full-width panel: floor((W + gap) /
  // (cell + gap)) where W is the content width (screen width minus the grid's side padding). Mirrors the
  // framework's repeat(auto-stretch, cell) math so the recent slice lands on exactly two rows. Falls back to
  // a sane default if the display query fails.
  private maxColumns(): number {
    try {
      const info = display.getDefaultDisplaySync()
      const widthVp = info.densityPixels > 0 ? info.width / info.densityPixels : 0
      const content = widthVp - 2 * ThemeConstants.SPACE_LG
      const cols = Math.floor(
        (content + ThemeConstants.SPACE_SM) / (STICKER_CELL_VP + ThemeConstants.SPACE_SM),
      )
      return cols > 0 ? cols : 8
    } catch (err) {
      return 8
    }
  }

  build() {
    Grid(this.scroller, this.gridOptions) {
      LazyForEach(
        this.dataSource,
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
                const picked: StickerItem = { name: entry.name, url: entry.url }
                this.onPick(picked)
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
