import { common } from '@kit.AbilityKit'
import BuildProfile from '../../../../BuildProfile'
import { AccountStore } from './AccountStore'
import type { AccountRecord, AccountRecordInput } from './AccountStore'

const SEED_USERNAME_PREFIX: string = 'qa_debug_user_'
const SEED_DEFAULT_BASE_URL: string = 'https://www.v2ex.com'

export interface AccountStoreQaSeedResult {
  scenario: string
  created: number
  notes: string[]
}

export class AccountStoreQaSeed {
  static isEnabled(): boolean {
    return BuildProfile.DEBUG
  }

  static assertEnabled(): void {
    if (!AccountStoreQaSeed.isEnabled()) {
      throw new Error('Account store QA seed is available only in debug builds')
    }
  }

  static async seedFakeAccounts(context: common.UIAbilityContext, count?: number): Promise<number> {
    AccountStoreQaSeed.assertEnabled()
    const targetCount = typeof count === 'number' && count > 0 ? count : 2
    let created = 0
    for (let i = 0; i < targetCount; i++) {
      const input: AccountRecordInput = {
        username: SEED_USERNAME_PREFIX + (i + 1).toString(),
        avatar: '',
        loginMode: 'cookie',
        baseUrl: SEED_DEFAULT_BASE_URL,
        cookieSnapshot: '',
        tokenSnapshot: '',
        validatedAt: Date.now(),
      }
      try {
        await AccountStore.add(context, input)
        created += 1
      } catch (_error) {
        // continue seeding remaining accounts
      }
    }
    return created
  }

  static async resetSeededAccounts(context: common.UIAbilityContext): Promise<void> {
    AccountStoreQaSeed.assertEnabled()
    const all = await AccountStore.getAll(context)
    const seedIds = all
      .filter((r: AccountRecord) => r.username.startsWith(SEED_USERNAME_PREFIX))
      .map((r: AccountRecord) => r.id)
    for (const id of seedIds) {
      try {
        await AccountStore.remove(context, id)
      } catch (_error) {
        // continue removing remaining accounts
      }
    }
  }
}
