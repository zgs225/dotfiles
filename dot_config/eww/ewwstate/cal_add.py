#!/usr/bin/env python3
"""cal_add.py — State machine for the eww-native calendar add-event form.

Called by executable_cal-add-action.sh with:
    cal_add.py <action> [args...]

Actions:
    init [pos_x pos_y]   Reset state, open calendar-add-popup
    account NAME         Select account
    title-paste          Read clipboard → title
    title-tpl TEXT       Set title from template
    date-prev / date-next / date-today
    start-inc / start-dec / start-allday
    end-inc / end-dec / end-clear
    rrule FREQ           none / DAILY / WEEKLY / MONTHLY / YEARLY
    weekday DAY          Toggle MO/TU/WE/TH/FR/SA/SU
    remind MIN           0 / 5 / 10 / 30 / 60 / 1440
    submit               Execute calendar-ctl add, close popup
    cancel               Close popup, reopen calendar-popup
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import date, timedelta

# Ensure sibling modules are importable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import caldb
from rrule import describe as rrule_describe

_STATE_FILE = "/tmp/eww-cal-add.json"
_WEEKDAY_CN = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
_WEEKDAY_CODES = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]


# ── Helpers ──────────────────────────────────────────────────────────────

def _eww(*args: str) -> None:
    subprocess.run(["eww", *args], timeout=5, capture_output=True)


def _eww_update(**kwargs: str) -> None:
    """Batch eww update var=val ..."""
    if not kwargs:
        return
    pairs = [f"{k}={v}" for k, v in kwargs.items()]
    _eww("update", *pairs)


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _read_state() -> dict:
    try:
        with open(_STATE_FILE) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return _default_state()


def _write_state(st: dict) -> None:
    with open(_STATE_FILE, "w") as f:
        json.dump(st, f, ensure_ascii=False)


def _default_state() -> dict:
    return {
        "account": "",
        "title": "",
        "date": date.today().isoformat(),
        "start_h": 10, "start_m": 0,
        "end_h": 11, "end_m": 0,
        "all_day": False,
        "has_end": True,
        "rrule_freq": "",
        "byday": [],
        "remind": 10,
        "cal_popup_pos": {"x": 0, "y": 0},
    }


def _time_str(h: int, m: int) -> str:
    return f"{h:02d}:{m:02d}"


def _add_30min(h: int, m: int) -> tuple[int, int]:
    total = h * 60 + m + 30
    total %= 1440
    return total // 60, total % 60


def _sub_30min(h: int, m: int) -> tuple[int, int]:
    total = h * 60 + m - 30
    if total < 0:
        total += 1440
    return total // 60, total % 60


def _date_label(d: date) -> str:
    today = date.today()
    wd = _WEEKDAY_CN[d.weekday()]
    if d == today:
        return f"今天 · {d.month}月{d.day}日 {wd}"
    if d == today + timedelta(days=1):
        return f"明天 · {d.month}月{d.day}日 {wd}"
    if d == today - timedelta(days=1):
        return f"昨天 · {d.month}月{d.day}日 {wd}"
    return f"{d.month}月{d.day}日 {wd}"


def _build_rrule(st: dict) -> str:
    freq = st.get("rrule_freq", "")
    if not freq:
        return ""
    parts = [f"FREQ={freq}"]
    if freq == "WEEKLY" and st.get("byday"):
        parts.append(f"BYDAY={','.join(st['byday'])}")
    return ";".join(parts)


# ── Yuck-literal generators ─────────────────────────────────────────────

def _build_accounts_yuck(selected: str) -> str:
    caldb.ensure_db()
    accounts = caldb.account_list()
    if not accounts:
        return '(box (label :text "--" :class "ca-chip-label"))'
    chips = []
    for a in accounts:
        name = _esc(a["name"])
        color = a["color"]
        active = " ca-acct-on" if a["name"] == selected else ""
        chips.append(
            f'(button :class "ca-acct-chip{active}" '
            f':onclick "~/.config/eww/scripts/cal-add-action.sh account {name}" '
            f'(box :orientation "h" :spacing 5 :valign "center" :space-evenly false '
            f'(box :class "ca-acct-dot ca-acct-dot-{color}") '
            f'(label :text "{name}" :class "ca-acct-label")))'
        )
    return '(box :orientation "h" :spacing 6 :space-evenly false ' + "".join(chips) + ")"


def _build_weekdays_yuck(byday: list[str]) -> str:
    chips = []
    for code, cn in zip(_WEEKDAY_CODES, _WEEKDAY_CN):
        active = " ca-wd-on" if code in byday else ""
        chips.append(
            f'(button :class "ca-wd-chip{active}" '
            f':onclick "~/.config/eww/scripts/cal-add-action.sh weekday {code}" '
            f'(label :text "{cn}" :class "ca-wd-label"))'
        )
    return '(box :orientation "h" :spacing 5 :space-evenly false ' + "".join(chips) + ")"


# ── Publish all display variables ────────────────────────────────────────

def _publish(st: dict) -> None:
    d = date.fromisoformat(st["date"])
    start_disp = "全天" if st["all_day"] else _time_str(st["start_h"], st["start_m"])
    end_disp = _time_str(st["end_h"], st["end_m"]) if st.get("has_end", True) else "--"
    rrule = _build_rrule(st)
    byday_str = ",".join(st.get("byday", []))

    _eww_update(
        cal_add_account=st.get("account", ""),
        cal_add_accounts_yuck=_build_accounts_yuck(st.get("account", "")),
        cal_add_title=_esc(st.get("title", "")),
        cal_add_date=st["date"],
        cal_add_date_label=_date_label(d),
        cal_add_start=start_disp,
        cal_add_end=end_disp,
        cal_add_all_day="true" if st["all_day"] else "false",
        cal_add_rrule_freq=st.get("rrule_freq", ""),
        cal_add_rrule=rrule,
        cal_add_byday=byday_str,
        cal_add_weekdays_yuck=_build_weekdays_yuck(st.get("byday", [])),
        cal_add_weekdays_vis="true" if st.get("rrule_freq") == "WEEKLY" else "false",
        cal_add_remind=str(st.get("remind", 10)),
    )


# ── Actions ──────────────────────────────────────────────────────────────

def _get_cal_popup_pos() -> dict:
    """Get calendar-popup window position via xdotool before closing it."""
    try:
        r = subprocess.run(["xdotool", "search", "--name", "Eww - calendar-popup"],
                           capture_output=True, text=True, timeout=2)
        wid = r.stdout.strip().split("\n")[0]
        if not wid:
            return {"x": 0, "y": 0}
        r2 = subprocess.run(["xdotool", "getwindowgeometry", "--shell", wid],
                            capture_output=True, text=True, timeout=2)
        pos: dict = {}
        for line in r2.stdout.splitlines():
            if line.startswith("X="):
                pos["x"] = int(line.split("=")[1])
            elif line.startswith("Y="):
                pos["y"] = int(line.split("=")[1])
        return pos if pos else {"x": 0, "y": 0}
    except Exception:
        return {"x": 0, "y": 0}


def action_init(args: list[str]) -> None:
    caldb.ensure_db()
    st = _default_state()

    # Default account = first in list
    accounts = caldb.account_list()
    if accounts:
        st["account"] = accounts[0]["name"]

    # Capture calendar-popup position BEFORE closing it
    st["cal_popup_pos"] = _get_cal_popup_pos()

    _write_state(st)
    _publish(st)

    # Close calendar-popup, open calendar-add-popup
    _eww("close", "calendar-popup")
    import time; time.sleep(0.15)
    _eww("open", "calendar-add-popup")
    _eww("update", "popup_open=calendar-add-popup")


def action_account(args: list[str]) -> None:
    if not args:
        return
    st = _read_state()
    st["account"] = args[0]
    _write_state(st)
    _publish(st)


def action_title_set(args: list[str]) -> None:
    """Called by input widget :onchange — saves typed text to state file."""
    st = _read_state()
    st["title"] = " ".join(args)[:80]
    _write_state(st)
    # Do NOT update eww variable — input widget manages its own display.
    # The eww variable is only updated by template/paste actions.


def action_title_paste(args: list[str]) -> None:
    st = _read_state()
    # Read clipboard via xclip or xsel
    text = ""
    for cmd in (["xclip", "-selection", "clipboard", "-o"],
                ["xsel", "--clipboard", "--output"]):
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=2)
            if r.returncode == 0 and r.stdout.strip():
                text = r.stdout.strip()
                break
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    if text:
        st["title"] = text[:60]  # cap length
    _write_state(st)
    _publish(st)


def action_title_tpl(args: list[str]) -> None:
    if not args:
        return
    st = _read_state()
    st["title"] = args[0]
    _write_state(st)
    _publish(st)


def action_date_prev(args: list[str]) -> None:
    st = _read_state()
    d = date.fromisoformat(st["date"]) - timedelta(days=1)
    st["date"] = d.isoformat()
    _write_state(st)
    _publish(st)


def action_date_next(args: list[str]) -> None:
    st = _read_state()
    d = date.fromisoformat(st["date"]) + timedelta(days=1)
    st["date"] = d.isoformat()
    _write_state(st)
    _publish(st)


def action_date_today(args: list[str]) -> None:
    st = _read_state()
    st["date"] = date.today().isoformat()
    _write_state(st)
    _publish(st)


def action_start_inc(args: list[str]) -> None:
    st = _read_state()
    if st["all_day"]:
        return
    st["start_h"], st["start_m"] = _add_30min(st["start_h"], st["start_m"])
    _write_state(st)
    _publish(st)


def action_start_dec(args: list[str]) -> None:
    st = _read_state()
    if st["all_day"]:
        return
    st["start_h"], st["start_m"] = _sub_30min(st["start_h"], st["start_m"])
    _write_state(st)
    _publish(st)


def action_start_allday(args: list[str]) -> None:
    st = _read_state()
    st["all_day"] = not st["all_day"]
    _write_state(st)
    _publish(st)


def action_end_inc(args: list[str]) -> None:
    st = _read_state()
    st["end_h"], st["end_m"] = _add_30min(st["end_h"], st["end_m"])
    st["has_end"] = True
    _write_state(st)
    _publish(st)


def action_end_dec(args: list[str]) -> None:
    st = _read_state()
    st["end_h"], st["end_m"] = _sub_30min(st["end_h"], st["end_m"])
    st["has_end"] = True
    _write_state(st)
    _publish(st)


def action_end_clear(args: list[str]) -> None:
    st = _read_state()
    st["has_end"] = False
    _write_state(st)
    _publish(st)


def action_rrule(args: list[str]) -> None:
    if not args:
        return
    st = _read_state()
    freq = args[0]
    if freq == "none":
        st["rrule_freq"] = ""
        st["byday"] = []
    else:
        st["rrule_freq"] = freq
        # Default BYDAY for weekly = same weekday as selected date
        if freq == "WEEKLY" and not st["byday"]:
            d = date.fromisoformat(st["date"])
            st["byday"] = [_WEEKDAY_CODES[d.weekday()]]
    _write_state(st)
    _publish(st)


def action_weekday(args: list[str]) -> None:
    if not args:
        return
    st = _read_state()
    code = args[0].upper()
    if code in st["byday"]:
        st["byday"].remove(code)
    else:
        st["byday"].append(code)
    st["byday"].sort(key=lambda c: _WEEKDAY_CODES.index(c))
    _write_state(st)
    _publish(st)


def action_remind(args: list[str]) -> None:
    if not args:
        return
    st = _read_state()
    st["remind"] = int(args[0])
    _write_state(st)
    _publish(st)


def action_submit(args: list[str]) -> None:
    st = _read_state()
    title = st.get("title", "").strip()
    if not title:
        subprocess.run(["dunstify", "-a", "eww-calendar", "-u", "critical",
                        "-t", "3000", "标题为空", "请输入事件标题"],
                       timeout=3, capture_output=True)
        return

    # Build calendar-ctl args
    ctl_args = [
        os.path.expanduser("~/.config/eww/scripts/calendar-ctl"),
        "add",
        "--date", st["date"],
        "--title", title,
    ]
    if st.get("account"):
        ctl_args += ["--account", st["account"]]
    if not st["all_day"]:
        ctl_args += ["--start", _time_str(st["start_h"], st["start_m"])]
        if st.get("has_end", True):
            ctl_args += ["--end", _time_str(st["end_h"], st["end_m"])]
    rrule = _build_rrule(st)
    if rrule:
        ctl_args += ["--rrule", rrule]
    ctl_args += ["--remind", str(st.get("remind", 10))]

    try:
        r = subprocess.run(ctl_args, capture_output=True, text=True, timeout=10)
        ok = r.returncode == 0
    except Exception:
        ok = False

    if ok:
        subprocess.run(["dunstify", "-a", "eww-calendar", "-u", "normal",
                        "-t", "3000", "已添加", f"{title} ({st['date']})"],
                       timeout=3, capture_output=True)
        # Immediately refresh events display so the calendar popup
        # shows the new event without waiting for the 60s poll.
        _refresh_events()
    else:
        subprocess.run(["dunstify", "-a", "eww-calendar", "-u", "critical",
                        "-t", "5000", "添加失败", "请检查 calendar-ctl"],
                       timeout=3, capture_output=True)

    _close_and_restore(st)


def action_cancel(args: list[str]) -> None:
    st = _read_state()
    _close_and_restore(st)


def _close_and_restore(st: dict) -> None:
    """Close calendar-add-popup and reopen calendar-popup."""
    _eww("close", "calendar-add-popup")
    import time; time.sleep(0.15)

    pos = st.get("cal_popup_pos", {})
    px = pos.get("x", 0)
    py = pos.get("y", 0)
    if px and py:
        _eww("open", "calendar-popup",
              "--arg", f"pos_x={px}px", "--arg", f"pos_y={py}px")
    else:
        _eww("open", "calendar-popup",
              "--arg", "pos_x=1400px", "--arg", "pos_y=50px")
    _eww("update", "popup_open=calendar-popup")


def action_delete(args: list[str]) -> None:
    """Delete an event by ID from the calendar popup's event list."""
    if not args:
        return
    try:
        eid = int(args[0])
    except ValueError:
        return
    caldb.ensure_db()
    ok = caldb.event_delete(eid)
    if ok:
        subprocess.run(["dunstify", "-a", "eww-calendar", "-u", "normal",
                        "-t", "2000", "已删除", f"事件 #{eid}"],
                       timeout=3, capture_output=True)
    # Immediate refresh of the events display
    _refresh_events()


def _refresh_events() -> None:
    """Re-publish events yuck-literal for the current selected date."""
    raw = subprocess.run(["eww", "get", "cal_selected_date"],
                         capture_output=True, text=True, timeout=3).stdout.strip()
    today = date.today()
    if raw:
        try:
            target = date.fromisoformat(raw)
        except ValueError:
            target = today
    else:
        target = today
    caldb.ensure_db()
    items = caldb.events_for_date(target)
    from collectors.calendar import _build_yuck, _date_label
    yuck = _build_yuck(items)
    label = _date_label(target)
    has = "true" if items else "false"
    _eww_update(events=yuck, cal_date_label=label, cal_has_events=has)


# ── Dispatch ─────────────────────────────────────────────────────────────

_ACTIONS = {
    "init": action_init,
    "account": action_account,
    "title-set": action_title_set,
    "title-paste": action_title_paste,
    "title-tpl": action_title_tpl,
    "date-prev": action_date_prev,
    "date-next": action_date_next,
    "date-today": action_date_today,
    "start-inc": action_start_inc,
    "start-dec": action_start_dec,
    "start-allday": action_start_allday,
    "end-inc": action_end_inc,
    "end-dec": action_end_dec,
    "end-clear": action_end_clear,
    "rrule": action_rrule,
    "weekday": action_weekday,
    "remind": action_remind,
    "submit": action_submit,
    "cancel": action_cancel,
    "delete": action_delete,
}


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: cal_add.py <action> [args...]", file=sys.stderr)
        return 2
    action = sys.argv[1]
    args = sys.argv[2:]
    fn = _ACTIONS.get(action)
    if fn is None:
        print(f"Unknown action: {action}", file=sys.stderr)
        return 2
    try:
        fn(args)
    except Exception as e:
        print(f"cal_add.py {action}: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
