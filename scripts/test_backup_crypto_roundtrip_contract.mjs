#!/usr/bin/env node
/**
 * Encrypted-backup crypto contract (static).
 *
 * BackupCrypto depends on @kit.CryptoArchitectureKit (native), so the cipher cannot be exercised
 * in Node. Instead this contract pins the security-relevant shape of the encrypt/decrypt path:
 *   - AES-256-GCM with a PBKDF2-SHA256 derived key
 *   - random per-export salt + iv (never hardcoded)
 *   - high PBKDF2 iteration count
 *   - the encryption password lives only in memory: never persisted, logged, or returned
 *   - seal() and open() round-trip the SAME signed envelope through the existing parse/validate path
 */
import fs from 'node:fs'
import assert from 'node:assert/strict'

const root = process.cwd()
const crypto = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupCrypto.ets`, 'utf8')
const types = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupTypes.ets`, 'utf8')
const service = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupService.ets`, 'utf8')
const account = fs.readFileSync(`${root}/shared/src/main/ets/backup/BackupAccountAdapter.ets`, 'utf8')

// ── algorithm shape ──
assert.ok(crypto.includes("createCipher('AES256|GCM|PKCS7')"), 'must use AES-256-GCM')
assert.ok(crypto.includes("createSymKeyGenerator('AES256')"), 'AES-256 sym key')
assert.ok(crypto.includes("createKdf('PBKDF2|SHA256')"), 'must derive key via PBKDF2-SHA256')
assert.ok(crypto.includes("algName: 'PBKDF2'"), 'PBKDF2 KDF spec')
assert.ok(crypto.includes('ENCRYPT_MODE') && crypto.includes('DECRYPT_MODE'), 'both encrypt and decrypt modes')
assert.ok(crypto.includes('generateRandomSync'), 'salt/iv drawn from a CSPRNG')

// ── random, non-hardcoded salt + iv per seal ──
assert.ok(/randomBytes\(BACKUP_CIPHER_SALT_BYTES\)/.test(crypto), 'salt is randomized per export')
assert.ok(/randomBytes\(BACKUP_CIPHER_IV_BYTES\)/.test(crypto), 'iv is randomized per export')

// ── strong KDF parameters ──
const iterMatch = types.match(/BACKUP_KDF_ITERATIONS:\s*number\s*=\s*(\d+)/)
assert.ok(iterMatch, 'KDF iteration count must be defined')
assert.ok(Number(iterMatch[1]) >= 100000, `PBKDF2 iterations too low: ${iterMatch && iterMatch[1]}`)
assert.ok(/BACKUP_KDF_KEY_SIZE:\s*number\s*=\s*32/.test(types), 'derived key must be 32 bytes (AES-256)')
assert.ok(/BACKUP_CIPHER_IV_BYTES:\s*number\s*=\s*12/.test(types), 'GCM iv must be 12 bytes')
assert.ok(/BACKUP_CIPHER_TAG_BYTES:\s*number\s*=\s*16/.test(types), 'GCM tag must be 16 bytes')

// ── password hygiene: never persisted, logged, or returned ──
assert.ok(!/preferences|putSync|getPreferences/.test(crypto), 'BackupCrypto must not touch preferences')
assert.ok(!/console\.|DiagnosticLogger/.test(crypto), 'BackupCrypto must not log anything (passwords stay in memory)')
// seal()/open() take the password as a parameter and return only ciphertext/plaintext — never the password.
assert.ok(/seal\(plaintext:\s*string,\s*password:\s*string\)/.test(crypto), 'seal takes password as a transient param')
assert.ok(/open\(ciphertextBase64:\s*string,\s*password:\s*string/.test(crypto), 'open takes password as a transient param')
assert.ok(!/return[^\n]*password/.test(crypto), 'BackupCrypto must not return the password')

// ── round-trip wiring through the existing signed-envelope path ──
assert.ok(service.includes('BackupCrypto.seal(JSON.stringify(envelope)'), 'export seals the SIGNED plaintext envelope')
assert.ok(service.includes('BackupCrypto.open(container.ciphertext'), 'import opens the container before parsing')
// Decrypted bytes flow back through the normal parse/validate path, with fromEncrypted=true so the
// inner envelope's encryption-only userInfo section is accepted (it arrived sealed).
assert.ok(/BackupValidator\.parseEnvelope\(plaintext,\s*true\)/.test(service), 'decrypted bytes flow back through the normal parse/validate path (fromEncrypted)')
assert.ok(/encrypted:\s*true/.test(service), 'encrypted container marks encrypted:true so import can recognize it')

// ── account adapter is the single credential touchpoint, behind the encrypted path ──
assert.ok(account.includes('cookieSnapshot') && account.includes('tokenSnapshot'), 'account adapter carries cookie/token snapshots')
assert.ok(account.includes('AccountStore') && account.includes('replaceAllFromBackup'), 'account restore goes through AccountStore boundary')
assert.ok(service.includes('BackupAccountAdapter') && !service.includes('AccountStore'), 'service routes accounts THROUGH the adapter, never AccountStore directly')

console.log('PASS backup crypto roundtrip contract')
