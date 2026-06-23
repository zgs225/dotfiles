#!/bin/bash

WIDTH=$(xrandr 2>/dev/null | grep '*' | awk '{print $1}' | cut -d'x' -f1)

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

if [ "$DPI" -ge 192 ]; then
    PAD1=2; BDR=4; PAD4=8; PAD6=12; PAD8=16; PAD20=40; PAD30=60
    BDR_R4=8; BDR_R8=16; BDR_RL=12; WIN_SM=320; WIN_MD=480; WIN_W=960
    EL_SP=8; FONT=24; MARGIN="0 0 12 0"
elif [ "$DPI" -ge 144 ]; then
    PAD1=2; BDR=3; PAD4=6; PAD6=9; PAD8=12; PAD20=30; PAD30=45
    BDR_R4=6; BDR_R8=12; BDR_RL=9; WIN_SM=240; WIN_MD=360; WIN_W=720
    EL_SP=6; FONT=18; MARGIN="0 0 9 0"
else
    PAD1=1; BDR=2; PAD4=4; PAD6=6; PAD8=8; PAD20=20; PAD30=30
    BDR_R4=4; BDR_R8=8; BDR_RL=6; WIN_SM=160; WIN_MD=240; WIN_W=480
    EL_SP=4; FONT=12; MARGIN="0 0 6 0"
fi

cat > /tmp/rofi-dpi.rasi <<EOF
configuration {
    font: "Noto Sans CJK SC ${FONT}";
}

* {
    rofi-pad-1: ${PAD1};
    rofi-bdr: ${BDR};
    rofi-pad-4: ${PAD4};
    rofi-pad-6: ${PAD6};
    rofi-pad-8: ${PAD8};
    rofi-pad-20: ${PAD20};
    rofi-pad-30: ${PAD30};
    rofi-bdr-radius4: ${BDR_R4};
    rofi-bdr-radius8: ${BDR_R8};
    rofi-bdr-radius-lg: ${BDR_RL};
    rofi-win-sm: ${WIN_SM};
    rofi-win-md: ${WIN_MD};
    rofi-win-width: ${WIN_W};
    rofi-el-spacing: ${EL_SP};
    rofi-inputbar-margin: ${MARGIN};
    rofi-msg-margin: ${MARGIN};
    rofi-lv-padding: ${PAD4} 0 0 0;
    rofi-el-padding-pm: ${PAD8} ${PAD20};
    rofi-el-padding-kh: ${PAD6} ${PAD8};
    rofi-font-size: ${FONT};
}
EOF
