"""Calendar database access layer — pure Python sqlite3.

DB location: ``~/.local/share/eww-calendar/events.db`` (user data, NOT
managed by chezmoi).  Created on first ``calendar-ctl init`` or lazily
by the collector via ``ensure_db()``.

Schema:
    accounts (id, name, color, is_local)
    events   (id, account_id, title, date, time_start, time_end,
              rrule, remind_minutes, notes, created_at)
"""
from __future__ import annotations

import os
import sqlite3
from datetime import date

_DB_DIR = os.path.expanduser("~/.local/share/eww-calendar")
_DB_PATH = os.path.join(_DB_DIR, "events.db")

_SCHEMA = """
CREATE TABLE IF NOT EXISTS accounts (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    name     TEXT    NOT NULL UNIQUE,
    color    TEXT    NOT NULL DEFAULT 'blue',
    is_local INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS events (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id    INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    title         TEXT    NOT NULL,
    date          TEXT    NOT NULL,              -- YYYY-MM-DD anchor
    time_start    TEXT    NOT NULL DEFAULT '',   -- HH:MM
    time_end      TEXT    NOT NULL DEFAULT '',   -- HH:MM
    rrule         TEXT    NOT NULL DEFAULT '',   -- RFC 5545 subset
    remind_minutes INTEGER NOT NULL DEFAULT 10,
    notes         TEXT    NOT NULL DEFAULT '',
    created_at    TEXT    NOT NULL DEFAULT (datetime('now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_events_date ON events(date);
"""

# Valid dot-color CSS classes (must match calendar-popup.scss)
VALID_COLORS = ("blue", "mauve", "green", "peach", "teal", "yellow")


def db_path() -> str:
    return _DB_PATH


def connect() -> sqlite3.Connection:
    """Open (or create) the database and return a connection."""
    os.makedirs(_DB_DIR, exist_ok=True)
    conn = sqlite3.connect(_DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def ensure_db() -> None:
    """Create schema + default local account if the DB doesn't exist yet."""
    conn = connect()
    try:
        conn.executescript(_SCHEMA)
        # Default local account (idempotent)
        cur = conn.execute("SELECT id FROM accounts WHERE is_local = 1 LIMIT 1")
        if cur.fetchone() is None:
            conn.execute(
                "INSERT INTO accounts (name, color, is_local) VALUES (?, ?, 1)",
                ("本地", "blue"),
            )
        conn.commit()
    finally:
        conn.close()


# ── Accounts ─────────────────────────────────────────────────────────────

def account_list() -> list[dict]:
    conn = connect()
    try:
        rows = conn.execute(
            "SELECT id, name, color, is_local FROM accounts ORDER BY is_local DESC, id"
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def account_add(name: str, color: str = "blue") -> int:
    if color not in VALID_COLORS:
        color = "blue"
    conn = connect()
    try:
        cur = conn.execute(
            "INSERT INTO accounts (name, color, is_local) VALUES (?, ?, 0)",
            (name, color),
        )
        conn.commit()
        return cur.lastrowid  # type: ignore[return-value]
    finally:
        conn.close()


def account_id_by_name(name: str) -> int | None:
    conn = connect()
    try:
        row = conn.execute(
            "SELECT id FROM accounts WHERE name = ?", (name,)
        ).fetchone()
        return row["id"] if row else None
    finally:
        conn.close()


def default_account_id() -> int:
    """Return the local account's id, creating it if needed."""
    ensure_db()
    conn = connect()
    try:
        row = conn.execute(
            "SELECT id FROM accounts WHERE is_local = 1 LIMIT 1"
        ).fetchone()
        if row:
            return row["id"]
        # Shouldn't happen after ensure_db, but be safe
        cur = conn.execute(
            "INSERT INTO accounts (name, color, is_local) VALUES (?, ?, 1)",
            ("本地", "blue"),
        )
        conn.commit()
        return cur.lastrowid  # type: ignore[return-value]
    finally:
        conn.close()


# ── Events ───────────────────────────────────────────────────────────────

def event_add(
    title: str,
    event_date: str,
    time_start: str = "",
    time_end: str = "",
    account_id: int | None = None,
    rrule: str = "",
    remind_minutes: int = 10,
    notes: str = "",
) -> int:
    if account_id is None:
        account_id = default_account_id()
    conn = connect()
    try:
        cur = conn.execute(
            """INSERT INTO events
               (account_id, title, date, time_start, time_end, rrule, remind_minutes, notes)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (account_id, title, event_date, time_start, time_end,
             rrule, remind_minutes, notes),
        )
        conn.commit()
        return cur.lastrowid  # type: ignore[return-value]
    finally:
        conn.close()


def event_delete(event_id: int) -> bool:
    conn = connect()
    try:
        cur = conn.execute("DELETE FROM events WHERE id = ?", (event_id,))
        conn.commit()
        return cur.rowcount > 0
    finally:
        conn.close()


def events_for_date(target: date) -> list[dict]:
    """Return all events that occur on *target*, expanding recurrences.

    Each returned dict has: id, account_id, account_name, account_color,
    title, date (original anchor), time_start, time_end, rrule,
    remind_minutes, notes, is_recurring (bool).
    """
    from rrule import expand

    conn = connect()
    try:
        rows = conn.execute(
            """SELECT e.id, e.account_id, a.name AS account_name,
                      a.color AS account_color, e.title, e.date,
                      e.time_start, e.time_end, e.rrule,
                      e.remind_minutes, e.notes
               FROM events e
               JOIN accounts a ON a.id = e.account_id
               ORDER BY e.time_start, e.id"""
        ).fetchall()
    finally:
        conn.close()

    results: list[dict] = []
    for row in rows:
        r = dict(row)
        anchor = _parse_date(r["date"])
        if anchor is None:
            continue
        occurrences = expand(anchor, r["rrule"], target, target)
        if occurrences:
            r["is_recurring"] = bool(r["rrule"])
            results.append(r)

    # Sort by start time (empty times sort last)
    results.sort(key=lambda e: (e["time_start"] or "99:99", e["id"]))
    return results


def events_for_range(start: date, end: date) -> list[dict]:
    """Return all events occurring in [start, end], expanding recurrences."""
    from rrule import expand

    conn = connect()
    try:
        rows = conn.execute(
            """SELECT e.id, e.account_id, a.name AS account_name,
                      a.color AS account_color, e.title, e.date,
                      e.time_start, e.time_end, e.rrule,
                      e.remind_minutes, e.notes
               FROM events e
               JOIN accounts a ON a.id = e.account_id
               ORDER BY e.date, e.time_start, e.id"""
        ).fetchall()
    finally:
        conn.close()

    results: list[dict] = []
    for row in rows:
        r = dict(row)
        anchor = _parse_date(r["date"])
        if anchor is None:
            continue
        occurrences = expand(anchor, r["rrule"], start, end)
        if occurrences:
            r["is_recurring"] = bool(r["rrule"])
            r["occurrences"] = [o.isoformat() for o in occurrences]
            results.append(r)
    return results


def upcoming_events(minutes_ahead: int = 30) -> list[dict]:
    """Events starting within the next *minutes_ahead* minutes (for notifications).

    Only returns events whose remind_minutes window covers 'now'.
    """
    from datetime import datetime, timedelta
    from rrule import expand

    now = datetime.now()
    today = now.date()
    now_hm = now.strftime("%H:%M")

    conn = connect()
    try:
        rows = conn.execute(
            """SELECT e.id, e.account_id, a.name AS account_name,
                      a.color AS account_color, e.title, e.date,
                      e.time_start, e.time_end, e.rrule,
                      e.remind_minutes, e.notes
               FROM events e
               JOIN accounts a ON a.id = e.account_id
               WHERE e.time_start != ''
               ORDER BY e.time_start"""
        ).fetchall()
    finally:
        conn.close()

    results: list[dict] = []
    for row in rows:
        r = dict(row)
        anchor = _parse_date(r["date"])
        if anchor is None:
            continue
        # Check if event occurs today
        occurrences = expand(anchor, r["rrule"], today, today)
        if not occurrences:
            continue

        ts = r["time_start"]
        try:
            event_dt = datetime(today.year, today.month, today.day,
                                int(ts.split(":")[0]), int(ts.split(":")[1]))
        except (ValueError, IndexError):
            continue

        remind = r.get("remind_minutes", 10) or 10
        remind_at = event_dt - timedelta(minutes=remind)
        # Fire if we're in the window [remind_at, event_dt]
        if remind_at <= now <= event_dt:
            r["event_datetime"] = event_dt.isoformat()
            r["minutes_until"] = max(0, int((event_dt - now).total_seconds() // 60))
            results.append(r)

    return results


def _parse_date(s: str) -> date | None:
    try:
        parts = s.split("-")
        return date(int(parts[0]), int(parts[1]), int(parts[2]))
    except (ValueError, IndexError):
        return None
