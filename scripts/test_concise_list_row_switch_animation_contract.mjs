#!/usr/bin/env node
// Static contract: ConciseListRow switches must preserve the native Toggle transition.
//
// Settings rows should use HDS' built-in list-item suffix switch instead of
// rebuilding a custom Toggle inside SuffixCustomBuilder. The switch state still
// belongs to the page/settings model; the interaction chrome belongs to HDS.
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const path = 'shared/src/main/ets/components/ConciseListRow.ets'
const source = readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
const code = source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '')

assert.match(code, /\bSuffixSwitch\b/, `${path}: imports/uses HDS SuffixSwitch`)
assert.match(code, /new\s+SuffixSwitch\(\s*\{[\s\S]*?isCheck:\s*this\.checked[\s\S]*?selectColor:\s*ThemeConstants\.BRAND_PRIMARY[\s\S]*?enable:\s*this\.isEnabled[\s\S]*?onChange:\s*\(value:\s*boolean\)\s*=>\s*\{[\s\S]*?this\.switchAction\(value\)[\s\S]*?\}/, `${path}: hasSwitch returns an HDS SuffixSwitch wired to existing settings state`)
assert.match(code, /private\s+suffixItem\(\):\s*SuffixTextAndArrow\s*\|\s*SuffixText\s*\|\s*SuffixCustomBuilder\s*\|\s*SuffixSwitch\s*\|\s*undefined/, `${path}: suffixItem type includes SuffixSwitch`)
assert.doesNotMatch(code, /Toggle\(\s*\{[\s\S]*?ToggleType\.Switch/, `${path}: must not rebuild a custom Toggle for list suffix switches`)
assert.doesNotMatch(code, /switchChecked|SWITCH_PARENT_SYNC_DELAY_MS|switchActionTimerId|pendingSwitchActionValue|scheduleSwitchAction|flushPendingSwitchAction/, `${path}: switch fix must not rely on local/timer-delayed parent sync`)
assert.doesNotMatch(code, /Date\.now\(\)|Math\.random\(\)|renderKey|refreshKey/, `${path}: must not force animation by churn keys`)

console.log('concise list row switch animation contract OK')
