#!/usr/bin/env node
/**
 * Regression: a logged-in node page must NOT be misclassified as a 2FA challenge.
 *
 * Bug: opening certain nodes (Codex, 站点状态) showed "V2EX requires two-factor verification" though the
 * user was logged in. V2EX node pages carry a create-topic form (`<form action="/new/{node}">` with a lone
 * `<input name="title">`); `findTwoFactorCodeField`'s old `candidates.length === 1` fallback returned that
 * `title` field as the "2FA code field", and `looksLikeTwoFactorForm` matched the whole page when a topic
 * title mentioned 2fa/两步/totp — so the node 2FA'd. Every REAL V2EX 2FA form names its field `code`/`otp`,
 * which the positive (preferred) check already catches, so the single-input fallback was removed.
 *
 * Run: node scripts/test_node_2fa_false_positive_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const parser = readFileSync('shared/src/main/ets/parser/V2exSigninParser.ets', 'utf8')

// Source: the single-text-input fallback must be gone; only a positively-identified code field counts.
assert.doesNotMatch(
  parser,
  /candidates\.length === 1 \? candidates\[0\]\.name/,
  'findTwoFactorCodeField must NOT fall back to "any single text input" (it misread a create-topic title field as a 2FA code field)',
)
assert.match(
  parser,
  /return preferred \? preferred\.name : ''/,
  'findTwoFactorCodeField must return empty when no field positively identifies as a 2FA code field',
)

// Logic replica of the FIXED findTwoFactorCodeField.
function findTwoFactorCodeField(inputs) {
  const candidates = inputs.filter((i) => {
    const t = (i.type || '').toLowerCase()
    return i.name && (t === 'text' || t === 'tel' || t === 'number' || t === 'password' || t === '')
  })
  const preferred = candidates.find((i) => {
    const name = (i.name || '').toLowerCase()
    const ph = (i.placeholder || '').toLowerCase()
    return name.includes('2fa') || name.includes('otp') || name.includes('code') ||
      ph.includes('2fa') || ph.includes('otp') || ph.includes('code') ||
      ph.includes('验证码') || ph.includes('动态') || ph.includes('安全码')
  })
  return preferred ? preferred.name : ''
}

// A node create-topic form's lone `title` input must NOT be treated as a 2FA code field.
assert.equal(
  findTwoFactorCodeField([{ name: 'title', type: 'text' }]),
  '',
  'a create-topic form (single `title` input) must not yield a 2FA code field',
)
// The page-wide search (search box `q` + create-topic `title`) must also not yield a code field.
assert.equal(
  findTwoFactorCodeField([{ name: 'q', type: 'text' }, { name: 'title', type: 'text' }]),
  '',
  'a node page with search + create-topic inputs must not yield a 2FA code field',
)
// A REAL 2FA form (field named `code` / `otp`) is still detected.
assert.equal(findTwoFactorCodeField([{ name: 'code', type: 'password' }]), 'code', 'real 2FA `code` field still detected')
assert.equal(findTwoFactorCodeField([{ name: 'otp_redacted', type: 'text' }]), 'otp_redacted', 'real 2FA `otp` field still detected')

console.log('node 2FA false-positive contract passed')
