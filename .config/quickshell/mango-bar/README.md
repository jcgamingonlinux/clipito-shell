# Clipito Shell — variante Mango WM

Mismo set de módulos que las variantes de Hyprland/niri/Sway (barra,
launcher, notificaciones, power menu, wallpaper picker con Wallhaven,
listado de ventanas, visor de atajos, dock de configuración, systray,
batería, red, bluetooth, etc.) portado a [Mango WM](https://github.com/mangowm/mango)
("dwm pero Wayland", construido sobre dwl + scenefx).

Escrito primero contra la documentación pública de mango (wiki + man page
de `mmsg`), y ya con una primera ronda de pruebas reales en Debian 14
forky (2026-09-19) que confirmó el esquema de `all-tags` y encontró/
arregló un bug real en `FocusedScreen.qml` — ver "Probado hasta ahora"
más abajo. Lo que falta probar en vivo es el **esquema exacto del JSON**
de un par de campos más — ver "Qué verificar" más abajo. Todo el código
deja un `console.log` con el JSON crudo la primera vez que algo no
matchea, así que ajustar un nombre de campo es cambiar una línea, no
reescribir nada.

## Probado hasta ahora (Debian 14 forky, 2026-09-19)

- ✅ La barra carga y corre.
- ✅ **`all-tags` confirmado.** El esquema real es
  `{"all_tags":[{"monitor":"...","tags":[{"index":N,"is_active":bool,
  "is_urgent":bool,"layout":"T","client_count":N}]}]}` — `Workspaces.qml`
  ya está actualizado a esto (dejó de ser una suposición).
- 🔧 **Bug real encontrado y arreglado:** `FocusedScreen.qml` asumía que
  `get all-monitors` devolvía un array directo, pero mango lo envuelve
  igual que `all-tags` (probablemente `{"all_monitors":[...]}`). Esto
  hacía que `FocusedScreen.name` quedara siempre en `""`, y como **todos**
  los popups de `shell.qml` se muestran con la condición
  `modelData.name === FocusedScreen.name`, ninguno llegaba a aparecer —
  esto era la causa de "hago click y no aparece ninguna ventana". Ya
  corregido; falta reconfirmar en la próxima prueba que el nombre del
  monitor enfocado se resuelve bien (el campo exacto dentro de cada
  monitor todavía no se vio en crudo).

## Diferencia de fondo con las otras 3 variantes

Hyprland/niri/Sway tienen un workspace activo por monitor. Mango usa
**tags estilo dwm**: siempre existen los 9 (1-9), una ventana puede estar
en más de uno, y podés VER más de un tag a la vez ("multiview"). Por eso:

- `Workspaces.qml` ya no lista "los workspaces que hay" — dibuja los 9
  tags fijos siempre, coloreados según ocupado/visible/urgente.
- **Click izquierdo** en un tag = `view` (mirar solo ese tag).
- **Click derecho** en un tag = `toggleview` (sumar/sacar ese tag de la
  vista actual, sin perder los demás — esto es el multiview).
- El snippet de config agrega `CTRL+SHIFT+1..9` como equivalente por
  teclado del click derecho.

## Instalación

1. Copiá esta carpeta a `~/.config/quickshell/mango-bar/`
2. `mmsg` ya viene con mango, no hay que instalar nada aparte para el IPC.
3. Pegá el contenido de `mango-config-snippet.conf` dentro de tu
   `~/.config/mango/config.conf` (agregalo, no reemplaces tu config).
4. Dependencias del resto de los módulos: las mismas que ya tenés
   instaladas para hyprland-bar/niri-bar/sway-bar (no cambian — son todas
   compositor-agnósticas: bluetooth, red, batería, etc.).
5. (Opcional) `sh ~/.config/quickshell/mango-bar/hide-on-fullscreen.sh`
   como `exec-once` aparte si querés el respaldo de auto-ocultado en
   fullscreen.

## Qué verificar la primera vez que lo corras

Con quickshell corriendo en una terminal (para ver los `console.log`):

1. **`FocusedScreen.qml`**: con el fix, fijate en la consola si loguea
   "no encontré un array de monitores" o "no reconocí el campo de foco"
   — si aparece cualquiera de los dos, pasame el JSON crudo que imprime.
2. **Campos de `get/watch focusing-client`** (`ActiveWindow.qml`, título
   y app-id): abrí una ventana y mirá la consola. Si no aparece bien,
   correlo a mano: `mmsg get focusing-client` y ajustá `applyClient()`.
3. **Campos de `get all-clients`** (`WindowListPopup.qml`): abrí el
   listado de ventanas (Super+Alt+Tab), la consola tira un ejemplo crudo
   del primer cliente la primera vez.
4. **`hide-on-fullscreen.sh`**: el nombre del campo `fullscreen` es una
   suposición (ver comentario en el script).
5. **Ruta de config**: `KeybindsPopup.qml` lee
   `~/.config/mango/config.conf` (confirmado en la wiki, "quick-start") —
   si vos la moviste, ajustá `configPath` en el archivo o avisame.

## Atajos de Clipito Shell (mismos en las 4 variantes)

| Atajo | Acción |
|---|---|
| Super+Alt+D | Launcher |
| Super+Shift+X | Power menu |
| Super+Alt+W | Selector de wallpaper |
| Super+Alt+K | Visor de atajos |
| Super+Alt+Tab | Listado de ventanas |
| Super+Alt+, | Ajustes de la barra |
| Super+Alt+B | Alternar auto-ocultado |
| Super+Alt+C | Dock de configuración |
| Ctrl+1..9 | Ver tag N *(default de mango, no de este snippet)* |
| Alt+1..9 | Mover ventana a tag N *(default de mango)* |
| Ctrl+Shift+1..9 | Multiview: sumar/sacar tag N |

## Limitaciones conocidas

- El feature de temas de color (Catppuccin/Gruvbox/Nord/etc.) está
  pausado/cancelado en todo el proyecto por ahora, no es específico de
  esta variante.
- Cava/visualizador de audio no está incluido (se está probando aparte).
- El parser de `KeybindsPopup.qml` no sigue ningún `source=` si dividís
  tu config.conf en varios archivos — apuntá `configPath` directo al que
  tiene los binds si es tu caso.
