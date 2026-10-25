// Passive observation only: never click, solve, replace or change the site's challenge.
// Cloudflare's current widget maps interactiveBegin to before-interactive-callback.
// This is a compatibility signal, not a stable Challenge Page API. Missing signals
// must remain unknown/waiting, never become a guessed request for human input.
export const CHECKIN_CHALLENGE_OBSERVER: string = `(function(){
  if(window.top!==window)return;
  window.__v2nextCheckinInteractive=false;
  var states=[];
  // ArkWeb omits closed-shadow-root iframes from window.frames. The cross-origin
  // Window.parent property still proves the sender is a direct child of this document.
  function isChild(source){try{return !!source&&source!==window&&source.parent===window&&!source.closed;}catch(_e){return false;}}
  window.__v2nextCheckinNeedsInteraction=function(){
    return states.some(function(s){
      if(!s.interactive)return false;
      return isChild(s.source);
    });
  };
  window.addEventListener('message',function(e){
    if(!e.isTrusted||e.origin!=='https://challenges.cloudflare.com')return;
    var d=e.data;
    if(!d||d.source!=='cloudflare-challenge'||typeof d.widgetId!=='string'||!d.widgetId)return;
    if(!isChild(e.source))return;
    if(['interactiveBegin','interactiveEnd','complete','fail','interactiveTimeout'].indexOf(d.event)<0)return;
    var item;for(var j=0;j<states.length;j++){if(states[j].source===e.source&&states[j].id===d.widgetId)item=states[j];}
    if(!item){item={source:e.source,id:d.widgetId,interactive:false};states.push(item);}
    item.interactive=d.event==='interactiveBegin';
    window.__v2nextCheckinInteractive=states.some(function(s){return s.interactive;});
  });
})()`

export const CHECKIN_PAGE_STATE: string = `(function(){
  var t=(document.body&&document.body.innerText)||'';
  var challenge=!!window._cf_chl_opt||!!document.querySelector('script[src*="/cdn-cgi/challenge-platform/"]');
  if(challenge)return typeof window.__v2nextCheckinNeedsInteraction==='function'&&window.__v2nextCheckinNeedsInteraction()?'interactive':'challenge';
  if(location.href==='about:blank'||!document.body)return 'loading';
  return 'content';
})()`
