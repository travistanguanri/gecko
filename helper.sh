#!/bin/bash
# Snapshot app helper (Mac).
# Every 2 seconds it looks at which app is in front. While that is Claude,
# ChatGPT or VS Code, and they are typing in it, it tells the sheet so (at
# most once a minute per app) and opens the form tab when the sheet says a
# form is due. Reading or scrolling does not count for that. Separately, each
# time one of those apps comes to the front, it tells the sheet how long it
# stayed there. Outside a discussion the sheet records nothing.
# It never looks inside any app, never sees which keys are pressed, and no
# other app's name ever leaves the laptop.

ENDPOINT="https://script.google.com/macros/s/AKfycbzzvFWZZp-xoufGymrCWWDuZzNkuG7kjfGOglel1QkP1NMFvMZPq_Ut0YVq76HqccK0/exec"
SITE="https://travistanguanri.github.io/snapshot"
CODE="$(cat "$HOME/.snapshot/code.txt")"

# The app in front, as the name written to the sheet. Empty for any other app.
tool_in_front() {
  local app
  app="$(lsappinfo info -only bundleid "$(lsappinfo front)" 2>/dev/null | sed -n 's/.*="\(.*\)"$/\1/p')"
  case "$app" in
    com.anthropic.claudefordesktop) echo "Claude" ;;
    com.openai.chat) echo "ChatGPT" ;;
    com.microsoft.VSCode) echo "VS Code" ;;
  esac
}

# Seconds since a key was last pressed, in any app. macOS gives only the time,
# never the key, and asks for no permission. If it cannot say, fall back to
# seconds since the keyboard or mouse was last touched.
seconds_since_typing() {
  osascript -l JavaScript -e 'ObjC.import("CoreGraphics"); Math.floor($.CGEventSourceSecondsSinceLastEventType(0, 10))' 2>/dev/null \
    || ioreg -c IOHIDSystem | awk '/HIDIdleTime/ { print int($NF / 1000000000); exit }'
}

# An AI app was in front from $2 to $3 (seconds). Sent in the background so
# the checks carry on; outside a discussion the sheet keeps nothing.
tell_open() {
  curl -sL --max-time 20 -G "$ENDPOINT" --data-urlencode "action=open" --data-urlencode "code=$CODE" \
    --data-urlencode "tool=$1" --data-urlencode "source=app-mac" \
    --data-urlencode "start=$2" --data-urlencode "end=$3" >/dev/null 2>&1 &
}

front_tool=""   # the AI app in front, and when it was first seen there
front_since=0
last_tick="$(date +%s)"  # the last check: a long gap since then means the laptop slept
last_tool=""    # the last use told to the sheet
last_sent=0

while true; do
  sleep 2
  tool="$(tool_in_front)"
  now="$(date +%s)"
  # Asleep since the last check: the app stopped being looked at then.
  if [ -n "$front_tool" ] && [ $((now - last_tick)) -gt 30 ]; then
    tell_open "$front_tool" "$front_since" "$last_tick"
    front_tool=""
  fi
  last_tick="$now"
  if [ "$tool" != "$front_tool" ]; then
    [ -n "$front_tool" ] && tell_open "$front_tool" "$front_since" "$now"
    front_tool="$tool"
    front_since="$now"
  fi
  [ -z "$tool" ] && continue
  # A use is typing in this app: a key pressed in the last 30 seconds, and
  # since the app came to the front (so the shortcut that switched to it,
  # or typing done in another app, does not count).
  typed="$(seconds_since_typing)"
  { [ "${typed:-0}" -ge 30 ] || [ "${typed:-0}" -ge $((now - front_since)) ]; } && continue
  [ "$tool" = "$last_tool" ] && [ $((now - last_sent)) -lt 60 ] && continue
  last_tool="$tool"
  last_sent="$now"

  reply="$(curl -sL --max-time 10 -G "$ENDPOINT" \
    --data-urlencode "action=use" --data-urlencode "code=$CODE" --data-urlencode "tool=$tool" \
    --data-urlencode "source=app-mac" --data-urlencode "t=$now")"
  if [ "$reply" = "yes" ]; then
    # After the #: which sign-up this helper is linked to. That part of an
    # address stays in the browser; Snapshot compares it with its own.
    url="$SITE/form.html?tool=${tool// /%20}&source=app-mac#helper=$CODE"
    open -a "Google Chrome" "$url" 2>/dev/null || open "$url"
  fi
done
