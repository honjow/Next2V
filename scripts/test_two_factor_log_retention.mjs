#!/usr/bin/env node
import assert from 'node:assert/strict'
import { load, entries, DiagnosticsRedactor } from './test_two_factor_session_behavior.mjs'
const base = 'shared/src/main/ets/diagnostics/'
const { DiagnosticsLogFormatter } = load(base + 'DiagnosticsLogFormatter.ets', ['DiagnosticsLogFormatter'], { DiagnosticsRedactor })
const files = new Map()
const handles = new Map()
let nextFd = 1
let offset = 0
class Clock extends Date {
  constructor(...args) { super(...(args.length ? args : [Date.now() + offset])) }
  static now() { return Date.now() + offset }
}
const fileIo = {
  OpenMode: { READ_WRITE: 1, CREATE: 2, TRUNC: 4, APPEND: 8 },
  mkdirSync: () => {},
  accessSync: path => files.has(path),
  openSync: (path, mode) => {
    if ((mode & 4) || !files.has(path)) files.set(path, '')
    const fd = nextFd++
    handles.set(fd, path)
    return { fd }
  },
  writeSync: (fd, text) => { const path = handles.get(fd); files.set(path, files.get(path) + text) },
  closeSync: file => handles.delete(file.fd),
  readTextSync: path => { assert.ok(files.has(path)); return files.get(path) },
  listFileSync: dir => [...files.keys()].filter(path => path.startsWith(dir + '/')).map(path => path.slice(dir.length + 1)),
  unlinkSync: path => files.delete(path),
}
const { DiagnosticsLogFileSink: sink } = load(base + 'DiagnosticsLogFileSink.ets', ['DiagnosticsLogFileSink'], {
  fileIo, fileUri: { getUriFromPath: path => 'file://' + path }, DiagnosticsRedactor, DiagnosticsLogFormatter, Date: Clock,
})
const context = { filesDir: '/app/files' }
sink.initialize(context)
for (const entry of entries.filter(entry => entry.context.flowId === entries.find(item => item.category === 'two_factor').context.flowId)) sink.append(entry)
const incident = sink.listRetainedLogFiles().find(file => file.fileName.startsWith('next2v-2fa-'))
assert.ok(incident)
const before = sink.readLogFileText(incident.fileName)
assert.ok(before.includes('challenge_opened'))
assert.ok(before.includes('response_received'))
for (let i = 0; i < 15; i++) {
  offset += 2000
  sink.initialize(context)
  sink.append({ ts: Clock.now(), level: 'info', category: 'app', event: 'relaunch', message: 'relaunch' })
}
assert.equal(sink.readLogFileText(incident.fileName), before, 'relaunch/general traffic must not evict 2FA incident')
assert.ok(sink.listRetainedLogFiles().filter(file => file.fileName.startsWith('next2v-log-')).length <= 10)
assert.ok(sink.listRetainedLogFiles().some(file => file.fileName === incident.fileName))
assert.equal(sink.isDiagnosticsLogFileName('../next2v-2fa-20261017-120000.txt'), false)
assert.equal(sink.isDiagnosticsLogFileName('next2v-2fa-20261017-120000.txt'), true)
for (let i = 0; i < 25; i++) {
  offset += 2000
  sink.append({ ts: Clock.now(), level: 'warn', category: 'two_factor', event: 'failed', message: 'failed', context: { flowId: `test-${i}` } })
}
assert.equal(sink.listRetainedLogFiles().filter(file => file.fileName.startsWith('next2v-2fa-')).length, 20)
// Large incidents rotate and the independent byte cap is enforced at rotation.
const facts = Object.fromEntries(Array.from({ length: 65 }, (_, index) => [`fact${index}`, 'x'.repeat(150)]))
for (let i = 0; i < 240; i++) {
  offset += 1000
  sink.append({ ts: Clock.now(), level: 'info', category: 'two_factor', event: 'response', message: 'response', context: { ...facts, flowId: 'large' } })
}
const journals = sink.listRetainedLogFiles().filter(file => file.fileName.startsWith('next2v-2fa-'))
assert.ok(journals.every(file => file.sizeBytes <= 256 * 1024))
// Rotation reserves room for the complete next segment.
assert.ok(journals.reduce((total, file) => total + file.sizeBytes, 0) <= 2 * 1024 * 1024)
for (const content of files.values()) {
  assert.ok(!/old-secret|retry-secret|nonce-one-secret|654321/.test(content))
}
offset += 31 * 24 * 3600 * 1000
sink.initialize(context)
assert.equal(sink.listRetainedLogFiles().filter(file => file.fileName.startsWith('next2v-2fa-')).length, 0)
assert.equal(handles.size, 0)
console.log('2FA journal: export, restart retention, independent quota, age/size rotation and redaction PASS')
