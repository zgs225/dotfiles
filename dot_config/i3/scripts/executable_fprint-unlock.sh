#!/usr/bin/env bash
# Parallel fingerprint listener for i3lock. Runs fprintd-verify and kills the
# given i3lock PID on match (killing i3lock unlocks the session). Exits when
# the PID disappears (password unlock). Self-gates on the fingerprint tier so
# lock.sh can spawn it unconditionally, keeping the D-Bus tier probe off the
# lock critical path.
#
# Design notes (from a production incident on the FocalTech fw9366):
# - ONE long-lived fprintd-verify per attempt, never killed on a timer. The
#   old `timeout 15 fprintd-verify` polling re-initialized the sensor every
#   15s (USB reset + full calibration imaging); a few minutes of that tripped
#   the sensor's thermal protection ("Device disabled to prevent
#   overheating"), and fprintd leaked the device claim while mishandling that
#   error (g_task assertion) -> every later Claim got AlreadyInUse and
#   fingerprint unlock stayed dead until fprintd was restarted.
# - Distinguish failure modes instead of blind retry: a real no-match means
#   the verify ran (>=2s) and is cheap to retry; an INSTANT failure is an
#   error path, so back off exponentially (never hammer D-Bus, and let the
#   sensor cool if it is hot).
# - On AlreadyInUse the claim is wedged inside fprintd and cannot self-heal:
#   restart fprintd once per lock session when passwordless sudo exists.
set -u

pid="${1:?usage: fprint-unlock.sh <i3lock-pid>}"

# Single instance per user: two listeners would fight over the device claim.
# -w waits out a lingering previous instance (its in-flight verify may still
# be draining, see the TERM trap below).
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/fprint-unlock.$UID.lock"
flock -w 20 9 || exit 0

fprint_tier() {
    [[ -e "$HOME/.config/i3/fprint.disable" ]] && { echo 0; return; }
    command -v fprintd-list >/dev/null 2>&1 || { echo 0; return; }
    local out
    out=$(timeout 5 fprintd-list "$USER" 2>/dev/null) || { echo 0; return; }
    grep -q '^ - #' <<<"$out" && { echo 2; return; }
    grep -q 'no fingers enrolled' <<<"$out" && { echo 1; return; }
    echo 0
}

[[ "$(fprint_tier)" == "2" ]] || exit 0

OUT="${XDG_RUNTIME_DIR:-/tmp}/fprint-unlock.$UID.out"
child=""

# On TERM (password-unlock cleanup) stop the in-flight fprintd-verify and
# WAIT for it, so the fprintd device claim is released before we exit; a
# lingering verify would fight the next lock session's claim.
on_term() {
    if [[ -n "$child" ]]; then
        kill "$child" 2>/dev/null
        wait "$child" 2>/dev/null
    fi
    exit 0
}
trap on_term TERM INT

notify_once() {
    [[ -n "${notified:-}" ]] && return
    notified=1
    dunstify --urgency=normal "指纹服务异常" "$1" 2>/dev/null || true
}

backoff=1
restarted=0

while kill -0 "$pid" 2>/dev/null; do
    start=$SECONDS
    fprintd-verify >"$OUT" 2>&1 &
    child=$!
    wait "$child"
    rc=$?
    child=""
    duration=$((SECONDS - start))

    if (( rc == 0 )); then
        kill "$pid" 2>/dev/null
        exit 0
    fi

    if (( duration >= 2 )); then
        # Real no-match: finger was presented and rejected. Cheap, retry soon.
        backoff=1
        sleep 0.3
        continue
    fi

    # Instant failure: error path, not a rejected finger.
    if grep -q "AlreadyInUse" "$OUT" 2>/dev/null; then
        # Claim wedged inside fprintd; it cannot release itself. Recover once
        # per lock session if passwordless sudo is available.
        if (( restarted == 0 )); then
            restarted=1
            if sudo -n systemctl restart fprintd 2>/dev/null; then
                notify_once "检测到指纹服务卡死，已自动重启恢复"
                backoff=1
                sleep 2
                continue
            fi
            notify_once "指纹解锁暂不可用，请用密码解锁后执行: sudo systemctl restart fprintd"
        fi
    fi

    (( backoff > 30 )) && backoff=30
    sleep "$backoff"
    (( backoff *= 2 ))
done
