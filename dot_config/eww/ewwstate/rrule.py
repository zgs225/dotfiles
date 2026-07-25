"""Simplified RRULE expansion — pure Python, zero dependencies.

Supports the RFC 5545 subset that covers real-world calendar use:

    FREQ   = DAILY | WEEKLY | MONTHLY | YEARLY
    INTERVAL = positive int (default 1)
    COUNT  = max total occurrences (including the anchor)
    UNTIL  = YYYYMMDD or YYYYMMDDTHHMMSS (inclusive)
    BYDAY  = MO,TU,WE,TH,FR,SA,SU  (WEEKLY only)

Storage format mirrors RFC 5545: ``FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR``
Empty string = no recurrence (single occurrence on the anchor date).
"""
from __future__ import annotations

from datetime import date, timedelta

_DAY_MAP = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}


def parse_rrule(rrule: str) -> dict:
    """Parse an RRULE string into a dict of components."""
    if not rrule or not rrule.strip():
        return {}
    parts: dict = {}
    for token in rrule.strip().split(";"):
        token = token.strip()
        if "=" not in token:
            continue
        key, val = token.split("=", 1)
        key = key.strip().upper()
        val = val.strip()
        if key == "FREQ":
            parts["freq"] = val.upper()
        elif key == "INTERVAL":
            try:
                parts["interval"] = max(1, int(val))
            except ValueError:
                parts["interval"] = 1
        elif key == "COUNT":
            try:
                parts["count"] = max(1, int(val))
            except ValueError:
                pass
        elif key == "UNTIL":
            # YYYYMMDD or YYYYMMDDTHHMMSS — we only need the date part
            try:
                parts["until"] = _parse_until(val)
            except ValueError:
                pass
        elif key == "BYDAY":
            days = []
            for d in val.split(","):
                d = d.strip().upper()
                if d in _DAY_MAP:
                    days.append(_DAY_MAP[d])
            if days:
                parts["byday"] = sorted(days)
    return parts


def _parse_until(val: str) -> date:
    val = val.replace("-", "")
    if "T" in val:
        val = val.split("T")[0]
    return date(int(val[:4]), int(val[4:6]), int(val[6:8]))


def expand(anchor: date, rrule: str, range_start: date, range_end: date) -> list[date]:
    """Return all occurrence dates of *anchor* + *rrule* within [range_start, range_end].

    The anchor date itself is always the first occurrence.  If rrule is empty,
    returns [anchor] when it falls in range, else [].

    A safety cap of 3660 iterations prevents infinite loops from malformed rules.
    """
    if range_end < range_start:
        return []

    parts = parse_rrule(rrule)
    if not parts or "freq" not in parts:
        # No recurrence — single occurrence
        if range_start <= anchor <= range_end:
            return [anchor]
        return []

    freq = parts["freq"]
    interval = parts.get("interval", 1)
    count = parts.get("count")
    until = parts.get("until")
    byday = parts.get("byday")  # only for WEEKLY

    results: list[date] = []
    occurrences = 0
    current = anchor
    iterations = 0
    max_iter = 3660  # ~10 years of daily; safety cap

    if freq == "WEEKLY" and byday:
        # Special handling: iterate week by week, emit matching days
        # Start from the beginning of the anchor's week (Monday)
        week_start = anchor - timedelta(days=anchor.weekday())
        while iterations < max_iter:
            for wd in byday:
                candidate = week_start + timedelta(days=wd)
                if candidate < anchor:
                    continue
                if until and candidate > until:
                    return results
                if count is not None and occurrences >= count:
                    return results
                occurrences += 1
                if candidate > range_end:
                    return results
                if candidate >= range_start:
                    results.append(candidate)
            week_start += timedelta(weeks=interval)
            iterations += 1
            # Early exit if we're past range and past until
            if week_start > range_end and (until is None or week_start > until):
                break
        return results

    # DAILY / WEEKLY (no BYDAY) / MONTHLY / YEARLY
    # For MONTHLY/YEARLY we compute each occurrence from the *anchor*
    # (anchor + N*interval months) to avoid day-clamping drift:
    #   Jan 31 → Feb 28 → Mar 31 (correct), not Jan 31 → Feb 28 → Mar 28.
    step = 0
    while iterations < max_iter:
        if freq in ("MONTHLY", "YEARLY"):
            months = interval * step * (12 if freq == "YEARLY" else 1)
            current = _add_months(anchor, months)
        # For DAILY/WEEKLY, current is advanced incrementally below.

        if until and current > until:
            break
        if count is not None and occurrences >= count:
            break
        if current > range_end:
            break

        occurrences += 1
        if current >= range_start:
            results.append(current)

        # Advance
        if freq == "DAILY":
            current += timedelta(days=interval)
        elif freq == "WEEKLY":
            current += timedelta(weeks=interval)
        # MONTHLY/YEARLY: handled by step counter above

        step += 1
        iterations += 1

    return results


def _add_months(d: date, months: int) -> date:
    """Add months to a date, clamping to the last day of the target month."""
    month = d.month - 1 + months
    year = d.year + month // 12
    month = month % 12 + 1
    # Clamp day to last day of target month
    import calendar as cal_mod
    max_day = cal_mod.monthrange(year, month)[1]
    return date(year, month, min(d.day, max_day))


def describe(rrule: str) -> str:
    """Human-readable Chinese description of an RRULE for display."""
    parts = parse_rrule(rrule)
    if not parts or "freq" not in parts:
        return ""
    freq = parts["freq"]
    interval = parts.get("interval", 1)

    names = {"DAILY": "天", "WEEKLY": "周", "MONTHLY": "月", "YEARLY": "年"}
    unit = names.get(freq, "")
    if not unit:
        return ""

    if interval == 1:
        base = f"每{unit}"
    else:
        base = f"每{interval}{unit}"

    byday = parts.get("byday")
    if byday and freq == "WEEKLY":
        day_names = ["一", "二", "三", "四", "五", "六", "日"]
        days_str = "、".join(f"周{day_names[d]}" for d in byday)
        base += f" ({days_str})"

    count = parts.get("count")
    until = parts.get("until")
    if count:
        base += f"，共{count}次"
    elif until:
        base += f"，至{until.month}月{until.day}日"

    return base
