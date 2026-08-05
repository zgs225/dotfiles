#!/usr/bin/env bash
# screenrecord.sh -- CleanShot-X-style region VIDEO recording
# (gpu-screen-recorder + eww floating control bar).
#
# Usage: screenrecord.sh video     (bound to $mod+Shift+5 in i3 config)
#        screenrecord.sh __ui_start|__ui_stop|__ui_cancel|__ui_audio|__ui_format
#                                 (eww rec-controls buttons only)
#        screenrecord.sh __stop    (internal: manual/external stop)
#
# State machine:
#   idle     --hotkey--> slop region select --> ARMED
#   ARMED    --[record] btn--> RECORDING
#   ARMED    --[cancel] btn / hotkey--> idle
#   RECORDING--[stop] btn / hotkey--> finalize mkv -> remux mp4 -> preview
#                                     (format GIF: mp4 kept, background
#                                      ffmpeg palette convert -> gif preview)
#
#   ARMED:     rec-controls bar [record] [WxH] [MP4/GIF] [audio toggle] [cancel]
#   RECORDING: rec-controls bar [live dot] [elapsed] [stop]
#
# Output format preference (mp4|gif) persists like the audio preference; the
# recording pipeline itself is format-agnostic (always mkv -> mp4 remux, so
# a failed GIF conversion never loses the recording). GIF conversion is a
# two-pass ffmpeg palette encode capped at REC_GIF_FPS, with dunstify -r
# percentage progress while it runs.
#
# No duration cap and no resolution scaling: the mp4 keeps the full selected
# region and runs until the user stops it (mkv intermediate -> lossless
# remux, so finalize is fast even for long recordings).
#
# Gotchas honored (see .agents/skills):
#   - Stop is ALWAYS SIGINT, never kill -9: GSR finalizes the container on
#     SIGINT; a hard kill corrupts the recording.
#   - eww SIGKILLs onclick commands after 200ms: __ui_start/__ui_stop re-exec
#     detached (setsid) before doing any real work. __ui_cancel/__ui_audio
#     stay under 200ms and run synchronously.
#   - All recorder state lives in pidfiles under XDG_RUNTIME_DIR; no pkill -f
#     (self-match trap).
#   - h264 wants even WxH: slop output is normalized down to even numbers.
#   - The control bar must sit OUTSIDE the captured region whenever there is
#     room -- a window overlapping the region would be baked into the video.
#     Fallback chain: below-right -> above-right -> inside-bottom-right
#     (ARMED only; on record-start an inside bar closes and the bar badge
#     carries the timer, stop falls back to the hotkey).
#   - The selection frame is 4 eww strip windows hugging the OUTSIDE of the
#     region (zero overlap with the capture), so it can stay up while
#     recording without contaminating the video.
#   - Optimistic UI: screen_recording=true is pushed right after spawn
#     (<100ms click feedback); the 3s health check rolls it back if GSR dies
#     on init (e.g. all monitors DPMS-off).
#   - GSR can die mid-recording (GPU reset, ...): the 1s elapsed-updater
#     subshell doubles as a death watcher. The pidfile is removed FIRST on a
#     deliberate stop, so a dead recorder with the pidfile still present ==
#     unexpected death -> cleanup + failure notification.
#   - SCREENRECORD_REGION="WxH+X+Y" bypasses slop (used for headless testing).

# Detach guard -- eww SIGKILLs onclick commands after 200ms. Must run before
# anything else; the re-exec below returns to eww instantly.
case "${1:-}" in
    __ui_start|__ui_stop)
        if [ -z "${EWW_SCREENRECORD_DETACHED:-}" ]; then
            EWW_SCREENRECORD_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
            exit 0
        fi
        ;;
esac

set -euo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}"
REC_PID_FILE="$STATE_DIR/screenrecord.gsr.pid"    # gpu-screen-recorder pid
REC_META_FILE="$STATE_DIR/screenrecord.meta"      # lines: tmp=<mkv>  start=<epoch>
REC_ARMED_FILE="$STATE_DIR/screenrecord.armed"    # one line: w h x y px py inside
LOG_FILE="$STATE_DIR/screenrecord.gsr.log"        # gsr stdout/stderr, per run
AUDIO_PREF="${XDG_STATE_HOME:-$HOME/.local/state}/screenrecord/audio"  # off|sys
FORMAT_PREF="${XDG_STATE_HOME:-$HOME/.local/state}/screenrecord/format"  # mp4|gif
REC_FPS="${SCREENRECORD_REC_FPS:-30}"
# GIF frame cap: 30fps full-size GIFs explode in size; 15fps is the default
# tradeoff. No resolution scaling (full selected region is kept).
REC_GIF_FPS="${SCREENRECORD_GIF_FPS:-15}"
REC_QUALITY="${SCREENRECORD_REC_QUALITY:-high}"
REC_AUDIO_DEVICE="${SCREENRECORD_REC_AUDIO_DEVICE:-default_output}"

dir="${SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
mkdir -p "$dir"

# notification app icon: 黛 tile + 藤黄 record dot (song-liquid-glass
# tokens; matches the rec-controls live dot). dunst rounds corners itself.
ICON="$HOME/.config/i3/assets/screenrecord-icon.svg"
[[ -f "$ICON" ]] || ICON=""

notify() { notify-send -u low -t 4000 -a screenrecord ${ICON:+-i "$ICON"} "screenrecord" "$1" 2>/dev/null || true; }
# same replace-id: the "exporting" hint is swapped in-place for the result
notify_r() { dunstify -r 9105 -u low -t "$2" -a screenrecord ${ICON:+-i "$ICON"} "screenrecord" "$1" 2>/dev/null || notify "$1"; }

eww_reset() {
    eww update screen_recording=false screen_rec_elapsed= screen_rec_region= 2>/dev/null || true
    eww close rec-controls 2>/dev/null || true
    close_frame
}

# Selection frame: 4 strips hugging the OUTSIDE of the region (zero overlap
# with the capture -> never baked into the video). Instances of one
# defwindow, addressed by id; `eww close <name>` does NOT reach --id
# instances, so closing must list the ids explicitly.
FRAME_T=2
open_frame() {   # w h x y
    local w=$1 h=$2 x=$3 y=$4 t=$FRAME_T
    eww open rec-frame --id top    --arg "pos_x=$((x-t))px" --arg "pos_y=$((y-t))px" --arg "width=$((w+2*t))px" --arg "height=${t}px" 2>/dev/null || true
    eww open rec-frame --id bottom --arg "pos_x=$((x-t))px" --arg "pos_y=$((y+h))px"  --arg "width=$((w+2*t))px" --arg "height=${t}px" 2>/dev/null || true
    eww open rec-frame --id left   --arg "pos_x=$((x-t))px" --arg "pos_y=${y}px"      --arg "width=${t}px"      --arg "height=${h}px" 2>/dev/null || true
    eww open rec-frame --id right  --arg "pos_x=$((x+w))px"  --arg "pos_y=${y}px"      --arg "width=${t}px"      --arg "height=${h}px" 2>/dev/null || true
}
close_frame() { eww close top bottom left right 2>/dev/null || true; }

is_recording() {
    [[ -f "$REC_PID_FILE" ]] || return 1
    local pid
    pid=$(cat "$REC_PID_FILE" 2>/dev/null) || return 1
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

is_armed() { [[ -f "$REC_ARMED_FILE" ]]; }

# popupFontSize tier, mirroring .chezmoitemplates/eww-sizes (15/20/26) so the
# placement math below uses the same baked window width as the yuck template.
dpi_font_size() {
    local dpi
    dpi=$(xrdb -query 2>/dev/null | awk '/Xft.dpi/ {print $2; exit}' | cut -d. -f1)
    dpi=${dpi:-96}
    if (( dpi >= 192 )); then echo 26; elif (( dpi >= 144 )); then echo 20; else echo 15; fi
}

# compute_placement w h x y -> "px py inside": panel bottom-RIGHT outside
# the frame (right edge aligned with the frame's outer right edge);
# inside=1 means the bar floats over the region bottom-right: only used for
# ARMED when no room exists outside.
compute_placement() {
    local w=$1 h=$2 x=$3 y=$4
    local pfs win_w win_h t=$FRAME_T gap=8
    pfs=$(dpi_font_size)
    # ARMED row: [record] [WxH] [MP4/GIF] [audio] [cancel] -- 26 chars wide
    win_w=$(( pfs * 26 )); win_h=$(( pfs * 3 ))
    local cx=$(( x + w / 2 )) cy=$(( y + h / 2 ))
    local mo
    mo=$(xrandr --listactivemonitors 2>/dev/null | awk -v cx="$cx" -v cy="$cy" '
        /^ +[0-9]+:/ {
            # $3 = "2560/344x1600/215+0+0" -> split on non-digits:
            # g[1]=px_w g[2]=mm_w g[3]=px_h g[4]=mm_h g[5]=off_x g[6]=off_y
            split($3, g, /[^0-9]+/); mw=g[1]; mh=g[3]; ox=g[5]; oy=g[6]
            if (cx >= ox && cx < ox + mw && cy >= oy && cy < oy + mh) {
                print ox, oy, mw, mh; exit
            }
        }')
    local ox=0 oy=0 mw=99999 mh=99999 px py inside=0
    [[ -n "$mo" ]] && read -r ox oy mw mh <<<"$mo"
    px=$(( x + w + t - win_w ))
    if (( y + h + t + gap + win_h <= oy + mh )); then
        py=$(( y + h + t + gap ))              # below the frame, right-aligned
    elif (( y - t - gap - win_h >= oy )); then
        py=$(( y - t - gap - win_h ))          # above the frame, right-aligned
    else
        px=$(( x + w - win_w - 12 ))
        py=$(( y + h - win_h - 12 )); inside=1 # no room: float inside bottom-right
    fi
    (( px + win_w > ox + mw )) && px=$(( ox + mw - win_w ))
    (( px < ox )) && px=$ox
    echo "$px $py $inside"
}

open_preview() {
    # $1 = mp4/gif path; reuse screenshot-popup with the 6s auto-close timer
    # pattern from screenshot.sh (annotate button is hidden for non-png).
    local out="$1" thumb="/tmp/screenrecord-thumb.png"
    local kind=mp4
    [[ "$out" == *.gif ]] && kind=gif
    if ffmpeg -hide_banner -loglevel error -y -i "$out" -vframes 1 -f image2 "$thumb" 2>/dev/null \
       && [[ -s "$thumb" ]]; then
        magick "$thumb" -resize 400x300 "$thumb" 2>/dev/null || true
    else
        thumb=""
    fi
    eww update screenshot_path="$out" screenshot_thumb="$thumb" screenshot_kind="$kind" 2>/dev/null || true
    eww open screenshot-popup 2>/dev/null || true

    local timer_pid_file="/tmp/eww-screenshot-timer.pid"
    if [ -f "$timer_pid_file" ]; then
        kill "$(cat "$timer_pid_file")" 2>/dev/null || true
    fi
    (sleep 6; eww close screenshot-popup 2>/dev/null || true; rm -f "$timer_pid_file") &
    echo $! > "$timer_pid_file"
}

arm_flow() {
    local w h x y
    if [[ -n "${SCREENRECORD_REGION:-}" ]]; then
        # test hook: "WxH+X+Y"
        local geom="${SCREENRECORD_REGION}"
        w=${geom%%x*}; geom=${geom#*x}
        h=${geom%%+*}; geom=${geom#*+}
        x=${geom%%+*}; y=${geom##*+}
    else
        local sel
        sel=$(slop -f "%w %h %x %y") || exit 0  # user cancelled: quiet exit
        read -r w h x y <<<"$sel"
    fi
    # normalize to even (h264), reject accidental tiny drags
    w=$(( w - (w % 2) )); h=$(( h - (h % 2) ))
    if (( w < 16 || h < 16 )); then
        notify "Region too small"
        exit 1
    fi

    local px py inside audio fmt
    read -r px py inside <<<"$(compute_placement "$w" "$h" "$x" "$y")"
    printf '%s %s %s %s %s %s %s\n' "$w" "$h" "$x" "$y" "$px" "$py" "$inside" > "$REC_ARMED_FILE"

    audio=$(cat "$AUDIO_PREF" 2>/dev/null || echo off)
    [[ "$audio" == "sys" ]] || audio=off
    fmt=$(get_format)

    eww update screen_recording=false screen_rec_elapsed= \
        screen_rec_region="${w} × ${h}" screen_rec_audio="$audio" \
        screen_rec_format="${fmt^^}" 2>/dev/null || true
    open_frame "$w" "$h" "$x" "$y"
    eww open rec-controls --arg "pos_x=${px}px" --arg "pos_y=${py}px" 2>/dev/null || true
}

cancel_arming() {
    rm -f "$REC_ARMED_FILE"
    eww_reset
}

toggle_audio() {
    local cur=off
    [[ -f "$AUDIO_PREF" ]] && cur=$(cat "$AUDIO_PREF" 2>/dev/null || echo off)
    local new=off
    [[ "$cur" != "sys" ]] && new=sys
    mkdir -p "$(dirname "$AUDIO_PREF")"
    printf '%s\n' "$new" > "$AUDIO_PREF"
    eww update screen_rec_audio="$new" 2>/dev/null || true
}

get_format() {
    local fmt
    fmt=$(cat "$FORMAT_PREF" 2>/dev/null || echo mp4)
    [[ "$fmt" == "gif" ]] || fmt=mp4
    echo "$fmt"
}

toggle_format() {
    local new=mp4
    [[ "$(get_format)" != "gif" ]] && new=gif
    mkdir -p "$(dirname "$FORMAT_PREF")"
    printf '%s\n' "$new" > "$FORMAT_PREF"
    eww update screen_rec_format="${new^^}" 2>/dev/null || true
}

start_from_armed() {
    # atomic consume: a rapid second __ui_start finds the file gone and
    # no-ops (plain rm has a check-then-act race between detached clicks)
    local consumed="$STATE_DIR/screenrecord.armed.consumed.$$"
    mv "$REC_ARMED_FILE" "$consumed" 2>/dev/null || exit 0
    local w h x y px py inside
    read -r w h x y px py inside < "$consumed"
    rm -f "$consumed"
    is_recording && exit 0                 # safety: never double-record

    local audio=off
    [[ -f "$AUDIO_PREF" ]] && audio=$(cat "$AUDIO_PREF" 2>/dev/null || echo off)

    local tmp start_epoch
    tmp=$(mktemp -u -t screenrecord.XXXXXX.mkv)
    start_epoch=$(date +%s)

    # note: -w takes the geometry directly ("-w WxH+X+Y"); the old
    # "-w region -region ..." form is deprecated since gsr 5.15
    local -a gsr_args=(-w "${w}x${h}+${x}+${y}"
        -f "$REC_FPS" -k h264 -q "$REC_QUALITY" -c mkv -o "$tmp")
    [[ "$audio" == "sys" ]] && gsr_args+=(-a "$REC_AUDIO_DEVICE")
    gpu-screen-recorder "${gsr_args[@]}" \
        </dev/null >"$LOG_FILE" 2>&1 8>&- 9>&- &
    local pid=$!
    echo "$pid" > "$REC_PID_FILE"
    printf 'tmp=%s\nstart=%s\n' "$tmp" "$start_epoch" > "$REC_META_FILE"

    # optimistic feedback (<100ms from click): flip bar + control bar into
    # recording state; the 3s health check below rolls this back on failure.
    # The frame stays up: it hugs the region from outside and is never
    # captured, and it marks exactly what is being recorded.
    eww update screen_recording=true screen_rec_elapsed="0:00" 2>/dev/null || true
    # bar floating INSIDE the region would be baked into the video: close it
    # (bar badge + hotkey carry the recording state in that case)
    (( inside )) && eww close rec-controls 2>/dev/null || true

    # startup health check: codec/monitor init failures kill GSR within 2-3s
    # (e.g. X11 capture with all monitors DPMS-off)
    sleep 3
    # if the pidfile is already gone, stop_recording consumed this recording
    # (user stopped within the health-check window) -- stay out of its way
    [[ -f "$REC_PID_FILE" ]] || exit 0
    if ! kill -0 "$pid" 2>/dev/null; then
        notify "Recorder failed to start: $(tail -1 "$LOG_FILE" 2>/dev/null | cut -c1-100)"
        rm -f "$REC_PID_FILE" "$REC_META_FILE" "$tmp"
        eww_reset
        exit 1
    fi

    # elapsed-time updater + unexpected-death watcher: exits on its own once
    # the recorder is gone; if the pidfile is still ours at that point, the
    # death was NOT a deliberate stop -> clean up and report
    ( while kill -0 "$pid" 2>/dev/null; do
          now=$(date +%s)
          el=$(( now - start_epoch ))
          eww update screen_rec_elapsed=$(( el / 60 )):$(printf '%02d' $(( el % 60 ))) 2>/dev/null || true
          sleep 1
      done
      if [[ -f "$REC_PID_FILE" ]] && [[ "$(cat "$REC_PID_FILE" 2>/dev/null)" == "$pid" ]]; then
          rm -f "$REC_PID_FILE" "$REC_META_FILE" "$tmp"
          eww_reset
          notify-send -u normal -t 6000 -a screenrecord ${ICON:+-i "$ICON"} "screenrecord" \
              "Recording failed: $(tail -1 "$LOG_FILE" 2>/dev/null | cut -c1-100)" 2>/dev/null || true
      fi
    ) </dev/null >/dev/null 2>&1 8>&- 9>&- &
}

# Two-pass ffmpeg palette encode mp4 -> gif with dunstify -r percentage
# progress (same replace-id as notify_r: the progress line is swapped
# in-place for the final result). The source mp4 is ALWAYS kept; on
# conversion failure the user is told where it is. Runs in a background
# subshell so the stop path returns instantly.
convert_to_gif() {
    local mp4="$1" gif="${1%.mp4}.gif"
    local palette prog
    palette=$(mktemp -t screenrecord-pal.XXXXXX.png)
    prog=$(mktemp -t screenrecord-prog.XXXXXX)
    trap 'rm -f "$palette" "$prog"' EXIT

    # total duration (us) for the percentage math; empty on probe failure
    # -> progress loop degrades to a spinner-less static line
    local dur total_us
    dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$mp4" 2>/dev/null || echo 0)
    total_us=$(awk -v d="${dur:-0}" 'BEGIN{printf "%d", d*1000000}')

    # pass 1: palette (fast; diff mode favors changed pixels, ideal for
    # screen content)
    notify_r "正在分析调色板…" 30000
    if ! ffmpeg -hide_banner -loglevel error -y -i "$mp4" \
            -vf "fps=$REC_GIF_FPS,palettegen=stats_mode=diff" "$palette"; then
        notify_r "GIF 转换失败，已保留 MP4: $(basename "$mp4")" 6000
        rm -f "$gif"
        return 1
    fi

    # pass 2: encode with progress; -progress appends key=value blocks to
    # $prog, the poller reads the latest out_time_us each tick
    ffmpeg -hide_banner -loglevel error -nostats -y \
        -i "$mp4" -i "$palette" \
        -lavfi "fps=$REC_GIF_FPS [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5" \
        -progress "$prog" "$gif" &
    local ffpid=$!
    while kill -0 "$ffpid" 2>/dev/null; do
        sleep 0.5
        local t_us pct
        t_us=$(awk -F= '/^out_time_us=/{v=$2} END{print v+0}' "$prog" 2>/dev/null || echo 0)
        pct=$(awk -v t="${t_us:-0}" -v total="$total_us" \
            'BEGIN{if(total>0){p=int(t*100/total); if(p>99)p=99; print p}else print 0}')
        notify_r "正在转换 GIF… ${pct}%" 30000
    done
    if ! wait "$ffpid"; then
        notify_r "GIF 转换失败，已保留 MP4: $(basename "$mp4")" 6000
        rm -f "$gif"
        return 1
    fi

    xclip -selection clipboard -t image/gif < "$gif" 2>/dev/null || true
    notify_r "GIF 已保存: $(basename "$gif") (已复制到剪贴板)" 4000
    open_preview "$gif"
}

stop_recording() {
    local pid tmp
    pid=$(cat "$REC_PID_FILE")
    tmp=$(awk -F= '/^tmp=/{print $2}' "$REC_META_FILE" 2>/dev/null || true)

    # remove state FIRST: the death watcher reads a missing pidfile as a
    # deliberate stop and stays quiet. eww_reset is the instant click
    # feedback (control bar closes within ~50ms).
    rm -f "$REC_PID_FILE" "$REC_META_FILE"
    eww_reset

    # in-progress indicator: remuxing a long recording takes a moment
    notify_r "正在导出视频…" 10000

    kill -INT "$pid" 2>/dev/null || true
    # wait for GSR to finalize the container (up to 15s)
    local i
    for i in $(seq 1 150); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    if kill -0 "$pid" 2>/dev/null; then
        notify_r "Recorder did not stop in 15s; recording discarded" 5000
        kill -9 "$pid" 2>/dev/null || true
        rm -f ${tmp:+"$tmp"}
        exit 1
    fi

    if [[ -z "${tmp:-}" || ! -s "$tmp" ]]; then
        notify_r "Nothing recorded" 4000
        rm -f ${tmp:+"$tmp"}
        exit 1
    fi

    local out
    out="$dir/$(date +%Y%m%d-%H%M%S).mp4"
    # lossless remux mkv -> mp4 (stream copy, no re-encode: full region
    # resolution, no duration cap, fast even for hour-long recordings)
    if ! ffmpeg -hide_banner -loglevel error -y -i "$tmp" \
        -c copy -movflags +faststart "$out"; then
        notify_r "Video export failed" 5000
        rm -f "$tmp"
        exit 1
    fi
    rm -f "$tmp"

    if [[ "$(get_format)" == "gif" ]]; then
        # mp4 stays on disk (source of truth + conversion fallback); the
        # GIF encode runs detached so the stop path returns instantly.
        notify_r "正在转换 GIF…" 30000
        ( convert_to_gif "$out" </dev/null >/dev/null 2>&1 8>&- 9>&- ) &
    else
        xclip -selection clipboard -t video/mp4 < "$out" 2>/dev/null || true
        notify_r "视频已保存: $(basename "$out") (已复制到剪贴板)" 4000
        open_preview "$out"
    fi
}

case "${1:-video}" in
    video)
        if is_recording; then
            stop_recording
        elif is_armed; then
            cancel_arming
        else
            arm_flow
        fi
        ;;
    __ui_start)  start_from_armed ;;
    __ui_stop)   is_recording && stop_recording ;;
    __ui_cancel) is_armed && cancel_arming ;;
    __ui_audio)  toggle_audio ;;
    __ui_format) toggle_format ;;
    __stop)
        is_recording && stop_recording
        ;;
    *)
        echo "Usage: screenrecord.sh [video|__ui_start|__ui_stop|__ui_cancel|__ui_audio|__ui_format|__stop]" >&2
        exit 1
        ;;
esac
