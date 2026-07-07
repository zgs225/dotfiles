#!/usr/bin/env bash
# Called by defpoll (~3s). Emits a single JSON line consumed by the profile card.
# Fields: host, uptime, cpu (0-100), mem_used/mem_total/mem_pct,
#         disk_used/disk_total/disk_pct, temp (°C), temp_pct.

host=$(hostnamectl hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "linux")

# Uptime → compact "Xd Yh" / "Xh Ym" / "Xm".
up_s=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
d=$((up_s / 86400)); h=$(((up_s % 86400) / 3600)); m=$(((up_s % 3600) / 60))
if   [ "$d" -gt 0 ]; then uptime="${d}d ${h}h"
elif [ "$h" -gt 0 ]; then uptime="${h}h ${m}m"
else uptime="${m}m"; fi

# CPU usage: sample /proc/stat twice.
read -r _ a b c idle_a rest < /proc/stat
prev_idle=$idle_a
prev_total=$((a + b + c + idle_a))
for x in $rest; do prev_total=$((prev_total + x)); done
sleep 0.25
read -r _ a b c idle_b rest < /proc/stat
cur_idle=$idle_b
cur_total=$((a + b + c + idle_b))
for x in $rest; do cur_total=$((cur_total + x)); done
dt=$((cur_total - prev_total)); di=$((cur_idle - prev_idle))
if [ "$dt" -gt 0 ]; then cpu=$(( (100 * (dt - di)) / dt )); else cpu=0; fi
[ "$cpu" -lt 0 ] && cpu=0; [ "$cpu" -gt 100 ] && cpu=100

# Memory.
read -r mem_used_kb mem_total_kb < <(free -k | awk '/^Mem:/ {print $3, $2}')
mem_pct=$(( mem_total_kb > 0 ? 100 * mem_used_kb / mem_total_kb : 0 ))
hkib() { awk -v k="$1" 'BEGIN{ g=k/1048576; if (g>=1) printf "%.1fG", g; else printf "%dM", k/1024 }'; }
mem_used=$(hkib "$mem_used_kb"); mem_total=$(hkib "$mem_total_kb")

# Root disk.
read -r disk_used disk_total disk_pct < <(df -h --output=used,size,pcent / 2>/dev/null | awk 'NR==2{gsub("%","",$3); print $1, $2, $3}')
disk_used=${disk_used:-0}; disk_total=${disk_total:-0}; disk_pct=${disk_pct:-0}

# Temperature (CPU package).
temp=$(sensors 2>/dev/null | awk -F'[+.]' '/Package id 0:|Tctl:|Tdie:/{print $2; exit}')
if [ -z "$temp" ]; then
    t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
    temp=$((t / 1000))
fi
temp=${temp:-0}
temp_pct=$temp; [ "$temp_pct" -gt 100 ] && temp_pct=100

printf '{"host":"%s","uptime":"%s","cpu":%d,"mem_used":"%s","mem_total":"%s","mem_pct":%d,"disk_used":"%s","disk_total":"%s","disk_pct":%d,"temp":%d,"temp_pct":%d}\n' \
    "$host" "$uptime" "$cpu" "$mem_used" "$mem_total" "$mem_pct" "$disk_used" "$disk_total" "$disk_pct" "$temp" "$temp_pct"
