import { webview } from '@kit.ArkWeb'
import { CookieJarSettings, DiagnosticLogger, V2exWebView } from 'shared'

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

  private maybeStartRun(): void {
    if (this.trigger <= 0 || this.active) {
      return
    }
    this.active = true
    this.step = 'pending'
    if (this.onRunStart) {
      this.onRunStart()
    }
    this.armTimeout()
  }

  build() {
    // Offscreen 1×1, fully transparent — present in the tree so it loads + runs JS, invisible to the user.
    Stack() {
      if (this.active) {
        V2exWebView({
          controller: this.controller,
          onControllerAttached: () => {
            this.onAttached()
          },
          onPageEnd: () => {
            this.onPageEnd()
          },
          onErrorReceive: () => {
            /* main-frame failures fall through to the timeout */
          },
        })
      }
    }
    .width(1)
    .height(1)
    .opacity(0)
    .hitTestBehavior(HitTestMode.None)
  }

  private onAttached(): void {
    if (this.step !== 'pending') {
      return
    }
    this.step = 'mission'
    // Make sure the WebView cookie jar carries the active account's session before loading.
    CookieJarSettings.restoreCurrentToWebCookieManager()
      .then(() => {
        this.safeLoad(`${this.baseUrl}/mission/daily`)
      })
      .catch(() => {
        this.safeLoad(`${this.baseUrl}/mission/daily`)
      })
  }

  private onPageEnd(): void {
    if (this.step === 'mission') {
      // Navigate to the 领取 button's redeem URL via a real browser navigation (passes the anti-bot).
      this.step = 'redeem'
      this.run(
        `(function(){var b=document.querySelector('input[value^="领取"]');if(b){var oc=b.getAttribute('onclick')||'';var m=oc.match(/\\/mission\\/daily\\/redeem\\?once=\\d+/);if(m){location.href=m[0];return 'GO';}b.click();return 'GO';}var t=(document.body&&document.body.innerText)||'';if(t.indexOf('已领取')>=0||t.indexOf('已完成')>=0)return 'DONE';return 'NOBTN';})()`,
      )
        .then((r: string) => {
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
          this.finish('failed', 0)
        })
    } else if (this.step === 'redeem') {
      // Redeem result page. SUCCESS requires POSITIVE confirmation (已领取/成功领取); the anti-bot wall and any
      // other page that merely lacks the 领取 button must NOT count as success (that was the false-success bug:
      // a wall page has no 领取 button, so the old `||!领取button` reported claimed without claiming).
      this.run(
        `(function(){var t=(document.body&&document.body.innerText)||'';if(t.indexOf('奇奇怪怪')>=0||t.indexOf('干净')>=0)return 'RWall';if(t.indexOf('已领取')>=0||t.indexOf('成功领取')>=0||t.indexOf('已成功')>=0)return 'RClaimed';if(document.querySelector('input[value^="领取"]'))return 'RNoClaim';return 'RUnknown:'+t.slice(0,80);})()`,
      )
        .then((r: string) => {
          DiagnosticLogger.info('auto_daily_checkin', 'redeem_result', { result: r })
          if (r.indexOf('RClaimed') >= 0) {
            this.step = 'balance'
            this.safeLoad(`${this.baseUrl}/balance`)
          } else {
            this.finish('failed', 0)
          }
        })
        .catch(() => {
          this.finish('failed', 0)
        })
    } else if (this.step === 'balance') {
      // Read the reward (铜币) from the balance table. The 每日登录 row is [desc, delta, balance, …]; the
      // delta cell right after the first cell that names 每日登录 is the reward — position-independent so a
      // V2EX column reshuffle won't grab the running balance by mistake.
      this.run(
        `(function(){var rs=document.querySelectorAll('table tr');for(var i=0;i<rs.length;i++){var ds=rs[i].querySelectorAll('td');for(var j=0;j+1<ds.length;j++){if((ds[j].innerText||'').indexOf('每日登录')>=0){var n=parseFloat(((ds[j+1].innerText)||'').replace(/[^0-9.]/g,''));if(n>0)return String(n);}}}return '0';})()`,
      )
        .then((r: string) => {
          this.finish('success', this.parseAmount(r))
        })
        .catch(() => {
          this.finish('success', 0)
        })
    }
  }

  private run(script: string): Promise<string> {
    try {
      return this.controller.runJavaScript(script)
    } catch (_e) {
      return Promise.reject(new Error('runJavaScript failed'))
    }
  }

  private safeLoad(url: string): void {
    try {
      this.controller.loadUrl(url)
    } catch (_e) {
      this.finish('failed', 0)
    }
  }

  private parseAmount(raw: string): number {
    const n = Number.parseFloat((raw || '').replace(/[^0-9.]/g, ''))
    return Number.isFinite(n) && n > 0 ? n : 0
  }

  private armTimeout(): void {
    this.clearTimer()
    this.timeoutId = setTimeout(() => {
      if (this.active) {
        this.finish('failed', 0)
      }
    }, 25000)
  }

  private clearTimer(): void {
    if (this.timeoutId !== -1) {
      clearTimeout(this.timeoutId)
      this.timeoutId = -1
    }
  }

  private finish(status: string, rewardCoins: number): void {
    if (this.step === 'idle') {
      return
    }
    DiagnosticLogger.info('auto_daily_checkin', 'finish', {
      fromStep: this.step,
      status: status,
      rewardCoins: rewardCoins,
    })
    this.step = 'idle'
    this.active = false
    this.clearTimer()
    if (this.onRunResult) {
      this.onRunResult(status, rewardCoins)
    }
  }
}
