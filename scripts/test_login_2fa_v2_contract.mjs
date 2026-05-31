#!/usr/bin/env node
// Static contract for the login/2FA State Management V1 -> V2 slice (bulk-remaining lane).
//
// These three surfaces are NOT in scripts/v2-migrated-leaves.json because they legitimately call
// Date.now() to stamp `validatedAt` on the persisted auth session (a data timestamp, not a
// refresh-by-key-churn token), which the strict leaf contract forbids. This check pins their V2
// migration and the command-bus mirror wiring that replaced their V1 @StorageLink/@Watch/@Consume:
//
//   1. V2exTwoFactorPrompt / V2exNativeLoginPage / V2exWebLoginPage are each @ComponentV2 with NO
//      surviving V1 component-state decorator (comment-stripped).
//   2. V2exTwoFactorPrompt exposes @Param/@Event (its former two-way `@Link visible` is now a one-way
//      @Param + @Event onVisibleChange).
//   3. The two login pages read the V2 nav holder (connectNavStack().stack, no @Consume) and their
//      command-bus mirror via @Monitor (connectNativeLoginShown / connectWebLoginAction).
//   4. Index.ets dual-writes both command mirrors at its single writers (notifyNativeLoginShown /
//      sendWebLoginAction), keeping the V1 AppStorage key and the V2 mirror in lockstep.
//
// Run: node scripts/test_login_2fa_v2_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');
const read = (rel) => readFileSync(join(repo, rel), 'utf8');
const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

let failures = 0;
const ok = (m) => console.log(`ok   ${m}`);
const fail = (m) => { console.error(`FAIL ${m}`); failures++; };
const must = (cond, m) => (cond ? ok(m) : fail(m));

const PROMPT = 'entry/src/main/ets/components/V2exTwoFactorPrompt.ets';
const NATIVE = 'entry/src/main/ets/pages/V2exNativeLoginPage.ets';
const WEB = 'entry/src/main/ets/pages/V2exWebLoginPage.ets';
const INDEX = 'entry/src/main/ets/pages/Index.ets';

const V1_DECORATORS = ['@State', '@Prop', '@Link', '@Watch', '@StorageLink', '@StorageProp', '@Consume', '@Provide', '@ObjectLink'];

// 1) all three are pure @ComponentV2 leaves -----------------------------------------------------
for (const rel of [PROMPT, NATIVE, WEB]) {
  const code = strip(read(rel));
  must(/@ComponentV2\b/.test(code), `${rel}: is @ComponentV2`);
  must(!/@Component\b(?!V2)/.test(code), `${rel}: no bare V1 @Component`);
  for (const d of V1_DECORATORS) {
    must(!new RegExp(`${d}\\b`).test(code), `${rel}: no surviving ${d}`);
  }
}

// 2) V2exTwoFactorPrompt @Param/@Event two-way replacement -------------------------------------
{
  const code = strip(read(PROMPT));
  must(/@Param\s+visible\b/.test(code), `${PROMPT}: @Param visible`);
  must(/@Event\s+onVisibleChange\b/.test(code), `${PROMPT}: @Event onVisibleChange (replaces @Link)`);
  must(/this\.onVisibleChange\?\.\(false\)/.test(code), `${PROMPT}: closes via onVisibleChange(false)`);
}

// 3) login pages read V2 nav holder + command mirror via @Monitor ------------------------------
{
  const code = strip(read(NATIVE));
  must(/connectNavStack\(\)\.stack/.test(code), `${NATIVE}: nav via connectNavStack().stack`);
  must(/connectNativeLoginShown\(\)/.test(code), `${NATIVE}: reads connectNativeLoginShown() mirror`);
  must(/@Monitor\(\s*['"]nativeLoginShownState\.command['"]\s*\)/.test(code), `${NATIVE}: @Monitor on the resume signal`);
}
{
  const code = strip(read(WEB));
  must(/connectNavStack\(\)\.stack/.test(code), `${WEB}: nav via connectNavStack().stack`);
  must(/connectWebLoginAction\(\)/.test(code), `${WEB}: reads connectWebLoginAction() mirror`);
  must(/@Monitor\(\s*['"]webLoginActionState\.command['"]\s*\)/.test(code), `${WEB}: @Monitor on the web-login command`);
}

// 4) Index dual-writes both mirrors at its single writers --------------------------------------
{
  const code = strip(read(INDEX));
  must(/connectNativeLoginShown\(\)\.command\s*=/.test(code), `${INDEX}.notifyNativeLoginShown: dual-writes connectNativeLoginShown().command`);
  must(/connectWebLoginAction\(\)\.command\s*=/.test(code), `${INDEX}.sendWebLoginAction: dual-writes connectWebLoginAction().command`);
  // V1 AppStorage halves still present (bridge stays reversible while Index is V1)
  must(/StorageKeys\.NATIVE_LOGIN_SHOWN/.test(code), `${INDEX}: still writes the V1 NATIVE_LOGIN_SHOWN key`);
  must(/StorageKeys\.WEB_LOGIN_ACTION/.test(code), `${INDEX}: still writes the V1 WEB_LOGIN_ACTION key`);
}

console.log(`\nlogin-2fa-v2 contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
