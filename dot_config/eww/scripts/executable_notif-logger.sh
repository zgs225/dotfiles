#!/usr/bin/env bash
# Daemon started by launch script — monitors D-Bus for dunst notifications
# Appends to /tmp/eww_notifications.json, keeps last 50 entries

LOG_FILE="/tmp/eww_notifications.json"
echo "[]" > "$LOG_FILE"

capture_state=""
app=""; sum=""; body=""

dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null \
| while IFS= read -r line; do
    if echo "$line" | grep -q '^method call'; then
        capture_state="app"; app=""; sum=""; body=""
    fi
    if echo "$line" | grep -q '^\s*string'; then
        value=$(echo "$line" | sed 's/^\s*string "//;s/"$//')
        case "$capture_state" in
            app)     app="$value";   capture_state="summary" ;;
            summary) sum="$value";   capture_state="body" ;;
            body)    body="$value";  capture_state="done" ;;
            *)       capture_state="" ;;
        esac
    fi
    if [ "$capture_state" = "done" ]; then
        timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        jq --arg app "$app" --arg t "$sum" --arg b "$body" --arg ts "$timestamp" \
          "[{app: \$app, title: \$t, body: \$b, timestamp: \$ts}] + . | .[:50]" \
          "$LOG_FILE" > /tmp/eww_notifs.new 2>/dev/null && mv /tmp/eww_notifs.new "$LOG_FILE"
        capture_state=""
    fi
done
