#!/usr/bin/env node
/**
 * No version-gated `hds.hdsMaterial` usage.
 *
 * Production crash (1.0.0 / versionCode 13): reviewers on HarmonyOS 6.0.0.130 devices hit
 *   SyntaxError: the requested module '@hms:hds.hdsMaterial' does not provide an export name 'hdsMaterial'
 * at app launch. `hdsMaterial` (from @kit.UIDesignKit) maps to the native submodule
 * `@hms:hds.hdsMaterial`, whose export is UNDEFINED on 6.0.0 — the static named import fails at module
 * link time, so any module importing it crashes (no canIUse can rescue a failed static import). The app
 * declares compatibleSdkVersion 6.0.0, so it must not import this 6.1+-only symbol. The material effect
 * (systemMaterialEffect) was removed; the bars fall back to the HDS default.
 *
 * Run: node scripts/test_no_version_gated_hds_material_contract.mjs
 */
import assert from 'node:assert/strict'
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join } from 'node:path'

function* etsFiles(dir) {
  for (const entry of readdirSync(dir)) {
    if (entry === 'oh_modules' || entry === 'node_modules' || entry === 'build' || entry.startsWith('.')) continue
    const full = join(dir, entry)
    const st = statSync(full)
    if (st.isDirectory()) yield* etsFiles(full)
    else if (entry.endsWith('.ets')) yield full
  }
}

const offenders = []
for (const root of ['entry', 'feature', 'shared']) {
  for (const file of etsFiles(root)) {
    const src = readFileSync(file, 'utf8')
    if (/\bhdsMaterial\b/.test(src) || /@hms:hds\.hdsMaterial/.test(src)) {
      offenders.push(file)
    }
  }
}

assert.deepEqual(
  offenders,
  [],
  `hdsMaterial (@hms:hds.hdsMaterial) is undefined on HarmonyOS 6.0.0 and crashes those devices at launch — do not import/use it. Offending files:\n  ${offenders.join('\n  ')}`,
)

console.log('no version-gated hds.hdsMaterial contract passed')
