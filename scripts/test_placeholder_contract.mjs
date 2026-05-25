#!/usr/bin/env node
/**
 * Placeholder contract: verify no {N} placeholders leak to visible UI.
 *
 * Strategy:
 * 1. Collect every resource key whose en_US value contains {0}/{1}/{2} (format templates).
 * 2. In every .ets source file, flag:
 *    (a) $r('app.string.<key>', <arg>, <arg>, ...) where <key> is a {N} template —
 *        these go through HarmonyOS native %s formatting and leave {N} literal.
 *    (b) AppStrings.text(AppStrings.R_<KEY>, 'fallback with {N}') where the result
 *        is NOT followed by AppStrings.format — the caller may forget to format.
 *    (c) Any raw Text/Button/$r() with known parameterized keys directly in the markup.
 * 3. Exit non-zero if violations found.
 *
 * Run: node scripts/test_placeholder_contract.mjs
 */

import { readFileSync, existsSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { readdirSync, statSync } from 'node:fs'

const __dirname = fileURLToPath(new URL('.', import.meta.url))
const REPO = join(__dirname, '..')

const SOURCE_ROOTS = [
  'entry/src/main/ets',
  'shared/src/main/ets',
  'feature',
]
for (const root of SOURCE_ROOTS) {
  const p = join(REPO, root)
  if (!existsSync(p)) {
    console.error(`FATAL: source root not found: ${p}`)
    process.exit(1)
  }
}

// ─── Step 1: Collect {N} format template keys from StringMap ──────────────
function collectFormatKeys() {
  const stringMapPath = join(REPO, 'shared/src/main/ets/i18n/StringMap.ets')
  if (!existsSync(stringMapPath)) {
    console.error('FATAL: StringMap.ets not found')
    process.exit(1)
  }
  const content = readFileSync(stringMapPath, 'utf-8')
  const lines = content.split('\n')
  const keys = new Set()
  // Capture en_US block only (first locale block, lines ~1-660)
  // Pattern:   'key_name': 'value with {0}',
  const re = /^\s*'([a-z_0-9]+)':\s*'.*\{[0-9]\}.*',$/
  for (const line of lines) {
    const m = line.match(re)
    if (m) {
      keys.add(m[1])
    }
  }
  return keys
}

// ─── Step 2: Walk source files ──────────────────────────────────────────
function* walkDir(dir, exts, excludeDirs = []) {
  const entries = readdirSync(dir, { withFileTypes: true })
  for (const ent of entries) {
    const full = join(dir, ent.name)
    if (ent.isDirectory()) {
      if (excludeDirs.includes(ent.name)) continue
      yield* walkDir(full, exts, excludeDirs)
    } else if (ent.isFile() && exts.some(e => ent.name.endsWith(e))) {
      yield full
    }
  }
}

const SOURCE_EXTS = ['.ets']
const EXCLUDE_DIRS = ['node_modules', 'oh_modules', 'build', 'ohosTest']

let violations = 0
const findings = []

function fail(category, file, message, line) {
  violations++
  const rel = relative(REPO, file)
  const loc = line ? `${rel}:${line}` : rel
  findings.push({ category, file: loc, message })
  console.error(`FAIL [${category}] ${loc} — ${message}`)
}

// ─── Step 3: Check for unsafe $r() with {N} format keys ──────────────────
function checkUnsafeResourceCall(formatKeys) {
  const category = 'UNSAFE_RESOURCE_CALL'

  for (const root of SOURCE_ROOTS) {
    const absRoot = join(REPO, root)
    if (!existsSync(absRoot)) continue

    for (const file of walkDir(absRoot, SOURCE_EXTS, EXCLUDE_DIRS)) {
      const content = readFileSync(file, 'utf-8')
      const lines = content.split('\n')

      // Pattern: $r('app.string.<key>', <not empty>)
      // This catches any $r() call with extra arguments for a format-template key.
      for (const key of formatKeys) {
        const re = new RegExp(`\\$r\\('app\\.string\\.${key}'\\s*,\\s*[^)]+\\)`, 'g')
        let m
        while ((m = re.exec(content)) !== null) {
          const pos = m.index
          const lineNum = (content.substring(0, pos).match(/\n/g) || []).length + 1
          fail(category, file,
            `$r('app.string.${key}', ...) uses {N} format template — must use AppStrings.format(AppStrings.text(AppStrings.R_${key.toUpperCase()}, ...), [...])`,
            lineNum)
        }
      }
    }
  }
}

// ─── Step 4: Check for AppStrings.text() with {N} fallback but NO format ──
// This flags cases where a {N} template string is resolved via AppStrings.text()
// but the result isn't wrapped in AppStrings.format(). To avoid false positives,
// we check the full line for presence of AppStrings.format both before and after.
function checkTextWithoutFormat(formatKeys) {
  const category = 'TEXT_WITHOUT_FORMAT'

  for (const root of SOURCE_ROOTS) {
    const absRoot = join(REPO, root)
    if (!existsSync(absRoot)) continue

    for (const file of walkDir(absRoot, SOURCE_EXTS, EXCLUDE_DIRS)) {
      const content = readFileSync(file, 'utf-8')
      const lines = content.split('\n')

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i]
        const re = /AppStrings\.text\(\s*AppStrings\.(R_[A-Z_0-9]+),\s*'([^']*\{[0-9]\}[^']*)'/g
        let m
        while ((m = re.exec(line)) !== null) {
          // Check nearby lines for AppStrings.format (look both forward and backward)
          const contextLines = [
            lines[i - 1] || '',
            lines[i] || '',
            lines[i + 1] || '',
            lines[i + 2] || '',
          ].join(' ')
          if (!contextLines.includes('AppStrings.format')) {
            fail(category, file,
              `AppStrings.text(${m[1]}, '${m[2]}') has {N} placeholders but no AppStrings.format() in nearby context (lines ${i + 1}-${i + 3})`,
              i + 1)
          }
        }
      }
    }
  }
}

// ─── Step 5: Check for direct Text($r()) with known param keys ───────────
// (mirrors the existing contract check but for any {N} template key)
function checkDirectParamInSink(formatKeys) {
  const category = 'DIRECT_PARAM_IN_SINK'
  const keyList = [...formatKeys].join('|')

  for (const root of SOURCE_ROOTS) {
    const absRoot = join(REPO, root)
    if (!existsSync(absRoot)) continue

    for (const file of walkDir(absRoot, SOURCE_EXTS, EXCLUDE_DIRS)) {
      const content = readFileSync(file, 'utf-8')
      const re = new RegExp(`\\((Text|Button)\\)\\s*\\$r\\('app\\.string\\.(${keyList})'\\s*,`, 'g')
      let m
      while ((m = re.exec(content)) !== null) {
        const pos = m.index
        const lineNum = (content.substring(0, pos).match(/\n/g) || []).length + 1
        fail(category, file,
          `{N} template key "${m[2]}" used directly in ${m[1]} component without format`,
          lineNum)
      }
    }
  }
}

// ─── Main ────────────────────────────────────────────────────────────────
console.log('=== Placeholder Contract ===\n')
const formatKeys = collectFormatKeys()
console.log(`Collected ${formatKeys.size} {N} format template keys from StringMap.ets\n`)

checkUnsafeResourceCall(formatKeys)
checkTextWithoutFormat(formatKeys)
checkDirectParamInSink(formatKeys)

console.log(`\n=== Result: ${violations} violation(s) ===`)
if (violations > 0) {
  console.log('\nViolations found — see details above.')
  process.exit(1)
} else {
  console.log('PASS: No unformatted {N} placeholders reach visible UI.')
  process.exit(0)
}
