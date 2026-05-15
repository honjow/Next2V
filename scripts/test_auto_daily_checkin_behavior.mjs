#!/usr/bin/env node
import assert from 'node:assert/strict'

class FakeSettings {
  constructor() {
    this.enabled = true
    this.lastAttemptDate = ''
    this.lastAttemptIdentity = ''
    this.lastSuccessDate = ''
  }
  isEnabled() { return this.enabled }
  getLastAttemptDate() { return this.lastAttemptDate }
  getLastAttemptIdentity() { return this.lastAttemptIdentity }
  getLastSuccessDate() { return this.lastSuccessDate }
  async saveLastAttemptDate(_context, date, identity) {
    this.lastAttemptDate = date
    this.lastAttemptIdentity = identity
  }
  async saveLastSuccessDate(_context, date) {
    this.lastAttemptDate = date
    this.lastSuccessDate = date
  }
}

class FakeApi {
  constructor(mission) {
    this.mission = mission
    this.fetchCalls = 0
    this.redeemCalls = 0
  }
  async getDailyMissionWithCookie(cookie) {
    this.fetchCalls += 1
    this.lastFetchCookie = cookie
    if (this.throwOnFetch) throw new Error('expired cookie')
    return this.mission
  }
  async redeemDailyMissionWithCookie(cookie, path) {
    this.redeemCalls += 1
    this.lastRedeem = { cookie, path }
    return { canRedeem: false, redeemPath: '', message: '签到完成' }
  }
}

function localDateString(date = new Date('2026-05-15T12:00:00')) {
  const month = `${date.getMonth() + 1}`.padStart(2, '0')
  const day = `${date.getDate()}`.padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

async function tryCheckin({ settings, api, cookie, today = localDateString(), inFlight = false }) {
  const cleanCookie = (cookie || '').trim()
  const attemptIdentity = cookieAttemptIdentity(cleanCookie)
  if (!settings.isEnabled()) return { attempted: false, redeemed: false, reason: 'disabled' }
  if (!cleanCookie) return { attempted: false, redeemed: false, reason: 'no-cookie' }
  if (inFlight) return { attempted: false, redeemed: false, reason: 'in-flight' }
  if (settings.getLastAttemptDate() === today && settings.getLastAttemptIdentity() === attemptIdentity) return { attempted: false, redeemed: false, reason: 'already-attempted' }
  await settings.saveLastAttemptDate({}, today, attemptIdentity)
  try {
    const mission = await api.getDailyMissionWithCookie(cleanCookie)
    if (!mission.canRedeem || !mission.redeemPath) {
      if ((mission.message || '').includes('已签到')) await settings.saveLastSuccessDate({}, today)
      return { attempted: true, redeemed: false, reason: 'not-redeemable' }
    }
    await api.redeemDailyMissionWithCookie(cleanCookie, mission.redeemPath)
    await settings.saveLastSuccessDate({}, today)
    return { attempted: true, redeemed: true, reason: 'redeemed' }
  } catch (error) {
    return { attempted: true, redeemed: false, reason: 'error', message: error.message || '' }
  }
}

function cookieAttemptIdentity(cookie) {
  let hash = 2166136261
  for (let i = 0; i < cookie.length; i += 1) {
    hash ^= cookie.charCodeAt(i)
    hash = Math.imul(hash, 16777619) >>> 0
  }
  return `${cookie.length}:${hash.toString(16)}`
}

async function scenario(name, arrange, assertScenario) {
  const settings = new FakeSettings()
  const api = new FakeApi({ canRedeem: true, redeemPath: '/mission/daily/redeem?once=123', message: '今日可签到' })
  const input = { settings, api, cookie: 'A=B; PB3=ok' }
  arrange(input)
  const result = await tryCheckin(input)
  assertScenario({ ...input, result })
  console.log(`ok - ${name}`)
}

await scenario('disabled skips fetch and redeem', ({ settings }) => { settings.enabled = false }, ({ api, result }) => {
  assert.equal(result.reason, 'disabled')
  assert.equal(api.fetchCalls, 0)
  assert.equal(api.redeemCalls, 0)
})

await scenario('no cookie skips fetch and redeem', (input) => { input.cookie = '' }, ({ api, result }) => {
  assert.equal(result.reason, 'no-cookie')
  assert.equal(api.fetchCalls, 0)
  assert.equal(api.redeemCalls, 0)
})

await scenario('same cookie already attempted today skips fetch and redeem', ({ settings }) => {
  settings.lastAttemptDate = localDateString()
  settings.lastAttemptIdentity = cookieAttemptIdentity('A=B; PB3=ok')
}, ({ api, result }) => {
  assert.equal(result.reason, 'already-attempted')
  assert.equal(api.fetchCalls, 0)
  assert.equal(api.redeemCalls, 0)
})

{
  const settings = new FakeSettings()
  const oldApi = new FakeApi({ canRedeem: true, redeemPath: '/mission/daily/redeem?once=old', message: '今日可签到' })
  oldApi.throwOnFetch = true
  const oldResult = await tryCheckin({ settings, api: oldApi, cookie: 'A=B; PB3=expired' })
  assert.equal(oldResult.reason, 'error')
  assert.equal(settings.lastAttemptDate, localDateString())
  assert.equal(settings.lastAttemptIdentity, cookieAttemptIdentity('A=B; PB3=expired'))

  const newApi = new FakeApi({ canRedeem: true, redeemPath: '/mission/daily/redeem?once=new', message: '今日可签到' })
  const result = await tryCheckin({ settings, api: newApi, cookie: 'A=B; PB3=fresh' })
  assert.equal(result.reason, 'redeemed')
  assert.equal(newApi.fetchCalls, 1)
  assert.equal(newApi.redeemCalls, 1)
  assert.equal(settings.lastAttemptIdentity, cookieAttemptIdentity('A=B; PB3=fresh'))

  const repeatApi = new FakeApi({ canRedeem: true, redeemPath: '/mission/daily/redeem?once=repeat', message: '今日可签到' })
  const repeat = await tryCheckin({ settings, api: repeatApi, cookie: 'A=B; PB3=fresh' })
  assert.equal(repeat.reason, 'already-attempted')
  assert.equal(repeatApi.fetchCalls, 0)
  assert.equal(repeatApi.redeemCalls, 0)
  console.log('ok - old same-day failed cookie does not suppress fresh login cookie, but fresh repeat is guarded')
}

await scenario('today not redeemable does not redeem', ({ api }) => { api.mission = { canRedeem: false, redeemPath: '', message: '今日已签到' } }, ({ settings, api, result }) => {
  assert.equal(result.reason, 'not-redeemable')
  assert.equal(api.fetchCalls, 1)
  assert.equal(api.redeemCalls, 0)
  assert.equal(settings.lastSuccessDate, localDateString())
})

await scenario('enabled cookie canRedeem fetches and redeems', () => {}, ({ settings, api, result }) => {
  assert.equal(result.reason, 'redeemed')
  assert.equal(result.redeemed, true)
  assert.equal(api.fetchCalls, 1)
  assert.equal(api.redeemCalls, 1)
  assert.deepEqual(api.lastRedeem, { cookie: 'A=B; PB3=ok', path: '/mission/daily/redeem?once=123' })
  assert.equal(settings.lastAttemptDate, localDateString())
  assert.equal(settings.lastSuccessDate, localDateString())
})

console.log('auto daily check-in behavior checks passed')
