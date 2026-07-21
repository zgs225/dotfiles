#!/usr/bin/env bash
# shichen.sh - print the traditional Chinese double-hour alongside civil time.
# Output: "申时 · 15:42"
# Mapping: zi 23-1, chou 1-3, yin 3-5, mao 5-7, chen 7-9, si 9-11,
#          wu 11-13, wei 13-15, shen 15-17, you 17-19, xu 19-21, hai 21-23.

names=(子 丑 寅 卯 辰 巳 午 未 申 酉 戌 亥)
hour=$(date +'%H' | sed 's/^0//')
idx=$(( (hour + 1) / 2 % 12 ))
printf '%s时 · %s\n' "${names[$idx]}" "$(date +'%H:%M')"
