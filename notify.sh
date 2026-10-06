#!/usr/bin/env bash
# Posts to Discord when the watchdog's result changes: a failure after a pass
# (or after no run at all), and a pass after a failure. The previous result is
# the last completed run of this workflow, read from GitHub's API.
#
#   OUTCOME          this run's check step: success or failure
#   DISCORD_WEBHOOK  where to post
#   GH_TOKEN, GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_SERVER_URL  set by Actions
#   PREVIOUS         overrides the API lookup (for testing)
set -uo pipefail

if [ -z "${PREVIOUS+x}" ]; then
  PREVIOUS=$(gh api "repos/$GITHUB_REPOSITORY/actions/workflows/watchdog.yml/runs?status=completed&per_page=10" \
    --jq "[.workflow_runs[] | select(.id != $GITHUB_RUN_ID) | select(.conclusion == \"success\" or .conclusion == \"failure\")][0].conclusion // \"none\"") ||
    PREVIOUS=unknown
fi
run_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}"
reason=$(cat reason.txt 2>/dev/null)

case "$OUTCOME/$PREVIOUS" in
  failure/success | failure/none | failure/unknown)
    msg="**Watchdog: safegrd.dev is failing.** ${reason:-The check failed.} $run_url" ;;
  success/failure)
    msg="**Watchdog: safegrd.dev passes again.** $run_url" ;;
  *)
    echo "No change ($PREVIOUS -> $OUTCOME); nothing posted."
    exit 0 ;;
esac

if [ -z "${DISCORD_WEBHOOK:-}" ]; then
  echo "Warning: DISCORD_WEBHOOK is not set; not posted: $msg" >&2
  exit 1
fi
jq -n --arg c "$msg" '{content: $c, allowed_mentions: {parse: []}}' |
  curl -sS -m 20 -f -H 'Content-Type: application/json' -d @- "$DISCORD_WEBHOOK" >/dev/null ||
  { echo "Error: Discord refused the message" >&2; exit 1; }
echo "Posted: $msg"
