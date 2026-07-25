# Calendar Events — Implementation Plan (Plan B: SQLite + ewwstate)

> Status: ACTIVE
> Created: 2025-07-19
> Philosophy: self-contained in ewwstate, zero new system deps, local-first

## Architecture Overview

```
~/.local/share/eww-calendar/events.db     SQLite (user data, NOT chezmoi-managed)
  accounts (id, name, color, is_local)
  events   (id, account_id, title, date, time_start, time_end,
            rrule, remind_minutes, notes, created_at)

ewwstate/
  caldb.py                  DB access layer (pure Python sqlite3)
  rrule.py                  Simplified RRULE expansion (pure Python)
  collectors/calendar.py    Replaces collectors/events.py
                            PollCollector "events"  (60s) — selected-date events → yuck-literal
                            EventCollector "calendar_notify" — 30s scan → dunstify

scripts/
  executable_calendar-ctl   CLI: init/add/list/delete/account-add/account-list
  executable_calendar-add.sh  rofi multi-step form (eww onclick entry point)

components/
  calendar-popup.yuck.tmpl  Redesigned: date nav + per-date events + add button

common.yuck                 defpoll events → unchanged topic name, same interface
```

## Recurrence Subset (pure Python, no dateutil)

Supported RRULE fields:
- FREQ: DAILY | WEEKLY | MONTHLY | YEARLY
- INTERVAL: positive int (default 1)
- COUNT: max occurrences
- UNTIL: YYYYMMDD or YYYYMMDDTHHMMSS
- BYDAY: comma-separated MO,TU,WE,TH,FR,SA,SU (WEEKLY only)

Storage format: `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR` (RFC 5545 subset syntax)
Empty string = no recurrence (single event).

## Milestones

### M1: Data Layer — caldb.py + rrule.py + calendar-ctl
  Files: ewwstate/caldb.py, ewwstate/rrule.py, scripts/executable_calendar-ctl
  Gate: calendar-ctl init/add/list/delete/account-add all work via CLI;
        rrule expansion verified with 6 test cases (daily/weekly/monthly/yearly/count/until)

### M2: Collector — collectors/calendar.py
  Files: ewwstate/collectors/calendar.py (replaces events.py)
  Gate: offline collect() produces valid yuck-literal;
        output format backward-compatible with existing calendar-popup;
        events topic shows selected-date events (default: today)

### M3: Notification — EventCollector in calendar.py
  Files: same calendar.py
  Gate: test event 2min in future → dunstify fires within 30s;
        no duplicate notifications; respects DND (dunstctl is-paused)

### M4: Calendar Popup UI Redesign
  Files: calendar-popup.yuck.tmpl, calendar-popup.scss.tmpl, common.yuck
  Gate: date navigation (prev/today/next) works;
        events list updates per selected date;
        add-event button visible; account color dots render;
        visual screenshot verified

### M5: Rofi Add-Event Flow
  Files: scripts/executable_calendar-add.sh
  Gate: end-to-end: click add → rofi account → rofi title → rofi time →
        rofi recurrence → event appears in popup for correct date;
        detach guard works (eww onclick doesn't kill the script)

### M6: Integration & Cleanup
  Files: remove events.json, update common.yuck comments, chezmoi apply
  Gate: full daemon restart → all topics healthy → popup visual OK;
        old events.json no longer referenced anywhere

## Execution Rules

1. ONE milestone at a time. Gate must pass before next milestone starts.
2. Every milestone: write → offline test → apply → reload → verify.
3. Follow ewwstate-collector-dev skill: 7-step verification for collectors.
4. Follow developing-eww-components skill: chezmoi apply → i3-msg exec launch.sh.
5. SCSS pure ASCII only. PUA icons via chr() in Python.
6. Design follows song-liquid-glass.md: color tokens from data.colors,
   cinnabar-uniqueness, glass-cell(0.30) for event rows, accent for interactive.
