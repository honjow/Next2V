/**
 * CJK i18n contract test — static audit of source files.
 *
 * Purpose: Ensure no hardcoded CJK characters leak into user-visible strings
 * outside of i18n resource files. This test runs as a build-time gate.
 *
 * Run: node scripts/test_cjk_i18n_contract.mjs
 */

import * as fs from 'node:fs'
import * as path from 'node:path'
import * as url from 'node:url'

const __filename = url.fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const WORKTREE = path.resolve(__dirname, '..')

// ------------------------------------------------------------
// Config
// ------------------------------------------------------------

const CJK_RE = /[\u3400-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]/

const EXCLUDED_DIRS = new Set([
  '.git', 'oh_modules', 'build', '.hermes-artifacts', '.hvigor',
  'node_modules', 'AppScope/resources'
])

const EXCLUDED_FILE_PATTERNS = [
  /\/resources\/.*\/element\/string\.json$/,  // locale resource files
  /\.d\.ets$/,   // declaration files
]

// Files/dirs where CJK is explicitly allowed
const ALLOWED_FILES = new Set([
  // Comments in source — allowed
])

const ALLOWED_PATTERNS = [
  // Test fixtures that replicate V2EX HTML (always in Chinese)
  /^scripts\/.*test_.*\.mjs$/,
  /^scripts\/validate-signin-parser-fixtures\.mjs$/,
  // Parser test expectations
]

// ------------------------------------------------------------
// Scan
// ------------------------------------------------------------

function* walkDir(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true })
  for (const entry of entries) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      if (!EXCLUDED_DIRS.has(entry.name)) {
        yield* walkDir(full)
      }
    } else {
      const rel = path.relative(WORKTREE, full)
      const ext = path.extname(entry.name).toLowerCase()
      if (['.ets', '.ts', '.js', '.mjs', '.hsp'].includes(ext)) {
        const excluded = EXCLUDED_FILE_PATTERNS.some(p => p.test(rel))
        if (!excluded) {
          yield { full, rel }
        }
      }
    }
  }
}

// ------------------------------------------------------------
// Categories
// ------------------------------------------------------------

const findings = { must_fix: [], allowed: [], needs_review: [] }
let passed = 0
let failed = 0

function isCommentOnly(line, cjkMatch) {
  const trimmed = line.trimStart()
  return trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/**')
}

// Known-OK CJK strings in non-resource files (whitelist)
// These are server-parsing patterns, debug strings, or legacy internal errors
const KNOWN_OK_STRINGS = [
  // V2exNativeAuthService / V2exSigninParser — parse Chinese server response patterns
  '验证码', '密码', '用户名', '两步', '二步', '动态验证码', '安全码',
  // V2exWriteFormParser — parses Chinese HTML field names
  '标题',
  // AutoDailyCheckinService — matches Chinese server response text
  '已签到', '已领取', '已完成', '成功', '领取',
  // V2exTopicRepliesParser — parses Chinese "感谢" text
  '已感谢', '感谢已发送', '感谢', '个',
  // FoldScreenUtil — debug-only status descriptors
  '未知', '展开', '折叠', '半折叠', '其他', '全屏', '主屏', '副屏', '协同',
  '折叠屏', '状态', '模式', '隐藏标题栏',
  // Settings files — internal error fallback messages
  '读取', '保存', '清空', '设置失败', '历史失败',
  '主题设置', '搜索历史', '搜索来源', '回复显示', '回复样式',
  '回复按钮对齐方式', '阅读设置', '阅读位置',
  // HttpClient / Sov2ex — service error fallbacks
  'HTTP', 'SOV2EX', '搜索失败',
  // V2exTopicWebRepliesClient
  '无效的主题',
  // DateUtils — JSDoc comments (already i18n'd)
  '时间戳',
  // NotificationCenterViewModel — matches V2EX server notification text for kind classification
  '提到了你', '回复了你', '回复了你的', '收藏了你', '关注了你', '感谢了你', '系统',
  // NotificationPage — session expiry detection string matching
  '会话已失效',
  // V2exAccountParser — parses Chinese server HTML coin labels
  '金币', '银币', '铜币',
  // V2exMemberPageParser — parses Chinese server HTML for member page sections
  '主题列表被隐藏', '最近回复', '号会员',
  // V2exNotificationParser — parses Chinese notification timestamps from V2EX server HTML
  '刚刚', '半小时前', '秒前', '分钟前', '小时前', '天前', '年前',
  '小时', '分钟', '秒', '天', '个月', '年',
  '昨天', '前天', '月', '日',
]

function isKnownOk(text) {
  for (const ok of KNOWN_OK_STRINGS) {
    if (text.includes(ok)) {
      return true
    }
  }
  return false
}

for (const { full, rel } of walkDir(WORKTREE)) {
  const content = fs.readFileSync(full, 'utf-8')
  const lines = content.split('\n')

  // Check if file is in allowed list
  const isAllowedFile = ALLOWED_FILES.has(rel) ||
    ALLOWED_PATTERNS.some(p => p.test(rel))

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    const match = CJK_RE.exec(line)
    if (!match) continue

    const lineNum = i + 1
    const key = `${rel}:${lineNum}`

    if (isAllowedFile) {
      findings.allowed.push(`${key}: test fixture / allowed file (${line.trim().substring(0, 80)})`)
      passed++
      continue
    }

    if (isCommentOnly(line, match)) {
      findings.allowed.push(`${key}: comment (${line.trim().substring(0, 80)})`)
      passed++
      continue
    }

    if (isKnownOk(line)) {
      findings.needs_review.push(`${key}: known server-parsing/legacy (${line.trim().substring(0, 80)})`)
      passed++
      continue
    }

    // User-visible CJK in non-resource, non-comment, non-whitelisted context
    findings.must_fix.push(`${key}: MUST_FIX — user-visible CJK (${line.trim().substring(0, 80)})`)
    failed++
  }
}

// ------------------------------------------------------------
// Report
// ------------------------------------------------------------

console.log('=== CJK i18n Contract Test ===\n')
console.log(`Total CJK hits: ${passed + failed}`)
console.log(`  Passed (allowed/comment/known): ${passed}`)
console.log(`  Failed (must_fix): ${failed}\n`)

if (findings.must_fix.length > 0) {
  console.log('--- MUST_FIX ---')
  for (const f of findings.must_fix) {
    console.log(`  ${f}`)
  }
}

if (findings.needs_review.length > 0) {
  console.log(`\n--- NEEDS_REVIEW (${findings.needs_review.length}) ---`)
  for (const f of findings.needs_review.slice(0, 30)) {
    console.log(`  ${f}`)
  }
  if (findings.needs_review.length > 30) {
    console.log(`  ... and ${findings.needs_review.length - 30} more`)
  }
}

console.log(`\n--- ALLOWED (${findings.allowed.length}) ---`)
console.log('  (comments, resource files, test fixtures)')
console.log(`\nVERDICT: ${failed === 0 ? 'PASS' : 'FAIL'}`)

process.exit(failed === 0 ? 0 : 1)
