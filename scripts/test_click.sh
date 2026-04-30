#!/bin/bash
# test_click.sh <label> <x> <y>
# Returns 0 on success, 1 on failure, 2 on crash
APP="com.next2v.app"
LABEL="$1"; X="$2"; Y="$3"

PID_BEFORE=$(hdc shell "pidof $APP" 2>&1 | tr -d '\r\n')
if [ -z "$PID_BEFORE" ]; then
  echo "FAIL: app not running before click"
  exit 3
fi

# Get before state
hdc shell "uitest dumpLayout" 2>&1 > /dev/null
sleep 0.5
LATEST=$(hdc shell "ls -t /data/local/tmp/layout_*.json 2>&1 | head -1" | tr -d '\r\n')
BEFORE="/tmp/layout_before_$$.json"
hdc file recv "$LATEST" "$BEFORE" 2>&1 > /dev/null

# Click
hdc shell "uitest uiInput click $X $Y" 2>&1 > /dev/null
sleep 1

# Check crash
PID_AFTER=$(hdc shell "pidof $APP" 2>&1 | tr -d '\r\n')
if [ -z "$PID_AFTER" ]; then
  echo "CRASH: app died after clicking $LABEL ($X,$Y)"
  exit 2
fi
if [ "$PID_BEFORE" != "$PID_AFTER" ]; then
  echo "CRASH: PID changed after clicking $LABEL ($X,$Y) ($PID_BEFORE→$PID_AFTER)"
  exit 2
fi

# Get after state
hdc shell "uitest dumpLayout" 2>&1 > /dev/null
sleep 0.5
LATEST=$(hdc shell "ls -t /data/local/tmp/layout_*.json 2>&1 | head -1" | tr -d '\r\n')
AFTER="/tmp/layout_after_$$.json"
hdc file recv "$LATEST" "$AFTER" 2>&1 > /dev/null

# Compare - count text items in content area (Y<1600, excluding tab bar at Y>1617)
BEFORE_COUNT=$(python3 -c "
import json
d=json.load(open('$BEFORE'))
def ct(n):
  c=0
  for ch in n.get('children',[]):
    a=ch.get('attributes',{})
    b=a.get('bounds','')
    if a.get('text','').strip() and '1675' not in b and b:
      c+=1
    c+=ct(ch)
  return c
print(ct(d))
" 2>&1)

AFTER_COUNT=$(python3 -c "
import json
d=json.load(open('$AFTER'))
def ct(n):
  c=0
  for ch in n.get('children',[]):
    a=ch.get('attributes',{})
    b=a.get('bounds','')
    if a.get('text','').strip() and '1675' not in b and b:
      c+=1
    c+=ct(ch)
  return c
print(ct(d))
" 2>&1)

echo "click $LABEL ($X,$Y): before=$BEFORE_COUNT items, after=$AFTER_COUNT items"

if [ "$BEFORE_COUNT" != "$AFTER_COUNT" ]; then
  echo "PASS: content changed"
  exit 0
else
  echo "FAIL: content unchanged (may need different coordinates)"
  exit 1
fi
