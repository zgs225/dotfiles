#!/usr/bin/env bash
# cal-nav.sh — Navigate the calendar selected date.
# Usage: cal-nav.sh prev|next|today
#
# Updates cal_selected_date + immediately refreshes events/cal_date_label
# via eww update (optimistic, bypasses the 60s poll).
set -euo pipefail

# Detach guard — eww SIGKILLs onclick commands after 200ms.
if [ -z "${EWW_CALNAV_DETACHED:-}" ]; then
    EWW_CALNAV_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

ACTION="${1:-today}"
EWWSTATE_DIR="$HOME/.config/eww/ewwstate"
export PYTHONDONTWRITEBYTECODE=1

python3 -c "
import sys, subprocess
sys.path.insert(0, '$EWWSTATE_DIR')
from datetime import date, timedelta
import caldb
from collectors.calendar import _build_yuck, _date_label

action = '$ACTION'

# Read current selected date from eww
raw = subprocess.run(['eww', 'get', 'cal_selected_date'],
                     capture_output=True, text=True, timeout=3).stdout.strip()
if not raw:
    current = date.today()
else:
    try:
        current = date.fromisoformat(raw)
    except ValueError:
        current = date.today()

if action == 'prev':
    target = current - timedelta(days=1)
elif action == 'next':
    target = current + timedelta(days=1)
else:  # today
    target = date.today()

# Empty string = today (collector convention)
new_val = '' if target == date.today() else target.isoformat()

# Compute events for the new date
caldb.ensure_db()
items = caldb.events_for_date(target)
label = _date_label(target)
has = 'true' if items else 'false'
yuck = _build_yuck(items)

# Optimistic eww update (instant feedback)
subprocess.run(['eww', 'update', f'cal_selected_date={new_val}'], timeout=5)
subprocess.run(['eww', 'update', f'events={yuck}'], timeout=5)
subprocess.run(['eww', 'update', f'cal_date_label={label}'], timeout=5)
subprocess.run(['eww', 'update', f'cal_has_events={has}'], timeout=5)
" 2>/dev/null
