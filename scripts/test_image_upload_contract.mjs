#!/usr/bin/env node
/**
 * V2Next image-upload feature contract (static source checks).
 *
 * Locks the invariants that the build can't catch and that an adversarial review surfaced:
 *  - CRITICAL: the topic editor blocks Submit while an "uploading://" placeholder is in the body, so a
 *    half-uploaded image's placeholder can never be published into a (paid, irreversible) V2EX topic.
 *  - The imageUploadSettings route is registered at every required site (coordinator + render + barrels +
 *    settings entry).
 *  - Every AppStrings.R_IMAGE_UPLOAD_* referenced in source exists as a key across all 7 locales.
 *  - The Imgur provider targets the correct endpoint with the Client-ID header and parses data.link.
 *
 * Run: node scripts/test_image_upload_contract.mjs
 */

import fs from 'node:fs'
import path from 'node:path'

const REPO = process.cwd()
const read = (rel) => fs.readFileSync(path.join(REPO, rel), 'utf8')
const failures = []
const ok = []
function check(cond, label) {
  if (cond) {
    ok.push(label)
  } else {
    failures.push(label)
  }
}

// ── CRITICAL: editor blocks submit while an upload placeholder is present ──────
const editor = read('entry/src/main/ets/pages/TopicEditorPage.ets')
check(/hasUploadInFlight\s*\(\)\s*:\s*boolean/.test(editor), 'editor defines hasUploadInFlight()')
check(/indexOf\('uploading:\/\/'\)\s*>=\s*0/.test(editor), "hasUploadInFlight() detects the 'uploading://' placeholder scheme")
// canSubmit must consult hasUploadInFlight (disables the title-bar Submit icon while uploading)
const canSubmit = (editor.match(/private canSubmit\(\)[\s\S]*?\n  }/) || [''])[0]
check(/hasUploadInFlight\(\)/.test(canSubmit), 'canSubmit() blocks while an upload is in flight')
// confirmSubmit must guard too (defense in depth on the command-bus submit path)
const confirmSubmit = (editor.match(/private confirmSubmit\(\)[\s\S]*?\n  }/) || [''])[0]
check(/hasUploadInFlight\(\)/.test(confirmSubmit), 'confirmSubmit() guards against an in-flight upload')
// the placeholder uses the uploading:// scheme so it renders nothing and is matchable
check(/uploading:\/\/\$\{Date\.now\(\)\}/.test(editor), 'placeholder uses a unique uploading://<ts> token')
// stale placeholders are stripped from a restored draft
check(/stripUploadingPlaceholders/.test(editor) && /uploading:\\\/\\\//.test(editor), 'editor strips orphaned uploading:// placeholders on draft load')

// ── Image source picker: a button-anchored menu (not an ActionSheet) ──────────
const toolbar = read('shared/src/main/ets/components/MarkdownToolbar.ets')
check(/\.bindMenu\(this\.imageMenuShown,\s*this\.ImageMenu/.test(toolbar), 'toolbar hangs the image menu (bindMenu) on the picture button')
check(/MenuItem\(/.test(toolbar) && /R_IMAGE_UPLOAD_ACTION_NEW/.test(toolbar) && /R_IMAGE_UPLOAD_ACTION_LINK/.test(toolbar), 'toolbar image menu offers upload + insert-link items')
check(/R_IMAGE_UPLOAD_ACTION_FROM_V2EX/.test(toolbar) && /\.enabled\(false\)/.test(toolbar), 'toolbar keeps the V2EX gallery item visible-but-disabled')
// the editor no longer pops a global ActionSheet; it wires the two real menu actions
check(!/ActionSheet\.show/.test(editor), 'editor no longer uses a global ActionSheet for image source')
check(/onImageUpload:\s*\(\)\s*=>\s*\{\s*this\.pickAndUploadImage\(\)/.test(editor), 'editor wires onImageUpload → pickAndUploadImage')
check(/onInsertImageLink:\s*\(\)\s*=>\s*\{\s*this\.insertInlineMarkdown/.test(editor), 'editor wires onInsertImageLink → insertInlineMarkdown')

// ── Route registration (all sites) ───────────────────────────────────────────
const coordinator = read('entry/src/main/ets/model/IndexRouteCoordinator.ets')
check(/'imageUploadSettings'\s*\|/.test(coordinator), 'route: family in the union type')
check(/'ImageUploadSettings':\s*'imageUploadSettings'/.test(coordinator), 'route: name→family mapping')
check(/'imageUploadSettings':\s*AppStrings\.R_IMAGE_UPLOAD_SETTINGS_TITLE/.test(coordinator), 'route: destination title')
check(/'imageUploadSettings':\s*true/.test(coordinator), 'route: standard title bar')
const indexPage = read('entry/src/main/ets/pages/Index.ets')
check(/descriptor\.family === 'imageUploadSettings'/.test(indexPage) && /ImageUploadSettingsPage\(\)/.test(indexPage), 'route: Index renders ImageUploadSettingsPage')
check(/ImageUploadSettingsPage/.test(read('feature/settings/src/main/ets/Index.ets')), 'route: settings module barrel exports the page')
check(/pushPathByName\('ImageUploadSettings'/.test(read('feature/settings/src/main/ets/pages/SettingsPage.ets')), 'settings entry row pushes the route')

// ── i18n: every referenced R_IMAGE_UPLOAD_* exists in all 7 locales ───────────
const LOCALES = ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW', 'ja_JP', 'ko_KR']
const localeKeys = {}
for (const loc of LOCALES) {
  const json = JSON.parse(read(`entry/src/main/resources/${loc}/element/string.json`))
  localeKeys[loc] = new Set(json.string.map((s) => s.name))
}
const appStrings = read('shared/src/main/ets/i18n/AppStrings.ets')
const referenced = new Set()
const reAll = /R_IMAGE_UPLOAD_[A-Z0-9_]+/g
for (const src of [editor, toolbar, indexPage, coordinator, read('feature/settings/src/main/ets/pages/ImageUploadSettingsPage.ets'), read('feature/settings/src/main/ets/pages/SettingsPage.ets')]) {
  let m
  while ((m = reAll.exec(src)) !== null) {
    referenced.add(m[0])
  }
}
for (const constName of referenced) {
  const keyMatch = appStrings.match(new RegExp(`${constName}: Resource = \\$r\\('app\\.string\\.([a-z0-9_]+)'\\)`))
  check(!!keyMatch, `AppStrings defines ${constName}`)
  if (keyMatch) {
    const key = keyMatch[1]
    for (const loc of LOCALES) {
      check(localeKeys[loc].has(key), `i18n: '${key}' present in ${loc}`)
    }
  }
}

// ── Imgur provider contract ───────────────────────────────────────────────────
const imgur = read('shared/src/main/ets/services/imageupload/ImgurImageProvider.ets')
check(/https:\/\/api\.imgur\.com\/3\/image/.test(imgur), 'imgur: posts to /3/image')
check(/Client-ID \$\{clientId\}/.test(imgur), 'imgur: Authorization Client-ID header')
check(/parsed\.data\.link/.test(imgur), 'imgur: parses data.link')
check(/responseCode === 413/.test(imgur), 'imgur: maps HTTP 413 → too large')
check(/JSON\.parse/.test(imgur) && /catch/.test(imgur), 'imgur: guards non-JSON responses')

// ── ImgBB provider contract ───────────────────────────────────────────────────
const imgbb = read('shared/src/main/ets/services/imageupload/ImgbbImageProvider.ets')
check(/https:\/\/api\.imgbb\.com\/1\/upload/.test(imgbb), 'imgbb: posts to /1/upload')
check(/\?key=\$\{encodeURIComponent\(apiKey\)\}/.test(imgbb), 'imgbb: API key in the query string')
check(/encodeToStringSync/.test(imgbb) && /'image': base64/.test(imgbb), 'imgbb: sends raw base64 in the image form field')
check(/parsed\.data\.url/.test(imgbb), 'imgbb: parses data.url')
check(/postForm/.test(imgbb), 'imgbb: reuses the urlencoded postForm path')

// ── sm.ms provider contract ───────────────────────────────────────────────────
const smms = read('shared/src/main/ets/services/imageupload/SmmsImageProvider.ets')
check(/https:\/\/sm\.ms\/api\/v2\/upload/.test(smms), 'smms: posts to /api/v2/upload')
check(/postMultipart\([^)]*'smfile'/.test(smms), 'smms: multipart smfile part')
check(/'Authorization': token/.test(smms), 'smms: raw token Authorization header')
check(/parsed\.images/.test(smms), 'smms: treats image_repeated (existing url in images) as success')
check(/parsed\.data\.url/.test(smms), 'smms: parses data.url')

// ── Multipart plumbing + service wiring ───────────────────────────────────────
const uploadClient = read('shared/src/main/ets/network/ImageUploadClient.ets')
check(/static async postMultipart\(/.test(uploadClient), 'client: postMultipart exists')
check(/multipart\/form-data; boundary=/.test(uploadClient), 'client: sets multipart Content-Type with boundary')
const proxyReq = read('shared/src/main/ets/network/NetworkProxyRequest.ets')
check(/extraData\?:\s*string\s*\|\s*ArrayBuffer/.test(proxyReq), 'proxy: extraData widened to string | ArrayBuffer (binary body)')
const service = read('shared/src/main/ets/services/imageupload/ImageUploadService.ets')
check(/new SmmsImageProvider\(\)/.test(service) && /new ImgbbImageProvider\(\)/.test(service) && /new ImgurImageProvider\(\)/.test(service), 'service: providerFor wires imgbb + smms + imgur')
check(/SMMS_MAX_BYTES/.test(service) && /5 \* 1024 \* 1024/.test(service), 'service: sm.ms 5MB per-provider cap')
const settings = read('shared/src/main/ets/settings/ImageUploadSettings.ets')
check(/imgbbApiKey/.test(settings) && /smmsToken/.test(settings) && /imgurClientId/.test(settings), 'settings: three per-provider credentials')
check(/static isConfigured\(/.test(settings), 'settings: isConfigured() gate exists')
// the editor gates on the generic isConfigured, not an imgur-specific field
check(/ImageUploadSettings\.isConfigured\(config\)/.test(editor), 'editor: gates upload on isConfigured (provider-agnostic)')

// ── report ────────────────────────────────────────────────────────────────────
for (const f of failures) {
  console.error(`FAIL  ${f}`)
}
console.log(`\nimage-upload contract: ${ok.length} checks passed, ${failures.length} failure(s)`)
process.exit(failures.length === 0 ? 0 : 1)
