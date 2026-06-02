/**
 * Denylist for the unified-settings whole-store backup dump.
 *
 * The plaintext backup exports the ENTIRE `next2v_settings` preferences store so newly added
 * settings are captured automatically — no per-field allowlist to maintain. That store, however,
 * also holds the network-proxy profiles (which embed the proxy password). This denylist is the
 * single guard that keeps those credential keys (and a few transient runtime breadcrumbs) out of
 * the plaintext envelope. Proxy profiles still travel in the encrypted userInfo section, handled
 * by BackupAccountAdapter.
 *
 * Matching is by case-insensitive substring so the rule is future-proof: any later key whose name
 * carries a credential marker is excluded without touching this file. We hardcode the lowercase
 * key markers here rather than importing StorageKeys, because the secret-exclusion contract forbids
 * the credential constant identifiers from appearing outside the encrypted-path account adapter.
 */
export class BackupSecretDenylist {
  // Case-insensitive markers of credential-bearing keys. 'proxy' covers networkProxySettings /
  // networkProxyProfiles / networkProxyActiveProfileId (the proxy profiles embed the password); the
  // rest are belt-and-suspenders for any future secret key so the plaintext dump stays clean.
  private static readonly SENSITIVE_SUBSTRINGS: string[] = [
    'password',
    'secret',
    'token',
    'cookie',
    'proxy',
    'credential',
  ]

  // Exact keys that are transient runtime breadcrumbs, not user settings: restoring a stale value
  // would mislead date/identity-based logic (e.g. skip a daily check-in), so they never get backed
  // up. The user-facing toggle (autoDailyCheckinEnabled) is NOT here and is backed up normally.
  private static readonly TRANSIENT_KEYS: string[] = [
    'autoDailyCheckinLastAttemptDate',
    'autoDailyCheckinLastAttemptIdentity',
    'autoDailyCheckinLastSuccessDate',
  ]

  /** True when the given preferences key must be excluded from the plaintext whole-store dump. */
  static isExcluded(key: string): boolean {
    const lower = key.toLowerCase()
    for (const fragment of BackupSecretDenylist.SENSITIVE_SUBSTRINGS) {
      if (lower.includes(fragment)) {
        return true
      }
    }
    return BackupSecretDenylist.TRANSIENT_KEYS.indexOf(key) >= 0
  }
}
