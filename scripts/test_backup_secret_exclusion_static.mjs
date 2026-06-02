import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root = process.cwd();
const dir = path.join(root, 'shared/src/main/ets/backup');
const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter(f => f.endsWith('.ets')) : [];
assert.ok(files.length > 0, 'backup source files must exist');

// Encrypted-path files MAY reference credentials and the encryption password, because that data
// only ever travels inside the AES-256-GCM container — never in a plaintext envelope:
//   BackupAccountAdapter.ets — exports/restores accounts + cookie/token snapshots
//   BackupCrypto.ets         — AES-256-GCM + PBKDF2 (uses the encryption password)
//   BackupService.ets        — orchestrates the encrypt/decrypt path
//   BackupValidator.ets      — recognizes the encrypted container, handles wrong-password
//   BackupTypes.ets          — declares the schema, including the encryption-only userInfo section
const ENCRYPTED_PATH_FILES = new Set([
  'BackupSecretDenylist.ets',
  'BackupAccountAdapter.ets',
  'BackupCrypto.ets',
  'BackupService.ets',
  'BackupValidator.ets',
  'BackupTypes.ets',
]);

// Settings imports / runtime credential touchpoints that must NEVER appear outside the single
// encrypted-path account adapter. Even the schema/service files must not reach into these stores.
const RUNTIME_CREDENTIAL_TOKENS = ['CookieJarSettings', 'AuthSettings', 'AuthSessionSettings', 'AccountStore', 'WebCookie', 'NETWORK_PROXY_PASSWORD', 'DiagnosticsStore', 'DiagnosticsFileExport'];
const ACCOUNT_ADAPTER = 'BackupAccountAdapter.ets';

// The spirit preserved from v1: NO plaintext-eligible backup file may reference credential
// fields, settings credential stores, or the literal word "password". Plaintext serialization
// stays credential-free; credentials only exist behind the encrypted container.
const PLAINTEXT_FORBIDDEN = ['cookieSnapshot', 'tokenSnapshot', 'KEY_TOKEN', 'TWO_FACTOR_COOKIE', 'AUTH_SESSION', 'AUTH_COOKIE'].concat(RUNTIME_CREDENTIAL_TOKENS);

for (const file of files) {
  const text = fs.readFileSync(path.join(dir, file), 'utf8');

  // 1. Runtime credential stores: only the account adapter may touch them. This holds even for the
  //    other encrypted-path files (service/validator/types route accounts THROUGH the adapter).
  if (file !== ACCOUNT_ADAPTER) {
    for (const word of RUNTIME_CREDENTIAL_TOKENS) {
      assert.ok(!text.includes(word), `${file} must not reference runtime credential store ${word}`);
    }
  }

  // 2. Plaintext-eligible files (everything not on the encrypted-path allowlist) stay fully
  //    credential-free, including the literal "password".
  if (!ENCRYPTED_PATH_FILES.has(file)) {
    for (const word of PLAINTEXT_FORBIDDEN) {
      assert.ok(!text.includes(word), `${file} (plaintext-eligible) must not reference ${word}`);
    }
    const passwordHits = [...text.matchAll(/password/ig)].map(m => m.index);
    assert.equal(passwordHits.length, 0, `${file} (plaintext-eligible) must not include password fields`);
  }
}

// 3. The plaintext-eligible BACKUP_SECTION_NAMES list must NOT contain userInfo (the only section
//    carrying credentials); userInfo lives in the encryption-only section list.
const types = fs.readFileSync(path.join(dir, 'BackupTypes.ets'), 'utf8');
const sectionNamesMatch = types.match(/BACKUP_SECTION_NAMES:\s*BackupSectionName\[\]\s*=\s*\[([\s\S]*?)\]/);
assert.ok(sectionNamesMatch, 'BACKUP_SECTION_NAMES must be defined');
assert.ok(!sectionNamesMatch[1].includes('userInfo'), 'userInfo must not be a plaintext-eligible section');
assert.ok(types.includes('BACKUP_ENCRYPTED_ONLY_SECTION_NAMES'), 'userInfo must be an encryption-only section');

// 4. The plaintext preferences adapter now dumps the WHOLE next2v_settings store (which also holds
//    the network-proxy profiles embedding the proxy password). The ONLY thing keeping that password
//    out of the plaintext envelope is the denylist, so verify the guard is wired and complete.
const denylist = fs.readFileSync(path.join(dir, 'BackupSecretDenylist.ets'), 'utf8');
for (const marker of ['proxy', 'password', 'token', 'cookie', 'secret']) {
  assert.ok(denylist.includes(`'${marker}'`), `BackupSecretDenylist must exclude keys containing '${marker}'`);
}
assert.ok(/isExcluded\s*\(/.test(denylist), 'BackupSecretDenylist must expose isExcluded(key)');
const prefAdapter = fs.readFileSync(path.join(dir, 'BackupPreferencesAdapter.ets'), 'utf8');
assert.ok(prefAdapter.includes('BackupSecretDenylist.isExcluded'), 'BackupPreferencesAdapter must filter the whole-store dump through BackupSecretDenylist.isExcluded');
// Both the export (dump) and the import (write-back) sides must consult the denylist, so a tampered
// backup can never smuggle a credential key back into the store either.
assert.ok((prefAdapter.match(/BackupSecretDenylist\.isExcluded/g) || []).length >= 2, 'BackupPreferencesAdapter must apply the denylist on both export and restore');

console.log('PASS backup secret exclusion static');
