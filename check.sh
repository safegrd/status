#!/usr/bin/env bash
# Reads SafeGrd's status route and fails when the service or its monitor is
# not answering. Writes the reason to reason.txt and the job summary.
#
#   STATUS_URL      default https://safegrd.dev/api/v1/ops/status
#   WATCHDOG_TOKEN  the token the route takes
set -uo pipefail

url="${STATUS_URL:-https://safegrd.dev/api/v1/ops/status}"
max_pass_age=300   # the monitor runs every minute
max_page_age=1800  # a page nobody has fixed in 30 minutes

fail() {
  echo "$1" >reason.txt
  echo "Error: $1" >&2
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "**Failing:** $1" >>"$GITHUB_STEP_SUMMARY"
  exit 1
}

: >reason.txt
code=$(curl -sS -m 20 -o status.json -w '%{http_code}' \
  -H "Authorization: Bearer ${WATCHDOG_TOKEN:-}" "$url" 2>curl.err) ||
  fail "no answer from $url in 20 s: $(tail -n1 curl.err)"
[ "$code" = 200 ] || fail "$url answered $code"

now=$(jq -r '.server_time | sub("\\.[0-9]+"; "") | fromdateiso8601' status.json) ||
  fail "the answer is not the status JSON"
pass=$(jq -r '.ops_watch_last_pass // empty | sub("\\.[0-9]+"; "") | fromdateiso8601' status.json)
[ -n "$pass" ] || fail "the monitor has not finished a pass since the server started"
age=$((now - pass))
[ "$age" -le "$max_pass_age" ] || fail "the monitor's last pass was ${age}s ago"

pages=$(jq -r '.open_pages' status.json)
if [ "$pages" -gt 0 ]; then
  since=$(jq -r '.oldest_page_since | sub("\\.[0-9]+"; "") | fromdateiso8601' status.json)
  open_for=$((now - since))
  [ "$open_for" -le "$max_page_age" ] ||
    fail "$pages page(s) open, the oldest for $((open_for / 60)) minutes"
fi

summary=$(jq -r '"\(.open_pages) page(s) open. Canary: " + ([.canary[] | "\(.surface) (\(.type), \(.runs_on))" + (if .late then " LATE" else "" end)] | join(", "))' status.json)
echo "OK: monitor pass ${age}s ago. $summary"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "**Passing.** Monitor pass ${age}s ago. $summary" >>"$GITHUB_STEP_SUMMARY"
exit 0
