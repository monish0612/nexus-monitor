# Nexus monitor

Public uptime check for Nexus. The probe target and alert credentials live in repository secrets (`BASE_URL`, `NEXUS_SMOKE_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`).

`NEXUS_SMOKE_API_KEY` must be a read-only key. The probe used to fall back to
signing in as the owner, so a job on a schedule held a password that can write
anything; there is no fallback now, and a missing key is reported as a failure
rather than quietly skipped.

Logs contain HTTP status codes and `monitor=ok` or `monitor=down`. They do not contain URLs, tokens, or response bodies.

The workflow runs every 30 minutes and alerts only when the state changes. Dispatch it with `fail=true` to send one down alert.
