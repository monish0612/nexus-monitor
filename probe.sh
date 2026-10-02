#!/bin/sh
# Public uptime probe. Status codes only — never print URLs, tokens, or bodies.
set -u

note() { printf '%s\n' "$1"; }

if [ -z "${BASE_URL:-}" ]; then
  note "config=missing"
  exit 1
fi

base=${BASE_URL%/}
fail=0

http_code() {
  curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$1" || printf '000'
}

web=$(http_code "$base/")
health=$(http_code "$base/health")
narrator=$(http_code "$base/health/narrator")
note "web=$web health=$health narrator=$narrator"
[ "$web" = "200" ] || fail=1
[ "$health" = "200" ] || fail=1
[ "$narrator" = "200" ] || fail=1

token=
login=000
if [ -n "${NEXUS_SMOKE_API_KEY:-}" ]; then
  token=$NEXUS_SMOKE_API_KEY
  login=200
  note "credential=api_key"
else
  note "credential=password_login"
  login=$(curl -sS -o /tmp/nexus-login.json -w '%{http_code}' --max-time 20 \
    -H 'content-type: application/json' \
    -d "{\"username\":\"${SMOKE_APP_USER:-monish}\",\"password\":\"${SMOKE_APP_PASSWORD:-}\"}" \
    "$base/api/v1/auth/app-login" || printf '000')
  note "login=$login"
  token=$(python3 -c 'import json; print(json.load(open("/tmp/nexus-login.json")).get("token",""))' 2>/dev/null || true)
  rm -f /tmp/nexus-login.json
fi
[ "$login" = "200" ] || fail=1

backup=missing
if [ -n "$token" ]; then
  body=$(curl -sS --max-time 20 -H "authorization: Bearer $token" "$base/api/v1/ops/health" || printf '{}')
  hours=$(printf '%s' "$body" | python3 -c 'import json,sys
try:
    d=json.loads(sys.stdin.read() or "{}")
except Exception:
    d={}
h=d.get("backup_age_hours")
print("" if h is None else h)')
  if [ -z "$hours" ]; then
    backup=missing
    fail=1
  elif python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 26 else 1)' "$hours"; then
    backup=ok
  else
    backup=stale
    fail=1
  fi
else
  fail=1
fi
note "backup=$backup"

if [ "${FORCE_FAIL:-}" = "true" ]; then
  fail=1
  note "forced_fail=yes"
fi

state_file=${MONITOR_STATE:-.monitor-state/state}
mkdir -p "$(dirname "$state_file")"
prev=ok
if [ -f "$state_file" ]; then
  prev=$(cat "$state_file" 2>/dev/null || echo ok)
fi

send() {
  ALERT_TEXT=$1 python3 - <<'PY'
import os, urllib.request, urllib.error, json
body = json.dumps({
    "chat_id": os.environ.get("TELEGRAM_CHAT_ID", ""),
    "text": os.environ.get("ALERT_TEXT", ""),
}).encode()
url = "https://api.telegram.org/bot" + os.environ.get("TELEGRAM_BOT_TOKEN", "") + "/sendMessage"
req = urllib.request.Request(url, data=body, headers={"content-type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=20) as resp:
        print("alert_http=%s" % resp.status)
except urllib.error.HTTPError as err:
    print("alert_http=%s" % err.code)
except Exception:
    print("alert_http=err")
PY
}

if [ "$fail" = "1" ]; then
  if [ "$prev" != "down" ]; then
    send "Nexus monitor: down web=$web health=$health narrator=$narrator backup=$backup"
  fi
  printf 'down\n' > "$state_file"
  note "monitor=down"
  exit 1
fi

if [ "$prev" = "down" ]; then
  send "Nexus monitor: recovered"
fi
printf 'ok\n' > "$state_file"
note "monitor=ok"
