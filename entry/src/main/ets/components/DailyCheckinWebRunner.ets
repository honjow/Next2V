import { webview } from '@kit.ArkWeb'
import { CookieJarSettings, V2exWebView } from 'shared'

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

  private controller: webview.WebviewController = new webview.WebviewController();
  @Local private active: boolean = false;
  // 'idle' | 'pending' (waiting for controller) | 'mission' | 'redeem' | 'balance'
  @Local private step: string = 'idle';
  private timeoutId: number = -1;

  @Monitor('trigger')
  onTriggerChange(): void {
    if (this.trigger <= 0 || this.active) {
      return
    }
    this.active = true
    this.step = 'pending'
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
        `(function(){var b=document.querySelector('input[value^="领取"]');if(!b)return 'none';var oc=b.getAttribute('onclick')||'';var m=oc.match(/\\/mission\\/daily\\/redeem\\?once=\\d+/);if(m){location.href=m[0];return 'go';}b.click();return 'go';})()`,
      )
        .then((r: string) => {
          if (r.indexOf('none') >= 0) {
            this.finish('already', 0)
          }
          // 'go' → the navigation triggers onPageEnd again with step==='redeem'.
        })
        .catch(() => {
          this.finish('failed', 0)
        })
    } else if (this.step === 'redeem') {
      // Redeem result page: claimed iff the 领取 button is gone (page shows 已领取 / 查看账户余额).
      this.run(
        `(function(){var t=(document.body&&document.body.innerText)||'';if(t.indexOf('已领取')>=0||!document.querySelector('input[value^="领取"]'))return 'ok';return 'fail';})()`,
      )
        .then((r: string) => {
          if (r.indexOf('ok') >= 0) {
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
    this.step = 'idle'
    this.active = false
    this.clearTimer()
    if (this.onRunResult) {
      this.onRunResult(status, rewardCoins)
    }
  }
}
