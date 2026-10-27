#!/usr/bin/env bash
# check-bars.sh — chequeo de consistencia entre las 4 barras de quickshell
# + deteccion de pixeles sin escalar (literals sin Scaling.px).
#
# Uso: bash check-bars.sh    (exit 0 = ok, exit 1 = hallazgos)
#
# Regla del proyecto: las 4 barras (.config/quickshell/{hyprland,sway,niri,mango}-bar)
# son COPIAS entre si; solo pueden diferir los archivos del allowlist de abajo
# (especificos del WM). Cualquier otra diferencia = deriva (fix no replicado).
# Correr antes de cada release (ver NOTAS-FIXES Fix 33).
set -u
cd "$(dirname "$0")"
QS=.config/quickshell
BARS=(hyprland-bar sway-bar niri-bar mango-bar)

# Archivos permitidos a diferir o existir solo en alguna barra
# (rutas relativas a la dir de cada barra). Si agregas una diferencia
# legitima por WM, agregala AQUI con un comentario (Fix 33).
ALLOWLIST="
# scripts de helper por WM
hide-on-fullscreen.sh
hyprland-config-snippet-legacy.conf
hyprland-config-snippet.lua
sway-config-snippet.conf
niri-config-snippet.kdl
mango-config-snippet.conf
launch-with-icon-theme.sh
# modulos con logica IPC especifica del WM
modules/ActiveWindow.qml
modules/BarConfigPopup.qml
modules/BarConfig.qml
modules/Bar.qml
modules/ConfigButton.qml
modules/FocusedScreen.qml
modules/KeybindsPopup.qml
modules/LauncherPopup.qml
modules/Notifications.qml
modules/PowerMenuPopup.qml
modules/Scaling.qml
modules/WindowListPopup.qml
modules/Workspaces.qml
README.md
shell.qml
"

fail=0
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

in_allowlist() { grep -qx "$1" <<< "$ALLOWLIST"; }

echo "== 1) Deriva entre barras =="
(cd "$QS/hyprland-bar" && find . -type f | sed 's|^\./||' | sort) > "$tmpdir/hyprland-bar"
for b in sway-bar niri-bar mango-bar; do
    (cd "$QS/$b" && find . -type f | sed 's|^\./||' | sort) > "$tmpdir/$b"
done

# Archivos presentes en una barra y ausentes en otra (fuera del allowlist)
while IFS= read -r f; do
    [ -z "$f" ] && continue
    in_allowlist "$f" && continue
    for b in sway-bar niri-bar mango-bar; do
        if ! grep -qx "$f" "$tmpdir/$b"; then
            echo "DERIVA: '$f' existe en hyprland-bar pero no en $b (no esta en el allowlist)"
            fail=1
        fi
    done
done < "$tmpdir/hyprland-bar"
for b in sway-bar niri-bar mango-bar; do
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        in_allowlist "$f" && continue
        if ! grep -qx "$f" "$tmpdir/hyprland-bar"; then
            echo "DERIVA: '$f' existe en $b pero no en hyprland-bar (no esta en el allowlist)"
            fail=1
        fi
    done < "$tmpdir/$b"
done

# Archivos presentes en todas pero con contenido distinto (fuera del allowlist)
while IFS= read -r f; do
    [ -z "$f" ] && continue
    in_allowlist "$f" && continue
    for b in sway-bar niri-bar mango-bar; do
        grep -qx "$f" "$tmpdir/$b" || continue
        if ! cmp -s "$QS/hyprland-bar/$f" "$QS/$b/$f"; then
            echo "DERIVA: '$f' difiere entre hyprland-bar y $b (no esta en el allowlist)"
            fail=1
        fi
    done
done < "$tmpdir/hyprland-bar"

[ "$fail" -eq 0 ] && echo "(sin deriva)"

echo
echo "== 2) Pixeles sin escalar (deben dar 0 resultados; el 0 no se escala) =="
hits=$(grep -rnE "(radius|columnSpacing|rowSpacing|spacing): [1-9][0-9]*$|border\.width: [1-9][0-9]*$|anchors\.margins: [1-9][0-9]*$" \
    "$QS"/hyprland-bar/modules/ "$QS"/sway-bar/modules/ "$QS"/niri-bar/modules/ "$QS"/mango-bar/modules/ 2>/dev/null || true)
if [ -n "$hits" ]; then
    echo "$hits"
    fail=1
else
    echo "(ninguno)"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "OK: sin deriva entre barras y sin pixeles sin escalar."
else
    echo "HALLAZGOS: revisar la salida de arriba."
fi
exit "$fail"
