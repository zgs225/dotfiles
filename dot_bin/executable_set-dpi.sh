#!/bin/bash

WIDTH=$(xrandr | grep '*' | awk '{print $1}' | cut -d'x' -f1)

if [ "$WIDTH" -ge 3000 ]; then
    DPI=192
elif [ "$WIDTH" -ge 2700 ]; then
    DPI=168
elif [ "$WIDTH" -ge 2000 ]; then
    DPI=144
else
    DPI=96
fi

xrdb -merge <<< "Xft.dpi: $DPI"
