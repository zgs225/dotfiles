#!/usr/bin/env bash
# Power panel info for the eww power popup.
# Called by defpoll (~3s). Emits JSON:
# {source,watts,percent,health,cycles,eta,eta_label,threshold,dgpu,dgpu_icon,dgpu_holders,icon_fullcharge}
# Never calls nvidia-smi (that would wake the dGPU).
set -u

B=/sys/class/power_supply/BAT0
A=/sys/class/power_supply/AC0/online
DGPU=/sys/bus/pci/devices/0000:01:00.0/power/runtime_status

ICON_DGPU_SLEEP=$(printf '\uf186')
ICON_DGPU_ACTIVE=$(printf '\uf0e7')
ICON_FULLCHARGE=$(printf '\uf240')

read_num() { cat "$1" 2>/dev/null || echo 0; }

source=bat
[ "$(read_num $A)" = "1" ] && source=ac
status=$(cat $B/status 2>/dev/null)
power_uw=$(read_num $B/power_now)
watts=$(awk -v u="$power_uw" 'BEGIN{printf "%.1f", u/1e6}')
percent=$(read_num $B/capacity)
ef=$(read_num $B/energy_full)
efd=$(read_num $B/energy_full_design)
health=$(awk -v f="$ef" -v d="$efd" 'BEGIN{ if(d>0) printf "%.0f", f*100/d; else printf "--" }')
cycles=$(read_num $B/cycle_count)
en=$(read_num $B/energy_now)

eta="--"
eta_label="剩余"
if [ "$status" = "Discharging" ] && [ "$power_uw" -gt 0 ]; then
    eta=$(awk -v e="$en" -v p="$power_uw" 'BEGIN{printf "%.1f h", e/p}')
elif [ "$status" = "Charging" ] && [ "$power_uw" -gt 0 ] && [ "$ef" -gt "$en" ]; then
    eta=$(awk -v e="$en" -v f="$ef" -v p="$power_uw" 'BEGIN{printf "%.1f h", (f-e)/p}')
    eta_label="充满"
fi

threshold=$(read_num $B/charge_control_end_threshold)

dgpu=$(cat $DGPU 2>/dev/null || echo unknown)
dgpu_icon="$ICON_DGPU_ACTIVE"
holders=""
if [ "$dgpu" = "suspended" ]; then
    dgpu_icon="$ICON_DGPU_SLEEP"
elif [ "$dgpu" = "active" ]; then
    holders=$(timeout 2 lsof /dev/nvidia* 2>/dev/null | awk 'NR>1 {print $1}' | sort -u | grep -v '^Xorg$' | head -3 | paste -sd, -)
fi

printf '{"source":"%s","watts":"%s","percent":%s,"health":"%s","cycles":%s,"eta":"%s","eta_label":"%s","threshold":"%s","dgpu":"%s","dgpu_icon":"%s","dgpu_holders":"%s","icon_fullcharge":"%s"}\n' \
    "$source" "$watts" "$percent" "$health" "$cycles" "$eta" "$eta_label" "$threshold" "$dgpu" "$dgpu_icon" "$holders" "$ICON_FULLCHARGE"
