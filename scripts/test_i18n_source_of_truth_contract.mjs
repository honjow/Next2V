#!/usr/bin/env node
/**
 * V2Next i18n source-of-truth static contract scanner.
 *
 * Covers I18N001 – I18N007 from the parent contract:
 *   I18N001_CJK_SOURCE_UI     — CJK in source UI paths
 *   I18N002_CJK_ENGLISH_RESOURCES — CJK in base/en_US resource values
 *   I18N003_BARE_APP_UI_LITERALS   — bare string literals in UI sinks
 *   I18N004_RESOURCE_KEY_PARITY    — key set parity across locales
 *   I18N005_RESOURCESTR_BYPASS     — pre-resolved labels with AppStrings.text
 *   I18N006_FORMATTER_MISUSE       — parameterized resource rendering hazards
 *   I18N007_REGRESSION_KEYS        — named regression family coverage
 *
 * Run:  node scripts/test_i18n_source_of_truth_contract.mjs
 */

import fs from 'node:fs'
import path from 'node:path'

const REPO = process.cwd()

// ─── helpers ───────────────────────────────────────────────────────
function read(rel) {
  return fs.readFileSync(path.join(REPO, rel), 'utf8')
}

function exists(rel) {
  return fs.existsSync(path.join(REPO, rel))
}

function* walkDir(dir, extensions, excludeDirs) {
  const stack = [dir]
  while (stack.length > 0) {
    const current = stack.pop()
    let entries
    try {
      entries = fs.readdirSync(current, { withFileTypes: true })
    } catch (_e) {
      continue
    }
    for (const entry of entries) {
      const full = path.join(current, entry.name)
      const rel = path.relative(REPO, full)
      if (entry.isDirectory()) {
        if (!excludeDirs.has(entry.name) && !rel.startsWith('.git') && !rel.startsWith('oh_modules')
          && !rel.startsWith('node_modules') && !rel.includes('build/')) {
          stack.push(full)
        }
      } else if (extensions.has(path.extname(entry.name).toLowerCase())) {
        yield { full, rel }
      }
    }
  }
}

function fail(checkId, rel, message, line) {
  const location = line !== undefined ? `${rel}:${line}` : rel
  failures.push(`[${checkId}] ${location}: ${message}`)
}

function readJsonFile(rel) {
  const full = path.join(REPO, rel)
  if (!fs.existsSync(full)) return null
  try {
    return JSON.parse(fs.readFileSync(full, 'utf8'))
  } catch (_e) {
    return null
  }
}

// ─── config ─────────────────────────────────────────────────────────
const CJK_RE = /[\u3400-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]/

const EXCLUDE_DIRS = new Set([
  '.git', 'oh_modules', 'build', '.hermes-artifacts', '.hvigor', 'node_modules',
])

const SOURCE_EXTS = new Set(['.ets', '.ts', '.js', '.mjs'])

const RESOURCE_SETS = [
  {
    pkg: 'entry',
    locales: ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW'],
    prefix: 'entry/src/main/resources',
  },
  {
    pkg: 'AppScope',
    locales: ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW'],
    prefix: 'AppScope/resources',
  },
]

const SOURCE_ROOTS = ['entry/src/main/ets', 'shared/src/main/ets']

const ARKUI_SINKS = [
  'Text', 'Button', 'MenuItem', 'AlertDialog', 'CustomDialog',
  'promptAction.showToast', 'TextInput.placeholder', 'Search.placeholder',
  'Navigation.title', 'NavDestination.title',
]

const UI_DESCRIPTOR_FIELDS = new Set([
  'title', 'subtitle', 'label', 'placeholder', 'message', 'description',
  'summary', 'text', 'caption', 'header', 'footer', 'menu', 'actionLabel',
  'primaryAction', 'secondaryAction',
])

const NON_VISIBLE_FIELDS = new Set([
  'id', 'key', 'route', 'name', 'type', 'icon', 'action', 'event', 'analyticsId',
])

const BRAND_TOKENS = new Set([
  'Base64', 'DUP', 'PRO', 'OP', 'API', 'URL', 'HTTP', 'HTTPS',
  'SOCKS5', 'GitHub', 'V2EX', 'OpenAI', 'Claude Code', 'Next2V',
  'YouTube', 'Vimeo', 'Gist', 'Imgur', 'Apple',
])

// Paths where CJK is allowed (parser/server/test/comment/generated)
const CJK_ALLOW_PATH_PATTERNS = [
  /^shared\/src\/main\/ets\/parser\//,
  /^shared\/src\/main\/ets\/settings\/CollectionParsers\.ets/,
  // Generated locale tables mirror resource JSON; CJK values in non-English locales expected
  /^shared\/src\/main\/ets\/i18n\/StringMap\.ets$/,
  /__tests__\//,
  /\/test\//,
  /\/tests\//,
  /\.spec\.ets$/,
  /\.test\.ets$/,
  /^scripts\//,
]

// Server-parsing CJK allowlist (extended from existing test_cjk_i18n_contract.mjs)
const SERVER_PARSE_CJK = [
  {
    file: /^entry\/src\/main\/ets\/viewmodel\/NotificationCenterViewModel\.ets$/,
    tokens: ['提到了你', '回复了你', '回复了你的', '回复', '感谢了你', '收藏了你', '收藏', '关注了你', '关注', '系统'],
  },
  {
    file: /^shared\/src\/main\/ets\/network\/V2exNativeAuthService\.ets$/,
    tokens: ['验证码', '密码', '用户名'],
  },
  {
    file: /^shared\/src\/main\/ets\/parser\//,
    tokens: [
      '金币', '银币', '铜币', '已领取', '已完成', '明天',
      '主题列表被隐藏', '最近回复', '号会员',
      '刚刚', '半小时前', '秒前', '分钟前', '小时前', '天前', '个月前', '年前',
      '小时', '分钟', '秒', '天', '个月', '年', '昨天', '前天', '月', '日',
      '登录受限', '受限的 IP 地址', '两步', '二步', '动态验证码', '安全码', '验证码', '动态',
      '感谢', '已感谢', '感谢已发送', '个', '标题',
    ],
  },
  {
    file: /^shared\/src\/main\/ets\/services\/AutoDailyCheckinService\.ets$/,
    tokens: ['已签到', '已领取', '已完成', '成功', '领取'],
  },
  {
    file: /^shared\/src\/main\/ets\/settings\/CollectionParsers\.ets$/,
    tokens: ['个主题'],
  },
]

const REGRESSION_FAMILIES = {
  account_current_switch_remove: [
    'account_active_label', 'account_switch_label', 'account_remove_label',
    'account_remove_title', 'account_remove_message_arg',
  ],
  topic_action_menu: [
    'topic_action_thank_topic', 'topic_action_site_favorite', 'topic_action_save_later',
    'topic_action_ignore_topic', 'topic_action_report_topic', 'topic_action_copy_title',
    'topic_action_copy_link', 'topic_action_share_link', 'topic_action_open_browser',
    'common_delete', 'common_remove', 'common_cancel',
  ],
  settings_storage_summary: [
    'nav_storage', 'clear_cache', 'clear_cache_message', 'read_cache_status_failed',
    'cache_subtitle', 'cache_subtitle_updated', 'clear_local_data', 'clear_local_data_message',
    'storage_written_format', 'storage_seeded_label_format',
  ],
  network_proxy_status: [
    'use_proxy', 'system_proxy', 'test_connection', 'testing_connection',
    'http_proxy', 'socks5_proxy', 'common_closed',
    'proxy_*',
    'proxy_summary_http', 'proxy_summary_https', 'proxy_summary_socks5',
    'proxy_summary_http_not_configured', 'proxy_summary_socks5_not_configured',
    'proxy_not_configured', 'proxy_config', 'proxy_connection',
    'proxy_type', 'proxy_parameters',
  ],
}

// ─── state ──────────────────────────────────────────────────────────
const failures = []
const warnings = []
const stats = { pass: 0, fail: 0 }

function isCommentLine(line) {
  const trimmed = line.trimStart()
  return trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/**')
}

function isCjkAllowedInFile(rel) {
  for (const pat of CJK_ALLOW_PATH_PATTERNS) {
    if (pat.test(rel)) return true
  }
  return false
}

function isServerParseCjk(rel, line) {
  for (const entry of SERVER_PARSE_CJK) {
    if (!entry.file.test(rel)) continue
    for (const token of entry.tokens) {
      if (line.includes(token)) return true
    }
  }
  return false
}

// ─── I18N001: CJK in source UI paths ────────────────────────────────
function checkCjkSourceUi() {
  const checkId = 'I18N001_CJK_SOURCE_UI'
  for (const root of SOURCE_ROOTS) {
    if (!exists(root)) continue
    for (const { full, rel } of walkDir(path.join(REPO, root), SOURCE_EXTS, EXCLUDE_DIRS)) {
      if (isCjkAllowedInFile(rel)) continue
      const content = read(rel)
      const lines = content.split('\n')
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i]
        const match = CJK_RE.exec(line)
        if (!match) continue
        if (isCommentLine(line)) continue

        // Exclude locale resource files
        if (/\/resources\//.test(rel)) continue

        if (isServerParseCjk(rel, line)) continue

        // User-visible CJK
        fail(checkId, rel, `user-visible CJK: "${line.trim().substring(0, 120)}"`, i + 1)
      }
    }
  }

  // Also check CJK in base/en_US resource values (overlaps with I18N002 but we also check here)
}

// ─── I18N002: CJK in English resource values ───────────────────────
function checkCjkEnglishResources() {
  const checkId = 'I18N002_CJK_ENGLISH_RESOURCES'
  const englishPaths = [
    'entry/src/main/resources/base/element/string.json',
    'entry/src/main/resources/en_US/element/string.json',
    'AppScope/resources/base/element/string.json',
    'AppScope/resources/en_US/element/string.json',
  ]
  for (const rel of englishPaths) {
    const data = readJsonFile(rel)
    if (!data) continue
    for (const item of data.string || []) {
      const value = String(item.value || '')
      if (CJK_RE.test(value)) {
        fail(checkId, `${rel}:${item.name}`, `English resource contains CJK: "${value.substring(0, 80)}"`)
      }
    }
  }
}

// ─── I18N003: Bare app UI literals ─────────────────────────────────
// Simple heuristic: find string literals in UI sink contexts
// This uses pattern matching on common ArkUI patterns
function checkBareUiLiterals() {
  const checkId = 'I18N003_BARE_APP_UI_LITERALS'

  // Patterns that likely capture bare UI string literals
  // Text('English words'), Button('...'), { label: '...' }, etc.
  const barePatterns = [
    // Text('...') with English word-looking content
    { regex: /Text\(\s*(['"`])([A-Z][a-z]{2,}[\s\w]*)\1\s*\)/g, name: 'Text()' },
    // Button('...')
    { regex: /Button\(\s*(['"`])([A-Z][a-z]{2,}[\s\w]*)\1\s*\)/g, name: 'Button()' },
    // promptAction.showToast({ message: '...' })
    { regex: /showToast\(\s*\{\s*message:\s*(['"])([A-Z][a-z]{2,}[\s\w]*)\1/g, name: 'showToast.message' },
    // { title: '...' } (in object literals, for descriptors)
    { regex: /\btitle:\s*(['"`])([A-Z][a-z]{2,}[\s\w]*)\1/g, name: 'descriptor.title' },
    // { subtitle: '...' }
    { regex: /\bsubtitle:\s*(['"`])([A-Z][a-z]{2,}[\s\w]*)\1/g, name: 'descriptor.subtitle' },
    // { label: '...' }
    { regex: /\blabel:\s*(['"`])([A-Z][a-z]{2,}[\s\w]*)\1/g, name: 'descriptor.label' },
    // { message: '...' }
    { regex: /\bmessage:\s*(['"`])([A-Z][a-z]{2,}[\s\w]*)\1/g, name: 'descriptor.message' },
    // { placeholder: '...' }
    { regex: /\bplaceholder:\s*(['"`])([A-Z][a-z]{2,}[\s\w]*)\1/g, name: 'descriptor.placeholder' },
    // { description: '...' }
    { regex: /\bdescription:\s*(['"`])([A-Z][a-z]{2,}[\s\w]*)\1/g, name: 'descriptor.description' },
  ]

  for (const root of SOURCE_ROOTS) {
    if (!exists(root)) continue
    for (const { full, rel } of walkDir(path.join(REPO, root), SOURCE_EXTS, EXCLUDE_DIRS)) {
      // Skip test files
      if (isCjkAllowedInFile(rel)) continue

      // Skip diagnostics infrastructure (not user-visible UI)
      if (rel.includes('/diagnostics/')) continue

      // Skip constants files (not user-visible UI)
      if (rel.includes('/constants/')) continue

      const content = read(rel)
      const lines = content.split('\n')

      for (const { regex, name } of barePatterns) {
        // Reset regex state
        regex.lastIndex = 0
        let match
        while ((match = regex.exec(content)) !== null) {
          const literal = match[2]
          // Skip brand tokens
          if (BRAND_TOKENS.has(literal)) continue
          // Skip empty/whitespace
          if (!literal.trim()) continue
          // Skip if it looks like a non-UI token (IDs, routes)
          if (/^[A-Z_]{2,}$/.test(literal)) continue

          // Find line number
          const pos = match.index
          const beforeMatch = content.substring(0, pos)
          const lineNum = (beforeMatch.match(/\n/g) || []).length + 1

          // Skip if line is a comment
          if (lineNum <= lines.length && isCommentLine(lines[lineNum - 1])) continue

          // Skip if this is an AppStrings.text fallback
          if (lines[lineNum - 1].includes('AppStrings.text(')) continue

          // Check if the field is non-visible
          const fieldName = name.split('.')[1] || ''
          if (fieldName && NON_VISIBLE_FIELDS.has(fieldName)) continue

          fail(checkId, rel, `bare UI literal in ${name}: "${literal}"`, lineNum)
        }
      }
    }
  }
}

// ─── I18N004: Resource key parity ──────────────────────────────────
function checkResourceKeyParity() {
  const checkId = 'I18N004_RESOURCE_KEY_PARITY'
  for (const rset of RESOURCE_SETS) {
    const keySets = {}
    for (const locale of rset.locales) {
      const rel = `${rset.prefix}/${locale}/element/string.json`
      const data = readJsonFile(rel)
      if (!data) {
        fail(checkId, rel, 'missing resource file')
        continue
      }
      const keys = new Set((data.string || []).map(item => String(item.name)))
      keySets[locale] = keys
    }

    if (!keySets['base']) continue
    const baseKeys = keySets['base']

    for (const locale of rset.locales) {
      if (!keySets[locale]) continue
      const localeKeys = keySets[locale]
      const rel = `${rset.prefix}/${locale}/element/string.json`

      // Check for duplicates
      const data = readJsonFile(rel)
      if (data) {
        const seen = new Set()
        for (const item of data.string || []) {
          const name = String(item.name)
          if (seen.has(name)) {
            fail(checkId, `${rel}:${name}`, 'duplicate resource key')
          }
          seen.add(name)
        }
      }

      // Missing from base
      for (const key of baseKeys) {
        if (!localeKeys.has(key)) {
          fail(checkId, rel, `missing key "${key}" from base locale set`)
        }
      }

      // Extra keys (locale has keys not in base)
      if (locale !== 'base') {
        for (const key of localeKeys) {
          if (!baseKeys.has(key)) {
            fail(checkId, rel, `extra key "${key}" not present in base locale`)
          }
        }
      }
    }
  }
}

// ─── I18N005: ResourceStr bypass (AppStrings.text pre-resolution) ──
function checkResourceStrBypass() {
  const checkId = 'I18N005_RESOURCESTR_BYPASS'

  const descriptorNamePatterns = [
    /Descriptor/, /Menu/, /Title/, /State/, /Coordinator/, /Row/, /Item/,
  ]

  for (const root of SOURCE_ROOTS) {
    if (!exists(root)) continue
    for (const { full, rel } of walkDir(path.join(REPO, root), SOURCE_EXTS, EXCLUDE_DIRS)) {
      if (isCjkAllowedInFile(rel)) continue

      // Only scan files likely to contain UI descriptor/state code
      const isDescriptorFile = descriptorNamePatterns.some(p => p.test(rel))
      const isInModel = rel.includes('/model/')
      const isInViewModel = rel.includes('/viewmodel/')
      if (!isDescriptorFile && !isInModel && !isInViewModel) continue

      const content = read(rel)
      const lines = content.split('\n')

      // Find AppStrings.text(...) calls assigned to UI descriptor fields
      const pattern = /(title|label|subtitle|message|description|summary|placeholder|text|caption|header|footer|actionLabel|primaryAction|secondaryAction)\s*:\s*AppStrings\.text\(/g
      let match
      while ((match = pattern.exec(content)) !== null) {
        const fieldName = match[1]
        const pos = match.index
        const lineNum = (content.substring(0, pos).match(/\n/g) || []).length + 1

        // Exempt: non-UI fields
        if (NON_VISIBLE_FIELDS.has(fieldName)) continue

        fail(checkId, rel,
          `field "${fieldName}" assigned with AppStrings.text() — pre-resolves locale, loses runtime reactivity`,
          lineNum)
      }

      // Also catch AppStrings.text() used to compute labels in functions returning descriptors
      // Pattern: return or const = AppStrings.text(...) where the result goes to a descriptor
      const preComputePattern = /(?:const|let)\s+\w+\s*=\s*AppStrings\.text\(/g
      while ((match = preComputePattern.exec(content)) !== null) {
        const pos = match.index
        const lineNum = (content.substring(0, pos).match(/\n/g) || []).length + 1
        const line = lines[lineNum - 1]

        // Skip formatter wrappers - they're approved
        if (line.includes('AppStrings.format(')) continue
        // Skip diagnostic/error message construction
        if (line.includes('message') && line.includes('AppStrings.text') && rel.includes('ApiError')) continue

        // Only flag if the variable name looks like a UI label
        if (/\b(followLabel|blockLabel|topicLabel|replyLabel|tabLabel|titleLabel|subtitleLabel|menuLabel|actionLabel)\b/.test(line)) {
          fail(checkId, rel,
            `UI label variable pre-resolved with AppStrings.text(): "${line.trim().substring(0, 120)}"`,
            lineNum)
        }
      }
    }
  }
}

// ─── I18N006: Formatter misuse ─────────────────────────────────────
function checkFormatterMisuse() {
  const checkId = 'I18N006_FORMATTER_MISUSE'
  const placeholderRe = /\{([0-9]+)\}/g

  // 1. Check resource values with placeholders
  for (const rset of RESOURCE_SETS) {
    for (const locale of rset.locales) {
      const rel = `${rset.prefix}/${locale}/element/string.json`
      const data = readJsonFile(rel)
      if (!data) continue
      for (const item of data.string || []) {
        const value = String(item.value || '')
        const placeholders = [...value.matchAll(placeholderRe)]
        if (placeholders.length === 0) continue

        // Check for duplicate placeholder indices
        const indices = placeholders.map(m => parseInt(m[1], 10))
        const unique = new Set(indices)
        if (unique.size !== indices.length) {
          fail(checkId, `${rel}:${item.name}`,
            `duplicate placeholder indices in resource value: "${value}"`)
        }
      }
    }
  }

  // 2. Check formatter implementation
  const appStringsRel = 'shared/src/main/ets/i18n/AppStrings.ets'
  if (exists(appStringsRel)) {
    const content = read(appStringsRel)
    // Check format uses replace (single) instead of replaceAll
    if (/\.replace\(`\{/.test(content) && !/\.replaceAll\(/.test(content)) {
      // Check if it's in the format method
      if (content.includes('static format(template: string, values: string[]): string')) {
        const formatLines = content.split('\n')
        let inFormat = false
        for (let i = 0; i < formatLines.length; i++) {
          if (formatLines[i].includes('static format(template: string, values: string[]): string')) {
            inFormat = true
            continue
          }
          if (inFormat && formatLines[i].includes('.replace(`{$')) {
            if (formatLines[i].includes('.replace(`{${index}}`') && !formatLines[i].includes('replaceAll')) {
              fail(checkId, appStringsRel,
                `AppStrings.format uses replace() not replaceAll() — duplicates won't be substituted`,
                i + 1)
            }
          }
          if (inFormat && formatLines[i].includes('return text')) break
        }
      }
    }
  }

  // 3. Check for direct resource-to-sink with placeholders
  // This is hard to do statically without full flow analysis, so flag known bad patterns
  for (const root of SOURCE_ROOTS) {
    if (!exists(root)) continue
    for (const { full, rel } of walkDir(path.join(REPO, root), SOURCE_EXTS, EXCLUDE_DIRS)) {
      const content = read(rel)

      // Pattern: AppStrings.text($r('app.string.*'), '...{0}...') where fallback has placeholders
      // but the resource key is for a parameterized string — this is OK as long as format is used after
      // Just flag fallback placeholder arity mismatches

      // Check: resource directly in Text/Button with $r and known parameterized resource
      const directParamPattern = /(Text|Button)\(\s*\$r\('app\.string\.(cache_subtitle|cache_subtitle_updated|account_remove_message_arg|storage_written_format|storage_seeded_label_format|reply_count_format|preloading_progress_format|preloading_progress_count_format|loaded_count_format|confirm_topic_favorite_format|confirm_reply_action_format|parse_action_failed_format|reply_thread_relation_label_format|reply_context_label_mention_format|reply_context_with_floor_format|action_done_format|draft_saved_on_format|load_all_replies_warning_format|diagnostics_log_file_share_hint|add_x_format|node_selected_format|connection_test_success|connection_test_failed|confirm_delete_proxy_message|retained_local_log_files_count_arg|diagnostics_current_launch_recent_count)'\)/g
      let match
      while ((match = directParamPattern.exec(content)) !== null) {
        const keyName = match[2]
        const pos = match.index
        const lineNum = (content.substring(0, pos).match(/\n/g) || []).length + 1
        fail(checkId, rel,
          `parameterized resource "${keyName}" used directly in UI sink without format wrapper`,
          lineNum)
      }

      // Pattern: AppStrings.text($r(...), fallback) where fallback has different placeholder count
      // This is a soft check — flag for manual review
    }
  }
}

// ─── I18N007: Regression key coverage ──────────────────────────────
function checkRegressionKeys() {
  const checkId = 'I18N007_REGRESSION_KEYS'

  // Collect all resource keys from entry base
  const entryBaseRel = 'entry/src/main/resources/base/element/string.json'
  const entryBase = readJsonFile(entryBaseRel)
  const allKeys = new Set()
  if (entryBase) {
    for (const item of entryBase.string || []) {
      allKeys.add(String(item.name))
    }
  }

  // 1. Check each regression family has keys present
  for (const [family, requiredKeys] of Object.entries(REGRESSION_FAMILIES)) {
    for (const rk of requiredKeys) {
      if (rk.includes('*')) {
        // Glob match
        const glob = new RegExp('^' + rk.replace(/\*/g, '.*') + '$')
        const matches = [...allKeys].filter(k => glob.test(k))
        if (matches.length === 0) {
          fail(checkId, family, `no keys matching glob "${rk}" found in entry base resources`)
        }
      } else {
        if (!allKeys.has(rk)) {
          fail(checkId, family, `required regression key "${rk}" missing from entry base resources`)
        }
      }
    }
  }

  // 2. Check that regression families covered in locale matrix (parity)
  // Already done in I18N004

  // 3. Check that AppStrings references exist for regression keys
  const appStringsRel = 'shared/src/main/ets/i18n/AppStrings.ets'
  if (exists(appStringsRel)) {
    const content = read(appStringsRel)
    for (const [family, requiredKeys] of Object.entries(REGRESSION_FAMILIES)) {
      for (const rk of requiredKeys) {
        // Convert key to AppStrings constant name
        if (rk.includes('*')) continue // Skip globs for AppStrings check
        const constantName = 'R_' + rk.toUpperCase()
        if (!content.includes(constantName)) {
          fail(checkId, appStringsRel,
            `regression key "${rk}" has no AppStrings.${constantName} constant`)
        }
      }
    }
  }

  // 4. Positive assertion: these specific keys MUST use ResourceStr in related coordinators
  const sourceChecks = [
    {
      rel: 'entry/src/main/ets/model/AccountPageCoordinator.ets',
      requiredTokens: [
        'R_ACCOUNT_ACTIVE_LABEL',
        'R_ACCOUNT_SWITCH_LABEL',
        'R_ACCOUNT_REMOVE_LABEL',
        'R_ACCOUNT_REMOVE_TITLE',
      ],
    },
    {
      rel: 'entry/src/main/ets/pages/AccountManagementPage.ets',
      requiredTokens: [
        'AccountPageCoordinator.SWITCH_LABEL',
        'AccountPageCoordinator.REMOVE_LABEL',
        'AccountPageCoordinator.ACCOUNT_ACTIVE_LABEL',
      ],
      forbiddenTokens: ['当前', '切换', '移除'],
    },
    {
      rel: 'entry/src/main/ets/model/TopicDetailTitleBarCoordinator.ets',
      requiredTokens: [
        'R_TOPIC_ACTION_THANK_TOPIC',
        'R_TOPIC_ACTION_SITE_FAVORITE',
        'R_TOPIC_ACTION_SAVE_LATER',
        'R_TOPIC_ACTION_IGNORE_TOPIC',
        'R_TOPIC_ACTION_REPORT_TOPIC',
      ],
    },
    {
      rel: 'shared/src/main/ets/settings/NetworkProxySettings.ets',
      requiredTokens: [
        "return AppStrings.R_COMMON_CLOSED",
        "return AppStrings.R_PROXY_SUMMARY_HTTP_NOT_CONFIGURED",
        "return AppStrings.R_PROXY_SUMMARY_SOCKS5_NOT_CONFIGURED",
      ],
      forbiddenTokens: ['关闭'],
    },
    {
      rel: 'feature/settings/src/main/ets/model/StorageSettingsCoordinator.ets',
      requiredTokens: [
        "AppStrings.R_CACHE_SUBTITLE_UPDATED",
        "AppStrings.R_CACHE_SUBTITLE",
        "AppStrings.format",
      ],
      forbiddenPatterns: [
        /\$r\('app\.string\.cache_subtitle/,
      ],
    },
  ]

  for (const check of sourceChecks) {
    if (!exists(check.rel)) {
      fail(checkId, check.rel, `source file not found for regression check`)
      continue
    }
    const content = read(check.rel)
    for (const token of check.requiredTokens || []) {
      if (!content.includes(token)) {
        fail(checkId, check.rel, `missing required regression token: "${token}"`)
      }
    }
    for (const token of check.forbiddenTokens || []) {
      if (content.includes(token)) {
        fail(checkId, check.rel, `forbidden CJK token found: "${token}"`)
      }
    }
    for (const pattern of check.forbiddenPatterns || []) {
      if (pattern.test(content)) {
        fail(checkId, check.rel, `forbidden pattern found: ${pattern}`)
      }
    }
  }
}

// ─── run all checks ─────────────────────────────────────────────────
console.log('=== V2Next i18n Source-of-Truth Contract Scanner ===\n')

// I18N001
checkCjkSourceUi()
// I18N002
checkCjkEnglishResources()
// I18N003
checkBareUiLiterals()
// I18N004
checkResourceKeyParity()
// I18N005
checkResourceStrBypass()
// I18N006
checkFormatterMisuse()
// I18N007
checkRegressionKeys()

// ─── report ─────────────────────────────────────────────────────────
if (failures.length > 0) {
  console.log(`FAIL — ${failures.length} violation(s) found:\n`)
  for (const f of failures) {
    console.log(`  ${f}`)
  }
  console.log(`\n${failures.length} violation(s) total.`)
  process.exit(1)
}

console.log(`PASS — all 7 check classes (I18N001–I18N007) passed.`)
console.log(`No i18n source-of-truth violations detected.`)
process.exit(0)
