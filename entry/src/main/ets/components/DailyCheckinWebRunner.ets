import { AlertDialogV2, AdvancedDialogV2Button } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import { AppPrompt, connectAppForeground, CookieJarSettings, DiagnosticLogger, V2exWebView } from 'shared'
import { CHECKIN_CHALLENGE_OBSERVER, CHECKIN_PAGE_STATE } from './checkin/CheckinChallengeScripts'

/**
 * Hidden-WebView daily check-in. V2EX guards /mission/daily/redeem with a TLS/JS-fingerprint anti-bot that
 * a raw HTTP GET cannot pass (verified on-device: exact UA + full client-hint headers are all rejected with
 * "请用一个干净安装的浏览器重试"). A real ArkWeb engine DOES pass it, so the redeem runs inside an offscreen
 * 1×1 Web: load /mission/daily → navigate to the 领取 button's redeem URL (a real browser navigation) →
 * verify it claimed → read the 铜币 reward from /balance. The caller (manual 签到 button or auto-checkin)
 * bumps `trigger` and reads back the result via onRunResult.
 */
@ComponentV2
export struct DailyCheckinWebRunner {
  // Bump to a new positive value to start a run (a timestamp/counter from the caller).
  @Param trigger: number = 0;
  @Param baseUrl: string = 'https://www.v2ex.com';
  // status: 'success' (rewardCoins set) | 'already' (already checked in) | 'failed'.
  @Event onRunResult?: (status: string, rewardCoins: number) => void;
  // Fired the moment a run actually starts (used by the auto path to show the "签到中" toast from the
  // mounted nav shell, where a UI window is ready).
  @Event onRunStart?: () => void;

  private controller: webview.WebviewController = new webview.WebviewController();
  @Local private active: boolean = false;
  // 'idle' | 'pending' (waiting for controller) | 'mission' | 'redeem' | 'balance'
  @Local private step: string = 'idle';
  private timeoutId: number = -1;
  // A claim confirmed by V2EX cannot be undone by the optional reward lookup.
  private claimConfirmed: boolean = false;
  // Async work from a timed-out/unmounted run must never complete a later run.
  private runGeneration: number = 0;
  private startedAt: number = 0;
  private runCookie: string = '';
  private controllerIsAttached: boolean = false;
  private pollId: number = -1;
  private inspecting: boolean = false;
  private contentHandled: boolean = false;
  private promptId: number = -1;
  private promptGeneration: number = -1;
  private pageGeneration: number = 0;
  private challengeSeen: boolean = false;
  private promptShown: boolean = false;
  @Local private manualMode: boolean = false;
  @Local private verificationVisible: boolean = false;
  private verificationController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    // The caller may bump `trigger` BEFORE this runner mounts — the auto check-in hands off the redeem
    // during pre-UI startup, which can land before loadContent. @Monitor('trigger') only fires on a change
    // AFTER mount, so it would miss that initial value and the redeem (and toast) would never run. Start
    // from the current value here too.
    this.maybeStartRun()
  }

  @Monitor('trigger')
  onTriggerChange(): void {
    this.maybeStartRun()
  }

  aboutToDisappear(): void {
    this.runGeneration += 1
    this.clearTimer()
    this.closeVerificationPrompt()
    this.step = 'idle'
    this.controllerIsAttached = false
    this.active = false
  }

  private maybeStartRun(): void {
    let reuseController = false
    if (this.active && !this.isCurrentRun(this.runGeneration)) {
      reuseController = !this.manualMode && this.controllerIsAttached
      try { (this.manualMode ? this.verificationController : this.controller).stop() } catch (_e) {}
      this.finish('failed', 0)
    }
    if (this.trigger <= 0 || this.active) {
      return
    }
    // The visible web-login page deliberately owns the shared ArkWeb cookie
    // jar. Starting a hidden mission page here could replace its fresh signin
    // session with the persisted account session before form submission.
    if (CookieJarSettings.isWebLoginCookieIsolationActive()) {
      return
    }
    this.runGeneration += 1
    this.runCookie = CookieJarSettings.getCurrentCookie()
    this.claimConfirmed = false
    this.inspecting = false
    this.contentHandled = false
    this.challengeSeen = false
    this.promptShown = false
    this.manualMode = false
    this.active = true
    this.step = 'pending'
    this.startedAt = Date.now()
    this.logPhase('web_run_started')
    if (this.onRunStart) {
      this.onRunStart()
    }
    this.armTimeout()
    // A same-frame account replacement can retain the mounted Web. Reuse its
    // controller explicitly rather than relying on another attachment callback.
    if (reuseController) {
      this.controllerIsAttached = true
      this.onAttached()
    }
  }

  build() {
    // Offscreen 1×1, fully transparent — present in the tree so it loads + runs JS, invisible to the user.
    Stack() {
      if (this.active && !this.manualMode) {
        V2exWebView({
          controller: this.controller,
          documentStartScripts: [{ script: CHECKIN_CHALLENGE_OBSERVER, scriptRules: [this.baseUrl] }],
          onControllerAttached: () => {
            this.controllerIsAttached = true
            this.onAttached()
          },
          onPageBegin: () => { this.onPageBegin() },
          onPageEnd: (event?: OnPageEndEvent) => {
            this.onPageEnd(event)
          },
          onErrorReceive: () => {
            // May include subresource errors: record it without declaring the claim failed.
            this.logPhase('web_load_error')
          },
        })
      }
    }
    .width(1)
    .height(1)
    .opacity(0)
    .hitTestBehavior(HitTestMode.None)
    .bindSheet($$this.verificationVisible, this.VerificationContent(), {
      height: SheetSize.LARGE,
      title: { title: $r('app.string.checkin_verification_title') },
      onDisappear: () => {
        if (this.active && this.manualMode) this.finish('failed', 0)
      },
    })
  }

  @Builder
  private VerificationContent() {
    List() {
      V2exWebView({
        controller: this.verificationController,
        documentStartScripts: [{ script: CHECKIN_CHALLENGE_OBSERVER, scriptRules: [this.baseUrl] }],
        onControllerAttached: () => {
          // Re-open the mission, never replay a redeem URL: it may already have claimed.
          this.step = 'mission'
          this.safeLoad(`${this.baseUrl}/mission/daily`)
        },
        onPageBegin: () => { this.onPageBegin() },
        onPageEnd: (event?: OnPageEndEvent) => { this.onPageEnd(event) },
        onErrorReceive: () => { this.logPhase('web_load_error') },
      })
    }.width('100%').height('100%')
  }

  private onAttached(): void {
    if (this.step !== 'pending') {
      return
    }
    if (CookieJarSettings.isWebLoginCookieIsolationActive()) {
      this.step = 'idle'
      this.active = false
      this.clearTimer()
      return
    }
    this.logPhase('web_controller_attached')
    const generation = this.runGeneration
    // Make sure the WebView cookie jar carries the active account's session before loading.
    CookieJarSettings.restoreCurrentToWebCookieManager()
      .then(() => {
        if (!this.isCurrentRun(generation)) {
          return
        }
        if (CookieJarSettings.isWebLoginCookieIsolationActive()) {
          this.step = 'idle'
          this.active = false
          this.clearTimer()
          return
        }
        this.step = 'mission'
        this.safeLoad(`${this.baseUrl}/mission/daily`)
      })
      .catch(() => {
        if (!this.isCurrentRun(generation)) {
          return
        }
        if (CookieJarSettings.isWebLoginCookieIsolationActive()) {
          this.step = 'idle'
          this.active = false
          this.clearTimer()
          return
        }
        this.step = 'mission'
        this.safeLoad(`${this.baseUrl}/mission/daily`)
      })
  }

  private clearPoll(): void {
    if (this.pollId !== -1) {
      clearTimeout(this.pollId)
      this.pollId = -1
    }
  }

  private onPageBegin(): void {
    this.pageGeneration += 1
    this.contentHandled = false
    this.inspecting = false
    this.clearPoll()
  }

  private onPageEnd(event?: OnPageEndEvent): void {
    if (event) this.logPhase('web_page_end', this.pageKind(event.url))
    if (!this.active || this.step === 'pending' || this.inspecting || this.contentHandled) return
    if (event && this.pageKind(event.url) === 'blank') return
    const generation = this.runGeneration
    this.inspecting = true
    const pageGeneration = this.pageGeneration
    this.run(CHECKIN_PAGE_STATE).then((raw: string) => {
      if (!this.isCurrentRun(generation) || pageGeneration !== this.pageGeneration) return
      this.inspecting = false
      const state = raw.replace(/^"|"$/g, '')
      if (state === 'challenge' || state === 'interactive' || state === 'loading') {
        if (!this.challengeSeen && state !== 'loading') {
          this.challengeSeen = true
          this.logPhase('web_challenge_wait')
          // Keep the same browser alive for automatic verification. This is not a
          // retry/reload and a timeout is never interpreted as manual interaction.
          this.armTimeout(60000)
        }
        if (state === 'interactive' && !this.manualMode && !this.promptShown &&
          connectAppForeground().foreground) this.offerVerification()
        this.scheduleInspection(generation)
        return
      }
      if (this.challengeSeen) this.logPhase('web_challenge_resolved')
      this.clearPoll()
      this.closeVerificationPrompt()
      this.contentHandled = true
      this.handleContent()
    }).catch(() => {
      if (!this.isCurrentRun(generation) || pageGeneration !== this.pageGeneration) return
      this.inspecting = false
      this.logPhase('web_inspection_error')
      this.scheduleInspection(generation)
    })
  }

  private scheduleInspection(generation: number): void {
    if (this.pollId !== -1) clearTimeout(this.pollId)
    this.pollId = setTimeout(() => {
      this.pollId = -1
      if (this.isCurrentRun(generation)) this.onPageEnd()
    }, 500)
  }

  private offerVerification(): void {
    this.promptShown = true
    this.logPhase('web_interaction_required')
    const generation = this.runGeneration
    this.promptGeneration = generation
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: () => { this.VerificationPrompt(generation) },
      systemMaterial: AppPrompt.modalSystemMaterial(),
      onWillDismiss: (action: DismissDialogAction) => {
        action.dismiss()
        if (this.promptGeneration !== generation) return
        const userDismissed = this.promptId !== -1
        this.promptId = -1
        this.promptGeneration = -1
        if (userDismissed && this.isCurrentRun(generation)) this.finish('failed', 0)
      },
    }).then((id: number) => {
      if (!this.isCurrentRun(generation) || this.contentHandled || this.promptGeneration !== generation) {
        this.getUIContext().getPromptAction().closeCustomDialog(id)
        return
      }
      this.promptId = id
    }).catch(() => {
      if (this.isCurrentRun(generation) && this.promptGeneration === generation && !this.contentHandled) {
        this.finish('failed', 0)
      }
    })
  }

  @Builder
  private VerificationPrompt(generation: number) {
    AlertDialogV2({
      primaryTitle: $r('app.string.checkin_verification_title'),
      content: $r('app.string.checkin_verification_message'),
      primaryButton: new AdvancedDialogV2Button({
        content: $r('app.string.common_cancel'),
        action: () => { if (this.isCurrentRun(generation)) this.finish('failed', 0) },
      }),
      secondaryButton: new AdvancedDialogV2Button({
        content: $r('app.string.checkin_verify_action'),
        action: () => { if (this.isCurrentRun(generation)) this.openVerification() },
      }),
    })
  }

  private closeVerificationPrompt(): void {
    this.promptGeneration = -1
    if (this.promptId === -1) return
    const id = this.promptId
    this.promptId = -1
    try { this.getUIContext().getPromptAction().closeCustomDialog(id) } catch (_e) {}
  }

  private openVerification(): void {
    if (!this.isCurrentRun(this.runGeneration) || this.contentHandled) return
    this.clearTimer()
    this.runGeneration += 1
    this.closeVerificationPrompt()
    this.inspecting = false
    this.contentHandled = false
    this.manualMode = true
    this.step = 'pending'
    this.verificationVisible = true
    this.armTimeout(120000)
  }

  private handleContent(): void {
    const generation = this.runGeneration
    const pageGeneration = this.pageGeneration
    if (this.step === 'mission') {
      // Navigate to the 领取 button's redeem URL via a real browser navigation (passes the anti-bot).
      this.step = 'redeem'
      this.run(
        `(function(){var b=document.querySelector('input[value^="领取"]');if(b){var oc=b.getAttribute('onclick')||'';var m=oc.match(/\\/mission\\/daily\\/redeem\\?once=\\d+/);if(m){location.href=m[0];return 'GO';}b.click();return 'GO';}var t=(document.body&&document.body.innerText)||'';if(t.indexOf('已领取')>=0||t.indexOf('已完成')>=0)return 'DONE';return 'NOBTN';})()`,
      )
        .then((r: string) => {
          if (!this.isCurrentRun(generation) || pageGeneration !== this.pageGeneration) {
            return
          }
          DiagnosticLogger.info('auto_daily_checkin', 'mission_result', { result: r })
          if (r.indexOf('GO') >= 0) {
            // navigation triggers onPageEnd again with step==='redeem'
            return
          }
          if (r.indexOf('DONE') >= 0) {
            this.finish('already', 0)
            return
          }
          // 'NOBTN' (button gone but no already-done text) — do NOT treat as success; report failure.
          this.finish('failed', 0)
        })
        .catch(() => {
          if (this.isCurrentRun(generation) && pageGeneration === this.pageGeneration) {
            this.finish('failed', 0)
          }
        })
    } else if (this.step === 'redeem') {
      // Redeem result page. SUCCESS requires POSITIVE confirmation (已领取/成功领取); the anti-bot wall and any
      // other page that merely lacks the 领取 button must NOT count as success (that was the false-success bug:
      // a wall page has no 领取 button, so the old `||!领取button` reported claimed without claiming).
      this.run(
        `(function(){var t=(document.body&&document.body.innerText)||'';if(t.indexOf('奇奇怪怪')>=0||t.indexOf('干净')>=0)return 'RWall';if(t.indexOf('已领取')>=0||t.indexOf('成功领取')>=0||t.indexOf('已成功')>=0)return 'RClaimed';if(document.querySelector('input[value^="领取"]'))return 'RNoClaim';return 'RUnknown:'+t.slice(0,80);})()`,
      )
        .then((r: string) => {
          if (!this.isCurrentRun(generation) || pageGeneration !== this.pageGeneration) {
            return
          }
          DiagnosticLogger.info('auto_daily_checkin', 'redeem_result', { result: r })
          if (r.indexOf('RClaimed') >= 0) {
            this.claimConfirmed = true
            this.step = 'balance'
            this.safeLoad(`${this.baseUrl}/balance`)
          } else {
            this.finish('failed', 0)
          }
        })
        .catch(() => {
          if (this.isCurrentRun(generation) && pageGeneration === this.pageGeneration) {
            this.finish('failed', 0)
          }
        })
    } else if (this.step === 'balance') {
      // Read the reward (铜币) from the balance table. The 每日登录 row is [desc, delta, balance, …]; the
      // delta cell right after the first cell that names 每日登录 is the reward — position-independent so a
      // V2EX column reshuffle won't grab the running balance by mistake.
      this.run(
        `(function(){var rs=document.querySelectorAll('table tr');for(var i=0;i<rs.length;i++){var ds=rs[i].querySelectorAll('td');for(var j=0;j+1<ds.length;j++){if((ds[j].innerText||'').indexOf('每日登录')>=0){var n=parseFloat(((ds[j+1].innerText)||'').replace(/[^0-9.]/g,''));if(n>0)return String(n);}}}return '0';})()`,
      )
        .then((r: string) => {
          if (!this.isCurrentRun(generation) || pageGeneration !== this.pageGeneration) {
            return
          }
          this.finish('success', this.parseAmount(r))
        })
        .catch(() => {
          if (this.isCurrentRun(generation) && pageGeneration === this.pageGeneration) {
            this.finish('success', 0)
          }
        })
    }
  }

  private run(script: string): Promise<string> {
    try {
      return (this.manualMode ? this.verificationController : this.controller).runJavaScript(script)
    } catch (_e) {
      return Promise.reject(new Error('runJavaScript failed'))
    }
  }

  private isCurrentRun(generation: number): boolean {
    return this.active && this.runGeneration === generation &&
      this.runCookie === CookieJarSettings.getCurrentCookie() && !CookieJarSettings.isWebLoginCookieIsolationActive()
  }

  // Never log page URLs: redeem URLs contain once tokens and redirects can contain session data.
  private pageKind(url: string): string {
    const clean = url.split('?')[0].split('#')[0]
    if (!clean || clean === 'about:blank') {
      return 'blank'
    }
    if (clean === `${this.baseUrl}/mission/daily/redeem`) {
      return 'redeem'
    }
    if (clean === `${this.baseUrl}/mission/daily`) {
      return 'mission'
    }
    if (clean === `${this.baseUrl}/balance`) {
      return 'balance'
    }
    if (clean === `${this.baseUrl}/signin`) {
      return 'signin'
    }
    if (clean === `${this.baseUrl}/2fa`) {
      return 'two-factor'
    }
    return 'other'
  }

  private logPhase(event: string, page: string = ''): void {
    if (!this.active) {
      return
    }
    DiagnosticLogger.info('auto_daily_checkin', event, {
      step: this.step,
      page: page,
      elapsedMs: Date.now() - this.startedAt,
      claimConfirmed: this.claimConfirmed,
    })
  }

  private safeLoad(url: string): void {
    try {
      (this.manualMode ? this.verificationController : this.controller).loadUrl(url)
    } catch (_e) {
      this.logPhase('web_navigation_error', this.pageKind(url))
      this.finish('failed', 0)
    }
  }

  private parseAmount(raw: string): number {
    const n = Number.parseFloat((raw || '').replace(/[^0-9.]/g, ''))
    return Number.isFinite(n) && n > 0 ? n : 0
  }

  private armTimeout(durationMs: number = 25000): void {
    this.clearTimer()
    this.timeoutId = setTimeout(() => {
      if (this.active) {
        this.logPhase('web_run_timeout')
        this.finish('failed', 0)
      }
    }, durationMs)
  }

  private clearTimer(): void {
    if (this.pollId !== -1) {
      clearTimeout(this.pollId)
      this.pollId = -1
    }
    if (this.timeoutId !== -1) {
      clearTimeout(this.timeoutId)
      this.timeoutId = -1
    }
  }

  private finish(status: string, rewardCoins: number): void {
    if (this.step === 'idle') {
      return
    }
    // /balance is enrichment only: timeout/load errors after RClaimed still mean
    // the day was signed. Keep failure for every unconfirmed redeem, including walls.
    const sameSession = this.runCookie === CookieJarSettings.getCurrentCookie() &&
      !CookieJarSettings.isWebLoginCookieIsolationActive()
    const finalStatus = this.claimConfirmed ? 'success' : status
    DiagnosticLogger.info('auto_daily_checkin', 'finish', {
      fromStep: this.step,
      status: finalStatus,
      rewardCoins: rewardCoins,
    })
    this.step = 'idle'
    this.controllerIsAttached = false
    this.active = false
    this.verificationVisible = false
    this.runGeneration += 1
    this.clearTimer()
    this.closeVerificationPrompt()
    // Verification can outlive an account switch. Never publish the old account's
    // claim result into the newly active account (or overwrite an isolated login).
    if (sameSession && this.onRunResult) {
      this.onRunResult(finalStatus, rewardCoins)
    }
  }
}
