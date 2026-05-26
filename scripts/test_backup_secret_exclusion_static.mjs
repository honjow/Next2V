import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root = process.cwd();
const dir = path.join(root, 'shared/src/main/ets/backup');
const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter(f => f.endsWith('.ets')) : [];
assert.ok(files.length > 0, 'backup source files must exist');
const allowed = new Set(['BackupSecretDenylist.ets']);
const forbidden = ['cookieSnapshot','tokenSnapshot','KEY_TOKEN','TWO_FACTOR_COOKIE','AUTH_SESSION','AUTH_COOKIE','CookieJarSettings','AuthSettings','AuthSessionSettings','AccountStore','WebCookie','NETWORK_PROXY_PASSWORD','DiagnosticsStore','DiagnosticsFileExport'];
for (const file of files) {
  if (allowed.has(file)) continue;
  const text = fs.readFileSync(path.join(dir, file), 'utf8');
  for (const word of forbidden) assert.ok(!text.includes(word), `${file} must not reference ${word}`);
  const passwordHits = [...text.matchAll(/password/ig)].map(m => m.index);
  assert.equal(passwordHits.length, 0, `${file} must not include password fields`);
}
console.log('PASS backup secret exclusion static');
