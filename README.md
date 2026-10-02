# Nexus monitor

Public uptime check for Nexus. The probe target and alert credentials live in repository secrets (`BASE_URL`, `SMOKE_APP_PASSWORD` or `NEXUS_SMOKE_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`).

Logs contain HTTP status codes and `monitor=ok` or `monitor=down`. They do not contain URLs, tokens, or response bodies.

The workflow runs every 30 minutes and alerts only when the state changes. Dispatch it with `fail=true` to send one down alert.
