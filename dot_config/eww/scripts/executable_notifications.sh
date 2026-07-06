#!/usr/bin/env bash
# Called by defpoll every 2s
# Reads /tmp/eww_notifications.json, outputs notif_count + yuck literal for notification list

LOG_FILE="/tmp/eww_notifications.json"
[ ! -f "$LOG_FILE" ] && echo "[]" > "$LOG_FILE"

count=$(jq 'length' "$LOG_FILE" 2>/dev/null || echo 0)
echo "notif_count=$count"

if [ "$count" -eq 0 ] 2>/dev/null; then
    echo "notifications=(label :class \"notif-empty\" \"All caught up\")"
    exit 0
fi

# Build yuck literal: group by "just now" (<2min) and "earlier"
now=$(date +%s)
cutoff=$((now - 120))

output=""
jq -c '.[] | {app: .app, title: .title, body: .body, timestamp: .timestamp}' "$LOG_FILE" 2>/dev/null \
| while IFS= read -r item; do
    app=$(echo "$item" | jq -r '.app // "dunst"')
    title=$(echo "$item" | jq -r '.title // ""')
    body=$(echo "$item" | jq -r '.body // ""')
    ts=$(echo "$item" | jq -r '.timestamp // ""')
    ts_epoch=$(date -d "$ts" +%s 2>/dev/null || echo 0)
    if [ "$ts_epoch" -ge "$cutoff" ] 2>/dev/null; then
        group="just_now"
    else
        group="earlier"
    fi
    echo "notif:${group}:${app}:${title}:${body}:${ts}"
done | while IFS=: read -r _ group app title body ts; do
    echo "(box :class \"notif-item unread\" (label :text \"${app}  ${title}\" :class \"notif-title\") (label :text \"${body}\" :class \"notif-body\") (label :text \"${ts}\" :class \"notif-time\"))"
done | tr '\n' ' '
