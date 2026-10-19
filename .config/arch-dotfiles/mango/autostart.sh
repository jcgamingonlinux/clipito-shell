#!/bin/bash
# 自启动脚本 仅作参考

set +e

# ensure xdg-desktop-portal running without last dirty state
systemctl --user restart xdg-desktop-portal &

# some env can't auto run the portal, so need this
/usr/lib/xdg-desktop-portal-wlr  >/dev/null 2>&1 &

# Resolucion con wlr-randr
# wlr-randr --output Virtual-1 --mode 1440x900 --pos 0,0 --transform normal --scale 1


# --- Arranque de Clipito Shell con Mango ---
# Usá esta línea EN VEZ de "exec-once = qs -c mango-bar" a secas, para que
# detecte el tema de íconos GTK igual que en las otras 3 variantes.
~/.config/quickshell/mango-bar/launch-with-icon-theme.sh


# xwayland dpi scale
echo "Xft.dpi: 140" | xrdb -merge #dpi缩放
# xrdb merge ~/.Xresources >/dev/null 2>&1

# ime input
fcitx5 --replace -d >/dev/null 2>&1 &

# network
nm-applet >/dev/null 2>&1 &

# Permission authentication
# /usr/lib/xfce-polkit/xfce-polkit >/dev/null 2>&1 &

# inhibit by audio
# sway-audio-idle-inhibit >/dev/null 2>&1 &

# change light value and volume value by swayosd-client in keybind
# swayosd-server >/dev/null 2>&1 &
