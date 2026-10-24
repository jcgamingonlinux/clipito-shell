# Clipito Shell — Fixes aplicados (2026-10-14)

(fork de `https://gitlab.com/linux-en-casa/claudito-shell`).

Publicado como fork: `https://github.com/jcgamingonlinux/clipito-shell` (main).

## Bugs corregidos

### 1. [BLOQUEANTE] `01-install-arch.sh` — paquete inexistente `xorg`
- **Línea 178** (array `pkgs_base`): `xorg` no existe como paquete en
  Arch (core/extra/multilib). Verificado contra los índices
  `*.db.tar.gz` (15.522 paquetes) y la API JSON de archlinux.org.
  Solo existen paquetes `xorg-*`. `pacman -S` fallaba y abortaba
  la instalación base.
- **Fix:** `xorg` → `xorg-server` (el X server real; `xorg-xwayland`
  ya se instala aparte por compositor).

### 2. [FUNCIONAL] `01-install-arch.sh` — condición invertida en yay/paru
- **Líneas 1061 y 1075**: `if [ ! -d "/tmp/yay" ]; then sudo rm -rf
  ...` borraba el directorio solo cuando **no** existía. En una
  re-ejecución del script, `git clone` fallaba (directorio ya
  ocupado) y el script abortaba.
- **Fix:** `[ ! -d ... ]` → `[ -d ... ]` en ambos casos (yay y paru).
- **Fix adicional (copy-paste):** en el caso paru el mensaje de error
  decía "No se pudo instalar yay." → ahora "No se pudo borrar
  /tmp/paru." (el de yay quedó "No se pudo borrar /tmp/yay.").

### 3. [COSMÉTICO] `03-install-forky.sh` — mensajes copy-paste
- **Líneas 978 y 989** (caso mango): decían "borrando directorio
  temporal de ly" al borrar `/tmp/scenefx` y `/tmp/mango`.
- **Fix:** ahora dicen "de scenefx" y "de mango" respectivamente.
  El de línea 1169 (caso `ly`, directorio `/tmp/ly`) era correcto y
  se mantuvo.

### 4. [MEDIO] `01-install-arch.sh` — no se copiaban configs de terminal
- Hyprland usa kitty, niri usa alacritty, sway usa foot, pero el
  script arch solo copiaba la config del compositor: cada terminal
  arrancaba con su config por defecto.
- **Fix:** se agregaron los bloques de copia (mismo patrón que ya
  tiene `03-install-forky.sh`): `backup_if_exists` + `rm -rf` +
  `cp -r kitty/|alacritty/|foot/ $HOME/.config/` en cada caso
  respectivo. Los directorios `.config/kitty`, `.config/alacritty` y
  `.config/foot` ya existían en el repo.

### 5. [MEDIO] `02-install-trixie.sh` — misma falta que 4
- **Fix:** idéntico al 4, en los casos hyprland/niri/sway.

### 6. [COSMÉTICO] `01-install-arch.sh` — mensajes SDDM en el caso `ly`
- **Líneas 1058 y 1060** (caso `ly)` de display managers): dos
  check_error **comentados** decían "No se pudo instalar/activar
  SDDM" (copy-paste del caso sddm). Solo estético (están en
  comentarios), pero se corrigió igual: ahora dicen "ly".
- Hallazgo reportado por el pase de calidad (subagente) tras
  aplicar los fixes 1-5.

### 7. [FUNCIONAL] Menús: no advertía si el usuario no seleccionaba nada (los 3 scripts)
- **El problema:** en los 5 menús de selección (WM, Software, Apps, DM,
  Flatpak), si el usuario presionaba ENTER sin marcar ninguna opción
  (o desmarcaba todas), el script seguía adelante **sin avisar** con
  esa sección vacía: en una instalación nueva quedaba sin WM o sin
  pack de software y el usuario no entendía por qué no se instaló
  nada. No había ninguna ayuda con las teclas que había que usar.
- **Fix:** nueva función `warn_no_selection()` + cada menú ahora
  entra en un loop: si se confirma con la selección vacía, muestra un
  aviso de diálogo explicando que hay que elegir al menos una opción
  con las teclas (ESPACIO = marcar/desmarcar, ENTER = confirmar,
  ESC = volver sin tocar la selección) y reabre el menú. Si el
  usuario presiona ESC, se mantiene el estado previo (comportamiento
  original). Se aplica a los 5 menús de los 3 scripts (código
  idéntico en los tres, verificado por md5).
- **Verificado:** (1) harness unitario con `dialog` simulado contra el
  código real extraído del archivo — 3 casos: vacío → aviso →
  reabre → se aplica la selección; selección directa sin aviso; ESC
  sin tocar el estado previo. (2) Test visual en vivo en la mini PC
  (CachyOS, mini PC Minisforum X1 Lite Elite 2): con el menú de WMs vacío, ENTER mostró
  el aviso exacto y reabrió el menú; después se marcó hyprland con
  ESPACIO+ENTER y quedó `wm_hyprland=1` en `~/.wm-installer-state`.

### 8. [FUNCIONAL] Menús: "Cancelar" cerraba el script (set -e) en vez de volver al menú (los 3 scripts)
- **El problema:** el script arranca con `set -euo pipefail`. Con ese modo,
  un `dialog` que devuelve 1 (Cancelar/ESC/No) **mata el script** si no
  está protegido con `||`. En "Restaurar backup" (y en el diálogo de
  confirmación de restauración, el checklist de archivos y la pantalla
  de bienvenida) las llamadas a dialog estaban sin proteger:
  `chosen=$(dialog ... --menu ...)` → al presionar Cancelar, `dialog`
  devuelve 1, la asignación falla y `set -e` cierra todo el script,
  cuando lo esperado era volver al menú principal.
- **Fix (los 3 scripts):**
  - `show_restore_menu`: `chosen=$(dialog ... --menu ...)` ahora termina
    en `|| return 0` → Cancelar vuelve al menú principal.
  - `restore_backup`: el checklist `selected=$(dialog ...)` termina en
    `|| { rm -f "$idx_file"; return 0; }` (y además limpia el índice
    temporal).
  - Los dos `--yesno` ("Confirmar restauración" y la pantalla de
    bienvenida) cambiaron de `dialog ... ; if [[ $? -ne 0 ]]` a un
    `if dialog ...; then ... else ... fi` directo: con el patrón viejo,
    el `dialog` suelto que devuelve 1 moría por `set -e` antes de leer
    el `$?`.
  - El aviso `warn_no_selection` ahora devuelve el rc del dialog
    (`|| rc=$?` + `return "$rc"`), y los 5 menús usan `if ! warn_
    no_selection ...; then return 0; fi`: ENTER en el aviso reabre el
    menú; **ESC en el aviso vuelve al menú principal sin tocar la
    selección** (lo que dice el propio texto del aviso).
  - Todos los msgbox/infobox restantes (Resumen, Léeme, Bienvenida,
    Preparando, "no hay backups", "restauración completada", etc.)
    llevan `|| true` para que un ESC/cierre no mate el script.
- **Verificado:** harness contra el código real extraído de cada script
  (4 escenarios por archivo, 15 ejecuciones): cancelar en el menú de
  fechas, cancelar en el checklist, "No" en la confirmación, y una
  restauración completa exitosa (archivo realmente restaurado). Los 3
  scripts pasan.

### 9. Créditos: "JC Gaming On Linux - fork, mejoras y testeo, asistido por JC IA"
- Agregado en los 3 scripts: (a) bloque de créditos al inicio del
  archivo y (b) en el diálogo "Instrucciones - Léeme"

### 10. Advertencia "WM primero" + créditos en Bienvenida (los 3 scripts)
- **Problema reportado:** al pasar a otra sección sin haber elegido un
  Window Manager, el script se cerraba en vez de indicar que falta el WM.
- **Fix (los 3 scripts):**
  - Nueva función `wm_selected()` (0 = hay al menos un WM marcado).
  - En el bucle del menú principal, toda opción que no sea `wm` pasa
    primero por `if ! wm_selected; then`: muestra el aviso
    "Falta el Window Manager — Todavía no seleccionaste ningún Window
    Manager. Vole al menú principal y elegí primero el WM (opción 1)
    antes de continuar." y, tras Aceptar (ENTER), `continue` de vuelta
    al menú principal. Con WM elegido, las secciones abren como siempre.
  - Créditos "JC Gaming On Linux - fork, mejoras y testeo, asistido por
    JC IA" agregados también en la pantalla de **Bienvenida** igual que en el Léeme.
- **Verificado en vivo (mini PC, HOME fresco):** bienvenida muestra el
  crédito; entrar a software/apps/dm/summary/restore/leeme sin WM
  muestra el aviso y Aceptar vuelve al menú principal; con WM marcado
  (niri) las secciones abren sin aviso. Secciones probadas sin WM
  (todas OK, sin crash): software (básico), apps (yay), dm (sddm),
  summary, restore, leeme.

### 11. [FUNCIONAL] Fixes defensivos `set -e`: estado viejo, HOME y hostnamectl (los 3 scripts)
- **Problema (hallado por el pase de QA):** con `set -euo pipefail`,
  tres líneas podían cerrar el script de forma silenciosa:
  - `load_state`: la línea `[[ -v WM_DESC[$k] ]] && SEL_WM[$k]=$v`
    (y las de `apps_*`/`flatpak_*`) devuelve 1 si el archivo de estado
    trae una clave que ya no existe en el menú (ej. `wm_mango=1` en la
    versión Arch, que no tiene mango). Si esa era la última línea, el
    `while` devolvía 1, la función devolvía 1 y la llamada suelta
    `load_state` moría el script al arrancar.
  - `save_state`: la primera línea `: > "$STATE_FILE"` fallaba si el
    directorio de `$HOME` no existía (ej. arranque con HOME inválido).
  - `show_welcome` (01): `host="$(hostnamectl | grep hostname | awk ... )"`:
    si `hostnamectl` no existe o no emite "hostname" (sin systemd), el
    pipeline fallaba y moría el script en la Bienvenida.
- **Fix (los 3 scripts; `hostnamectl` solo existe en 01):**
  - `load_state`: `|| true` en las 3 líneas de asignación + `return 0`
    explícito al final.
  - `save_state`: `mkdir -p "$(dirname "$STATE_FILE")"` antes de
    escribir.
  - `01 show_welcome`: `hostnamectl 2>/dev/null | ... || true`.
- **Verificado:** `bash -n` en los 3; harness unitario contra el código
  real extraído (T1: estado viejo con clave inválida → sobrevive y
  conserva las válidas; T2: HOME inexistente → `save_state` crea el
  directorio y escribe; T3: pipeline de `hostnamectl` fallando → no
  mata el script); test A/B de la función `load_state` con el estado
  viejo (sin fix: devuelve 1 y moría; con fix: rc=0); consistencia
  entre los 3 scripts (los parches son idénticos, verificado por
  patrón). Además: todos los usos de `check_error` llevan `|| exit 1`
  (36/36 en 01, 35/35 en 02, 40/40 en 03) y `SEL_WM` está
  inicializado para todas las claves, por lo que `wm_selected` es
  seguro bajo `set -u`.

### 12. Crédito de YouTube + descripción del pack `full` (los 3 scripts)
- **Modificación hecha en el script de Arch, replicada en 02/03:**
  - Créditos del header: línea `# https://www.youtube.com/@jcgamingonlinux`
    bajo "JC Gaming On Linux - fork, mejoras y testeo, asistido por JC IA".
  - Bienvenida: `animate_text "https://www.youtube.com/@jcgamingonlinux"`
    bajo la línea de @LinuxenCasa.
  - `SOFTWARE_DESC [full]`: "Full - Todo el BloatWare de Paquetes" →
    "Full - BloatWare al más puro estilo Windows 11" (redacción final;
    intermedia: "…Todo el BloatWare de Paquetes al más puro estilo…").
  - En `01`: además, limpieza de la lista de paquetes (líneas en blanco
    dentro de `pkgs_extra_full` y `pkgs_wm_wayland` quitadas, e
    indentación corregida en `ttf-jetbrains-mono-nerd` y el bloque
    `nwg-displays`/`pipewire`/`pipewire-alsa`/`pipewire-pulse`/
    `wireplumber`); en `03` el mismo bloque `nwg-displays`/`pipewire*`
    llevaba las líneas en blanco y la indentación vieja → mismo fix.
    En `02` las listas ya estaban limpias (no aplica).
- **Verificado:** `bash -n` OK en los 3; conteo de patrones
  (`jcgamingonlinux` ×2 y "Windows 11" ×1 en cada uno); bytes del bloque
  `nwg-displays` de `03` idénticos a los de `01` (verificado con
  `cat -A`).

### 13. [FUNCIONAL] `check_error`: mensajes de error muertos bajo `set -e` (los 3 scripts)
- **Problema:** el patrón original era:
  ```
  cmd
  check_error "mensaje" || exit 1
  ```
  Bajo `set -e` (línea 2), si `cmd` fallaba el script salía **antes** de
  llegar a `check_error`: el mensaje amable en español nunca se
  mostraba (código muerto). Solo se veía el error crudo de apt/pacman
  y el script paraba sin explicación.
- **Fix:** 97 sitios transformados a `cmd || check_error "mensaje"`:
  al fallar, `check_error` sí se ejecuta, muestra "Error: …" y sale.
  En el camino de éxito el comportamiento es idéntico (sin mensaje).
  Casos especiales:
  - `flatpak remote-add … || true` + `check_error` (3 sitios, 1 por
    script): la `|| true` dejaba la check 100% muerta (siempre veía
    `$?=0`) → la `|| true` se reemplazó por
    `|| check_error "No se pudo añadir el repositorio Flathub."` (el
    fallo del remoto ahora es fatal con mensaje; antes continuaba en
    silencio y el `flatpak install` siguiente fallaba más tarde sin
    explicación).
  - 4 sitios donde `check_error` seguía a un bloque `fi` (sway en 01,
    sway en 02, mango y sway en 03): guard colgado en el `sudo cp
    *.desktop` del interior del bloque (el punto real de fallo) y la
    línea muerta eliminada.
- **Verificado:** `bash -n` OK en los 3; test aislado del patrón
  (éxito: sin mensaje y continúa; fallo: mensaje + exit 1); diff
  completo revisado a mano (97 insertions / 194 deletions).
- **Fuente:** pase de QA round 13 (subagente con ojos frescos) —
  avisos de `apt update` sin guard; la auditoría propia amplió el
  finding al patrón completo de `check_error`.

## Optimizaciones APLICADAS (0.2)

1. **Forky: mango fijado al tag `0.14.4`** (`git clone -b 0.14.4
   https://github.com/mangowm/mango.git`). Antes compilaba desde
   `master` (sin version fija; hoy era 0.18.0, la config del repo
   está probada contra 0.14.4, la misma del `.deb` de trixie).
   El tag `0.14.4` existe (verificado en GitHub API).

## Desinstalación (04-uninstall-arch.sh) — PROBADO EN MÁQUINA REAL (2026-10-19/20)

- **Máquina:** mini PC Minisforum (Ryzen H 255), **distribución actual: CachyOS**
  (la que corre en la mini PC de pruebas).
- **Escenario:** instalación completa del repo (hyprland + quickshell + kitty, 14–15
  oct) sobre una base LXQt (sddm, breeze). Desinstalar para volver al estado
  original sin tocar nada preexistente.
- **Resultado:** **éxito**. 66 paquetes quitados, 14 archivos/directorios borrados,
  `~/.config/gtk-3.0` restaurado al estado exacto original, 0 huérfanos nuevos,
  `sddm` intacto como DM.

### Lista exacta de paquetes (lo central del test)
- `/var/log/pacman.log` distinguía `[ALPM] installed` (70 paquetes que el
  instalador **agregó de verdad**) de `[ALPM] upgraded` (preexistentes solo
  actualizados: `vim`, `fastfetch`, `imagemagick`, `discord`, `telegram-desktop`,
  stack KDE, `python-pydantic`, …) → de esos últimos **no se tocó ninguno**.
- Análisis de `Required By`: 4 de los 70 hoy los piden paquetes preexistentes →
  conservados (`graphicsmagick`→`zbar`, `libadwaita`→`gnome-firmware`,
  `python-anyio`→`python-httpx2`, `ministream`→`libadwaita`). Lista final: **66**.
- Dry-run con `pacman -Rp` real: la primera pasada detectó el conflicto
  `ministream`/`libadwaita`; la segunda quedó limpia antes de ejecutar.

### Verificado tras el run
- **Fuera:** hyprland, quickshell, kitty, yay, thunar, dialog, acpi, swaylock,
  wlr-randr, yad, zenity, xorg-xwayland, nwg-displays, hyprland-guiutils
  (verificado con `pacman -Qi`).
- **Intactos (preexistentes):** xorg-server, sddm, vim, fastfetch, firefox,
  gparted, micro, mpv, btop, alsa-utils, pavucontrol, network-manager-applet,
  breeze, breeze-gtk, imagemagick, adwaita-icon-theme, graphicsmagick, libadwaita,
  python-anyio, zbar, gnome-firmware, python-httpx2, flatpak.
- `~/wallpapers/wallhaven/` (wallpaper del usuario) conservado; `/usr/local/bin`
  quedó como el original; gtk-3.0 restaurado del backup de la primera instalación
  (mtime original del 15 sep intacto).

### 14. [FUNCIONAL] 04 — lista de remoción estática poco fiable
- **Problema:** la lista hardcodeada mezclaba paquetes que el instalador no
  instaló (deps KDE de la base) y paquetes que sí instaló pero que el usuario
  ya usa en otra cosa → rompía la transacción de `pacman -Rns` o quitaba
  paquetes ajenos.
- **Fix:** `build_removal_list()` lee `~/.wm-installer-packages-new` (snapshot
  antes/después que registra el instalador) y solo usa la lista estática en
  instalaciones legacy. Los huérfanos se limpian por **diff antes/después**
  (no se tocan huérfanos preexistentes del usuario).
- **Fixes asociados del mismo run:** `restore_backup()` restaura EXACTO
  (`rm` + `cp -a`, no merge) y los paths restaurados nunca se borran
  (`RESTORED_PATHS`/`is_restored`); `remove_flatpak()` solo actúa si flatpak fue
  instalado por el script; `~/wallpapers` se limpia por archivo (no el directorio
  entero); dry-run con `pacman -Rp` real que anticipa conflictos; nombres legacy
  `claudito`/`claudeito` en clones y wallpapers; guard de `whoami` (no root).

### 15. [FUNCIONAL] 04 — paths de sistema no visibles como usuario quedaban atrás (hallado en el test real)
- **Problema:** `/etc/sudoers.d` es `drwxr-x--- root:root`: el chequeo de
  existencia `[[ -e $f ]]` corriendo como usuario devuelve falso (EACCES en el
  stat) aunque el archivo exista, y el `sudo rm` nunca se ejecuta →
  `/etc/sudoers.d/waylandenv` quedó detrás de la desinstalación real.
- **Fix:** `remove_files()` detecta la existencia de paths de sistema (fuera de
  `$HOME`) con `sudo test -e`; los paths de usuario mantienen el chequeo normal.
- **Verificado:** en el test el archivo quedó; con el fix el chequeo sí lo ve
  (el resto manual se limpió a mano en la máquina).

### 16. [MENOR] 04 — `~/.cache/go-build` no estaba en la lista (hallado en el test real)
- **Problema:** al compilar `yay` (AUR helper escrito en Go) se crea
  `~/.cache/go-build`; no estaba en el array `FILES` y quedó detrás.
- **Fix:** agregado `"$HOME/.cache/go-build"` a `FILES`.
- **Verificado:** resto manual limpiado a mano en la máquina; en runs futuros
  queda cubierto.

### 17. [BLOQUEANTE] 02/03 — `ly` no compila: zig 0.16.0 no cumple el mínimo 0.17.0 (test forky)
- **Problema:** el bloque `ly` (02-trixie y 03-forky) descargaba
  `zig 0.16.0` y hacía `git clone` de `master` de `codeberg.org/fairyglade/ly`
  (sin pin de versión). `ly` (v1.5.0 y master 1.6.0) requiere
  **zig 0.17.x** (`minimum_zig_version = "0.17.0"` en `build.zig.zon`), así que
  `zig build` falla con errores de compilación del propio build runner
  (`invalid builtin function: '@backingInt'`, `no field named 'root' in struct
  'Build'`) y el instalador muere ahí (set -e): "no termina de instalar".
  Además, clonar `master` sin pin hace el build no reproducible: cualquier
  bump de versión en el upstream rompe el instalador.
- **Fix (02 y 03):**
  1. zig **0.16.0 → 0.17.0** (único release 0.17.x disponible).
  2. `git clone --depth 1 --branch v1.5.0` (última versión liberada de ly;
     determinista).
  3. `check_error` en `wget`, `git clone`, `zig build` y `zig build installexe`
     (antes un fallo ahí dejaba el set -e sin mensaje).
  4. `sudo rm -rf /opt/zig-x86_64-linux-0.17.0` antes del `tar` (evita mezclar
     un extracto anterior parcial).
- **Verificado (server de desarrollo, 2026-10-24):** zig 0.17.0 + ly v1.5.0 → `zig build`
  rc=0, binario en `zig-out/bin/ly` (29 MB); con zig 0.16.0 el mismo build da
  rc=2 con los errores citados.
- **Test forky (box de pruebas, 2026-10-23): PROBADO EN MÁQUINA REAL, OK.**
  Primera corrida: el fix funcionó (zig 0.17.0 descargado, ly pinneada a
  `bccddcda`) pero `zig build` falló con `unable to unpack git files:
  ReadFailed` en la dep `translate-c` (codeberg): caida transitoria de red que
  deja el cache de zig (~/.cache/zig) parcialmente poblado — reintentar sin
  limpiar el cache falla igual. Retry manual con cache limpia → rc=0, binario
  de 27 MB en ~2 min. Corrida completa (post-uninstall + reclone desde GitHub
  + reinstalación): niri 26.04 + ly 1.5.0 instalados, `ly@tty2.service`
  enabled, 0 errores en el log. El build de ly duró ~28 s gracias al cache de
  compilación tibio (deps + artefactos del retry manual sobrevivieron al
  reboot en /home).
- **Fix 2 (retry, 02 y 03):** `zig build` ahora corre hasta 3 intentos; a cada
  fallo limpia `~/.cache/zig` y reintenta; si los 3 fallan, mensaje claro y
  `exit 1`. Esto convierte el flake de red en un auto-recovery en vez de un
  "el script no termina".

### 18. [MENOR] 05/06 — uninstallers: paths de `ly` errados/incompletos y servicio no deshabilitado
- **Problema:** `installexe` de `ly` (prefix por defecto `/usr`) instala
  `/usr/bin/ly`, `/usr/lib/systemd/system/ly@.service` y
  `ly-kmsconvt@.service`, `/etc/ly/` (config+lang), `/etc/pam.d/ly` y
  `ly-autologin`. Los uninstallers apuntaban a `/usr/local/bin/ly` y
  `/usr/local/lib/systemd/system/ly@.service` (prefix `/usr/local`, que el
  instalador nunca usa) → el uninstall dejaba el ejecutable, las units, el
  config y el pam detrás; el `systemctl enable --force ly@tty2` del instalador
  tampoco se deshacía.
- **Fix (05 y 06):** lista `FILES` corregida/aumentada (ambos prefixes zig
  0.16/0.17, ambos prefixes de binario/unit, `ly-kmsconvt@.service`,
  `/etc/ly`, `/etc/pam.d/ly*`) + `systemctl disable ly@tty2.service` antes de
  borrar las units.
- **Verificado:** `bash -n` OK; se confirmará con un uninstall real en la box
  forky tras el test del instalador.

## Fix 19 — nwg-displays sin soporte para niri → reemplazo por wdisplays (2026-10-23)

**Síntoma:** el ítem "Displays Settings" del menú (quickshell niri-bar) no
abría nada al clickear.
**Causa:** `nwg-displays` (0.3.28) solo soporta sway y Hyprland; en niri
termina con `[Error] Neither sway nor Hyprland detected, terminating` y no
muestra GUI.
**Fix:** reemplazar `nwg-displays` por `wdisplays` en los 6 scripts
(instalación 01/02/03 y desinstalación 04/05/06).
- `wdisplays` usa el protocolo `wlr-output-management-unstable-v1`; los que lo
  implementan conocidos son Sway, Wayfire, Hyprland y **niri** (niri lo añadió
  en el commit `43df7fad`, 2024-05-21 → cualquier niri moderno, incl. el 26.04
  de la box, lo soporta).
- Disponibilidad: Arch `extra` 1.1.3-2, trixie main 1.1.1-1+b2, forky main
  1.1.3-1. (No está en AUR; sí `wdisplays-git`.)
- En trixie va en `pkgs_wm_wayland_backports`, que se instala con
  `apt install -y` normal (sin `-t trixie-backports`), así que no hay conflicto
  de repositorio.
- **Verificado en la box de pruebas (niri 26.04):** con
  `setsid wdisplays` en la sesión niri el proceso queda VIVO (GUI abierta),
  a diferencia de nwg-displays que terminaba al instante.
- En la box se removió nwg-displays y se instaló wdisplays manualmente.

## Fix 20 — mango/scenefx sin compilador C: "Unknown compiler(s)" en meson (2026-10-24)

**Síntoma:** en la box forky (genmachine-test, instalación de los 4 WMs) el
instalador abortaba en el primer WM compilable (mango) con:
`meson.build:1:0: ERROR: Unknown compiler(s): [['cc'], ['gcc'], ['clang'], ...]`
(`Error: No se pudo compilar scenefx (meson build).`).
**Causa:** `pkgs_mango_niri` no instalaba ningún compilador C. `build-essential`
solo se instala en la fase de DM (ly), que corre DESPUÉS de los WMs; y los
otros WMs (hyprland/sway/niri) no se compilan (van de .deb/apt), así que el
compilador nunca existía cuando meson necesitaba `cc`.
**Fix:** agregar `build-essential` a `pkgs_mango_niri` (03-install-forky.sh) —
el arreglo lo comparten los caminos mango y niri.
- **Verificado en la box:** todos los módulos pkg-config requeridos por
  scenefx 0.5.0 (wayland-server, wlroots-0.20, libdrm, xkbcommon, pixman-1) y
  mango 0.17.5 (xcb, xcb-icccm, xcb-randr, libinput, wayland-client,
  libpcre2-8, libcjson, pangocairo) ya estaban OK; el único faltante era el
  compilador. `scenefx-0.5` queda FALTA hasta que se compila scenefx (esperado).
