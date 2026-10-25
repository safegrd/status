# SafeGrd status

Checks run here, outside SafeGrd's own servers, so they still report when
those servers cannot.

| Workflow | Runs | What it does |
| :-- | :-- | :-- |
| `watchdog` | Every 15 minutes | Reads `https://safegrd.dev/api/v1/ops/status` and fails when it does not answer in 20 s, when SafeGrd's monitor has not run in 5 minutes, or when a page has been open for 30 minutes. Posts to Discord when the result changes. |
| `supabase-backup` | Backup every 6 hours, drill daily | Backs up a canary Supabase database with [safegrd/backup-action](https://github.com/safegrd/backup-action), the way a customer's workflow does. |
| `action-canary` | Daily | Backs up and drills a seeded PostgreSQL database with safegrd/backup-action, for a host whose key SafeGrd holds and for one that holds its own key. |
| `keepalive` | Weekly | Commits a dated line, because GitHub turns off scheduled workflows in a repository with no commit for 60 days. |

## Secrets

| Secret | Used by |
| :-- | :-- |
| `WATCHDOG_TOKEN` | `watchdog`: the bearer token the status route takes |
| `DISCORD_WEBHOOK` | `watchdog` |
| `SAFEGRD_CONFIG` | `supabase-backup`: the enrolled host's `safegrd.yaml` |
| `SUPABASE_DATABASE_URL` | `supabase-backup` |
| `ACTION_CANARY_CONFIG_MANAGED` | `action-canary`: `safegrd.yaml` of the host whose key SafeGrd holds |
| `ACTION_CANARY_CONFIG_LOCAL` | `action-canary`: `safegrd.yaml` of the host that holds its own key |
| `ACTION_CANARY_KEY_LOCAL` | `action-canary`: that host's `keys/daemon.key` |

## Run the check by hand

```sh
WATCHDOG_TOKEN=... ./check.sh
```
