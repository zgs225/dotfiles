#!/usr/bin/env bash
# pinentry frontend for rbw: pinentry-rofi with the 绢纱琉璃 rofi theme.
# Args after `--` are forwarded by pinentry-rofi to its rofi invocation
# (each arg is shell-quoted individually, so pass option and value as
# separate argv words).
exec /usr/bin/pinentry-rofi -- \
    -theme "$HOME/.config/rofi/launcher.rasi" \
    -theme-str 'listview { lines: 0; } entry { placeholder: ""; }'
