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
  // Generated locale tables mirror resource JSON; CJK values in non-English locales expected
  'shared/src/main/ets/i18n/StringMap.ets',
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

const findings = { must_fix: [], allowed: [], server_parsing: [] }
let passed = 0
let failed = 0

function isCommentOnly(line, cjkMatch) {
  const trimmed = line.trimStart()
  return trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/**')
}

// Server-facing CJK is not localization debt: these strings are grammar for V2EX HTML / server messages.
// Keep this allowlist path-aware. Do not add broad tokens like "个" globally: that hides real UI copy.
const SERVER_PARSE_ALLOWLIST = [
  {
    file: /^entry\/src\/main\/ets\/viewmodel\/NotificationCenterViewModel\.ets$/,
    tokens: ['提到了你', '回复了你', '回复了你的', '回复', '感谢了你', '收藏了你', '收藏', '关注了你', '关注', '系统']
  },
  {
    file: /^shared\/src\/main\/ets\/network\/V2exNativeAuthService\.ets$/,
    tokens: ['验证码', '密码', '用户名']
  },
  {
    file: /^shared\/src\/main\/ets\/parser\//,
    tokens: [
      '金币', '银币', '铜币', '已领取', '已完成', '明天',
      '主题列表被隐藏', '最近回复', '号会员',
      '刚刚', '半小时前', '秒前', '分钟前', '小时前', '天前', '个月前', '年前',
      '小时', '分钟', '秒', '天', '个月', '年', '昨天', '前天', '月', '日',
      '登录受限', '受限的 IP 地址', '两步', '二步', '动态验证码', '安全码', '验证码', '动态',
      '感谢', '已感谢', '感谢已发送', '个', '标题'
    ]
  },
  {
    file: /^shared\/src\/main\/ets\/services\/AutoDailyCheckinService\.ets$/,
    tokens: ['已签到', '已领取', '已完成', '成功', '领取']
  },
  {
    file: /^shared\/src\/main\/ets\/settings\/CollectionParsers\.ets$/,
    tokens: ['个主题']
  }
]

function isServerParsingOk(rel, text) {
  for (const entry of SERVER_PARSE_ALLOWLIST) {
    if (!entry.file.test(rel)) continue
    for (const token of entry.tokens) {
      if (text.includes(token)) return true
    }
  }
  return false
}

function scanDefaultResourceCjk() {
  const resourceFiles = [
    'entry/src/main/resources/base/element/string.json',
    'entry/src/main/resources/en_US/element/string.json'
  ]
  for (const rel of resourceFiles) {
    const full = path.join(WORKTREE, rel)
    if (!fs.existsSync(full)) continue
    const data = JSON.parse(fs.readFileSync(full, 'utf-8'))
    const values = data.string || []
    for (const item of values) {
      const value = String(item.value || '')
      if (CJK_RE.test(value)) {
        findings.must_fix.push(`${rel}:${item.name}: MUST_FIX — default/en_US resource contains CJK (${value.substring(0, 80)})`)
        failed++
      }
    }
  }
}

function scanZhHkRelativeTimeVariants() {
  const rel = 'entry/src/main/resources/zh_HK/element/string.json'
  const full = path.join(WORKTREE, rel)
  if (!fs.existsSync(full)) return

  const data = JSON.parse(fs.readFileSync(full, 'utf-8'))
  const valuesByName = new Map((data.string || []).map(item => [item.name, String(item.value || '')]))
  const checks = [
    ['relative_just_now', '刚'],
    ['relative_minutes_ago', '分钟'],
    ['relative_hours_ago', '小时'],
    ['relative_months_ago', '个月']
  ]

  for (const [name, simplifiedVariant] of checks) {
    const value = valuesByName.get(name)
    if (value === undefined) {
      findings.must_fix.push(`${rel}:${name}: MUST_FIX — zh_HK relative-time resource is missing`)
      failed++
    } else if (value.includes(simplifiedVariant)) {
      findings.must_fix.push(`${rel}:${name}: MUST_FIX — zh_HK relative-time resource contains simplified variant ${simplifiedVariant} (${value})`)
      failed++
    } else {
      findings.allowed.push(`${rel}:${name}: zh_HK relative-time resource avoids simplified variant ${simplifiedVariant}`)
      passed++
    }
  }
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

    if (isServerParsingOk(rel, line)) {
      findings.server_parsing.push(`${key}: server-parsing (${line.trim().substring(0, 80)})`)
      passed++
      continue
    }

    // User-visible CJK in non-resource, non-comment, non-whitelisted context
    findings.must_fix.push(`${key}: MUST_FIX — user-visible CJK (${line.trim().substring(0, 80)})`)
    failed++
  }
}

scanDefaultResourceCjk()
scanZhHkRelativeTimeVariants()

// ------------------------------------------------------------
// Report
// ------------------------------------------------------------

console.log('=== CJK i18n Contract Test ===\n')
console.log(`Total CJK hits: ${passed + failed}`)
console.log(`  Passed (allowed/comment/server-parsing): ${passed}`)
console.log(`  Failed (must_fix): ${failed}\n`)

if (findings.must_fix.length > 0) {
  console.log('--- MUST_FIX ---')
  for (const f of findings.must_fix) {
    console.log(`  ${f}`)
  }
}

if (findings.server_parsing.length > 0) {
  console.log(`\n--- SERVER_PARSING_ALLOWED (${findings.server_parsing.length}) ---`)
  for (const f of findings.server_parsing.slice(0, 30)) {
    console.log(`  ${f}`)
  }
  if (findings.server_parsing.length > 30) {
    console.log(`  ... and ${findings.server_parsing.length - 30} more`)
  }
}

console.log(`\n--- ALLOWED (${findings.allowed.length}) ---`)
console.log('  (comments, resource files, test fixtures)')
console.log(`\nVERDICT: ${failed === 0 ? 'PASS' : 'FAIL'}`)

process.exit(failed === 0 ? 0 : 1)
