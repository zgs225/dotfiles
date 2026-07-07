#!/usr/bin/env bash
# Unread/notification badge count — dunst notification history length.
dunstctl count history 2>/dev/null || echo 0
