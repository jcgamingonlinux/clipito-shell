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

**Síntoma:** en la box forky (máquina de test, instalación de los 4 WMs) el
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

## Fix 21 — network-manager-applet arrastra cinnamon + lightdm (2026-10-24)

**Síntoma:** box forky (máquina de test) con los 4 WMs instalados: el boot
mostraba el greeter de lightdm (slick) en vez de ly@tty2, y el sistema tenía
todo el escritorio Cinnamon (16+ paquetes) instalado.
**Causa:** `network-manager-applet` (en la lista base de 01/02/03) depende de
`policykit-1-gnome | polkit-1-auth-agent` (alternativa de paquete virtual). En
forky `policykit-1-gnome` NO existe y el único proveedor de
`polkit-1-auth-agent` es **cinnamon** → apt lo arrastra completo y lightdm se
auto-activa (roba el default a ly). Verificado con `aptitude why`:
`network-manager-applet Depende policykit-1-gnome | polkit-1-auth-agent` /
`cinnamon Proporciona polkit-1-auth-agent`. Era un Depends:
`--no-install-recommends` no lo evitaba.
**Fix:** `network-manager-applet` fuera de las listas de 01/02/03 (se queda
solo en 04/05/06 para limpiar instalaciones viejas). En los WMs de clipito no
hay tray host que lo muestre; la red se maneja con nmtui. El applet sigue
usándose en los autostart de mango/hypr (`nm-applet >/dev/null 2>&1 &`), que
es un no-op inofensivo si no está instalado.
**Bonus:** conflicto de binds en los configs de mango (warning al arrancar):
`XF86AudioPlay` y `XF86AudioPause` suelen ser el mismo keycode → línea
XF86AudioPause comentada en `.config/{arch,debian}-dotfiles/mango/config.conf`.

## Nota — mango "no inicia": no era el compositor (2026-10-24)

Prueba en la box: `runuser -u test -- mango` desde una TTY real (con ACL de
logind sobre /dev/dri) → mango corre y el bar de quickshell arranca (se ve el
JSON de workspaces en el log). El fallo que se veía
(`failed to open /dev/dri/renderD128: Permission denied` → `couldn't create
renderer`) ocurre al probar mango SIN sesión de seat (SSH o desde el greeter
X de lightdm): el nodo render es `root:render 660` y la ACL la pone logind
solo para el usuario de la sesión activa. Desde ly@tty2 (sesión real) mango
inicia bien.

## Fix 22 — blueman (UI de bluetooth) + mask de DMs ajenos al elegido (2026-10-24)

**Síntoma 1 (bluetooth):** en la box (máquina de test) el panel de Bluetooth
del bar de niri mostraba "Encendido" pero "Buscar dispositivos" no encontraba
nada. Verificación: el stack funciona (hci0 UP, Powered: yes, firmware
Realtek RTL8852BE OK; un `bluetoothctl scan on` detectó la balanza Xiaomi
S400 que había cerca). El panel no la encontró porque el scan del panel es
corto (~8s) y la balanza solo hace advertise intermitente. Sin embargo el
sistema no tenía manager completo para emparejar/colocar dispositivos
(GUI: solo el widget del bar).
**Fix:** `blueman` agregado a `pkgs_base` en 01/02/03 (en forky arrastra
solo python3-gi-cairo; en Arch es extra). Queda en 04/05/06 para desinstalar.

**Síntoma 2 (DM):** tras reboot, la box mostraba el greeter de GDM en tty1
aunque `ly@tty2` estaba enabled y gdm "disabled". La imagen base de GenMachines
viene con GNOME completo (gnome-shell, gdm3, etc.): gdm arranca al boot vía
graphical.target sin importar el enablement; el `systemctl disable` que hacía
el instalador no bastaba.
**Fix:** la fase de DM ahora hace `systemctl mask` de gdm/gdm3/lightdm/sddm
(no-elegidos) y `unmask` del elegido (01/02/03). En la box ya quedó aplicado
a mano: gdm+gdm3 masked, ly@tty2 es el único DM.

## Nota — nautilus (GNOME Files) redundante con thunar (2026-10-24)

La box (imagen GenMachines con GNOME de base) traía **nautilus 51** además de
thunar: dos "gestores de archivos" en el menú de apps. Nautilus era auto
(traído por el stack GNOME de la imagen: gnome-sushi, gnome-flashback,
xdg-desktop-portal-gnome, papers) — NINGÚN paquete de los instaladores lo
arrastra (verificado con `apt-cache showpkg nautilus` → reverse-deps son solo
paquetes GNOME), así que en una instalación limpia no aparece.
Fix en la box: `apt-get remove nautilus` (sacó nautilus + gnome-sushi +
gnome-flashback + xdg-desktop-portal-gnome, todos del stack de la imagen).
Thunar queda como único file manager. El icono del menú se refresca
reiniciando `qs` (el bar cachea la lista de .desktop al arrancar) o con el
próximo login. Si alguna vez se arma la bench desde imagen GNOME, repetir.

## Fix 23 — cinnamon arrastrado por virtuales de polkit/notification (2026-10-24)

**Síntoma:** en la box (forky) aparecieron en el menú de login las sesiones de
cinnamon/cinnamon2d/cinnamon-wayland y la app "Backgrounds" (gnome-backgrounds)
aunque el instalador no instala cinnamon.
**Causa:** dos cadenas de virtuales (verificado contra el Packages de forky):
- `blueman` → `Depends: notification-daemon` (virtual). Providers: el paquete
  real `notification-daemon` (3.20.0-5) **o** `cinnamon`. apt eligió cinnamon
  en la corrida de las 00:59 (no es determinista).
- `thunar` → `Recommends: policykit-1-gnome | polkit-1-auth-agent`. En forky no
  existe `policykit-1-gnome`; providers del virtual: cinnamon, gnome-shell,
  xfce-polkit, etc. apt eligió cinnamon.
Cinnamon arrastra muffin+nemo+lightdm (auto) + gnome-backgrounds → 2 "extras"
en el menú (sesiones cinnamon + app Backgrounds que no funciona fuera de
cinnamon).
**Fix:** fijar los providers reales ligeros:
- `notification-daemon` (paquete real) en `pkgs_base` de 02/03.
- `xfce-polkit` en `pkgs_wm_wayland` de 03 (02 ya traía `lxpolkit`, su
  equivalente en trixie).
- Desinstaladores 05/06: `notification-daemon` (+ `xfce-polkit` en 06).
- Arch (01/04): sin cambio — pacman no tiene esos virtuales (verificado: deps
  de blueman/thunar son concretas).
En la box se limpió a mano: `apt remove cinnamon` (0 paquetes extra salieron) +
`autoremove` (gnome-backgrounds, tint2, etc.) + `apt remove lightdm`. Quedan
solo las sesiones de mango y niri; `ly@.service` enabled.

## Fix 24 — Popup de red de quickshell sin WiFi (2026-10-24)

**Síntoma:** el applet de red de la barra solo mostraba "IP local"
(NetworkPopup.qml de 190×100 px, `keyboardFocus: None` en la ventana): no
había forma de ver/conectar redes WiFi ni cambiar de conexión.
**Causa:** dos cosas faltaban:
1. **No existía NetworkManager**: los instaladores no instalaban ningún
   gestor de red (en la box la ethernet la manejaba ifupdown/dhcpcd y el
   WiFi no tenía gestión). `network-manager-applet` estaba fuera de las
   listas desde el fix 23 (arrastra el virtual `policykit-1-gnome |
   polkit-1-auth-agent` → cinnamon en forky).
2. **El popup no tenía UI de WiFi**: solo corrió `ip -4 -o addr` y no
   recibía teclado (ventana `WlrLayershell.keyboardFocus: None`).
**Fix:**
- **`network-manager` (SOLO core, sin applet)** en `pkgs_base` de 01
  (`networkmanager` en arch) y 03 (forky). El core no tiene deps de
  virtuales (verificado en forky: `libnm0, dbus, ...`; `wpasupplicant`
  llega por Recommends). 02-trixie ya traía `network-manager-gnome`
  (core+applet+editor) en `pkgs_wm_wayland`: OK porque en la MISMA
  transacción apt resuelve el virtual polkit con `lxpolkit` (que ya está
  en la lista), no con cinnamon.
- **NetworkPopup.qml reescrito** (las 4 barras: niri/mango/hyprland/sway,
  340×560 px):
  - Conexión actual: WiFi (SSID) y/o LAN (nombre de conexión) vía
    `nmcli dev status`; fallback a /sys/class/net si no hay NM (como el
    indicador).
  - Lista de redes WiFi: `nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list`
    (señal + candado; ocultas se tipean a mano).
  - Conectar (con contraseña si hace falta: `nmcli dev wifi connect
    SSID password PASS`), desconectar (`nmcli dev disconnect DEV`),
    ON/OFF del radio (`nmcli radio wifi`), estado ✓/✗ de la última acción.
  - `keyboardFocus: Exclusive` en la ventana contenedora (igual que el
    launcher) para que el TextField reciba teclas; Escape cierra/cancela.
  - Auto-refresco cada 15 s mientras está abierto.
- **Uninstallers**: 04 agrega `networkmanager`; 05 agrega
  `network-manager` + `nm-connection-editor`; 06 agrega `network-manager`.
- **Guards de dhcpcd** en 01/02/03: si existe el unit `dhcpcd` se
  desactiva al instalar el pack base (evita doble cliente DHCP cuando NM
  toma la red).
**Verificado en una máquina real (forky, niri):** `apt install
network-manager` → NM active, `wpa_supplicant` active, `nmcli dev wifi
list` ve una red WiFi real como usuario normal (D-Bus OK sin
polkit interactivo). La ethernet quedó `unmanaged` en NM: no pelea con
ifupdown/dhcpcd y la conexión SSH no se toca.
**NOTA:** en esa máquina, dhcpcd NO es unit de systemd (lo levanta
ifupdown desde /etc/network/interfaces), por eso los guards no lo tocan
ahí; en imágenes limpias donde SÍ sea unit, el guard lo desactiva.

## Fix 25 — Popup de red: LAN `unmanaged` no aparecía + SSIDs en blanco (2026-10-24)

**Síntoma:** con LAN cableada activa, el popup decía "Sin conexión" y la
lista de WiFi no mostraba nombres (filas vacías).
**Causa:** dos bugs distintos en el NetworkPopup del fix 24:
1. **LAN `unmanaged`:** cuando NM está instalado pero deja la ethernet
   `unmanaged` (la maneja ifupdown/dhcpcd), `nmcli dev status` la reporta
   como `unmanaged` (no `connected`) → el estado LAN del popup quedaba
   vacío. El fallback a /sys/class/net solo corría cuando NO había NM.
2. **Delegate del ListView:** el modelo es un array JS (`property var
   wifiList: []`), no un ListModel. El delegate usaba `model.ssid`/`model.signal`/`model.sec`,
   que en un array JS resuelven a `undefined` (lo correcto es `modelData.*`) →
   los Text de SSID/señal se pintaban vacíos.
**Fix (las 4 barras):**
- `statusScript`: además de `nmcli dev status`, SIEMPRE lee el operstate
  de /sys/class/net (excl. lo) y emite `FBDEV:<dev>:wifi|eth` para cada
  interfaz `up`. El QML deduplica: una FBDEV solo cuenta si NM no la
  reporta como `connected`.
- `currentStatusText()`/`anyConnected()`: ahora muestran/cuentan la LAN
  no gestionada por NM (vía /sys) como `LAN: <dev>`, no solo las
  conexiones que NM dice `connected`.
- Delegate: `model.ssid` → `modelData.ssid` (y señal/securidad).
**Verificado:** con LAN cableada activa y NM marcándola `unmanaged`, el
popup muestra "LAN: <interfaz>" y la lista de WiFi con SSIDs/señal/candado.

## Fix 26 — ly como .deb precompilado en release/debian/ (2026-10-24)

**Síntoma:** el instalador compilaba `ly` (TUI display manager, tty2) de
fuente en cada instalación: descarga de zig 0.17.0, `git clone` v1.5.0 y
`zig build` que fetchea dependencias git — lento y con puntos de falla de
red (fallo transitorio de codeberg → 3 reintentos con cache limpia; gate
`minimum_zig_version=0.17.0` que rompía el zig 0.16 del repositorio).
**Fix:**
- `ly_1.5.0-1_amd64.deb` en `release/debian/`: binario `/usr/bin/ly` +
  unit template `ly@.service` + postinst (`systemctl enable --force
  ly@tty2` + restart) + postrm (disable/stop; purge limpia el symlink de
  enable). `Depends` calculado desde `ldd`: solo libs básicas de Debian
  (libpam0g, libxcb1, libaudit1, libxau6, libxdmcp6, libcap-ng0,
  util-linux, xauth) — **sin wlroots**, así que UN SOLO .deb sirve para
  trixie y forky (el binario pide como máximo GLIBC_2.36; verificado con
  `objdump -T` sobre forky/glibc 2.43).
- 02 y 03: el bloque `ly)` ahora hace `apt install ./ly_1.5.0-1_amd64.deb`
  desde `release/debian/` (sin zig/clone/build).
- 05 y 06: `ly` agregado al array de paquetes a purgar (antes solo se
  borraban archivos sueltos + deps de compilación, que siguen en la lista
  por los instaladores viejos).
**Verificado:** en una máquina de test (forky) se desinstaló la copia
manual (binario + unit + enable), se instaló el .deb con `apt install` y
quedó `ly 1.5.0-1` instalado, `ly@tty2` enabled+active con el proceso
corriendo en tty2.

## Fix 27 — ly .deb incompleto: faltaba todo /etc/ly (2026-10-25)

**Síntoma:** tras reinstalar la box con el instalador del fix 26, `ly`
autenticaba bien en tty2 pero no lanzaba la sesión: el log
(`/var/log/ly.log`) mostraba `executing: /bin/bash -c /etc/ly/setup.sh
niri-session` y un segundo después `logged out`. `/etc/ly/` estaba vacío
y no existían `/etc/pam.d/ly`.
**Causa:** el .deb 1.5.0-1 solo empaquetaba `/usr/bin/ly` +
`ly@.service`. Al desinstalar la copia manual (build de fuente) se
llevaron todos los archivos de config que `zig build installexe`
instala, y el .deb no los re-ponía: `ly` cargaba el config embebido por
default (que apunta a `/etc/ly/setup.sh`, etc.) y el comando de setup
desaparecía al instante (script inexistente).
**Fix:** `ly_1.5.0-2_amd64.deb` en `release/debian/` (reemplaza a
1.5.0-1) con el set completo replicando `installexe`:
`/usr/bin/ly`, `ly@.service` + `ly-kmsconvt@.service` (patcheados),
`/etc/ly/` completo (`setup.sh` 755, `config.ini` + `config.ini.example`
patcheados, `startup.sh` 755, `example.dur`/`example.lua` 755,
`custom-sessions/README`, `lang/` con los 25 idiomas) y `/etc/pam.d/ly`
+ `ly-autologin`. Los placeholders `$CONFIG_DIRECTORY`/`$PREFIX_DIRECTORY`/
`$EXECUTABLE_NAME` reemplazados a mano como hace el instalador de ly
(`/etc`, `/usr`, `ly`).
- 02 y 03: `apt install ./ly_1.5.0-2_amd64.deb`.
**Verificado:** en la box forky, `apt install` de 1.5.0-2 sobre 1.5.0-1:
`/etc/ly/` completo, `bash -n setup.sh` OK, config.ini con
`setup_cmd = /etc/ly/setup.sh`, `ly@tty2` activo (el log de TUI carga
sin errores; el `x11 session directory FileNotFound` es inofensivo,
config solo-Wayland).

## Fix 28 — Popup de red: botones Conectar/Cancelar fuera del recuadro (2026-10-25)

**Síntoma:** en el panel de contraseña de WiFi, los botones "Conectar" y
"Cancelar" se desbordaban ~16px por debajo del borde del recuadro
(confirmado en captura de la box: niri, popup abierto, red "Angel").
**Causa:** el `Rectangle` del panel usaba
`implicitHeight: pwCol.implicitHeight`, pero el `ColumnLayout` interior
(`pwCol`) tiene `anchors.margins: Scaling.px(8)`. El `implicitHeight` del
layout es la altura natural del contenido (sin márgenes), así que el
Rectangle quedaba 16px más chico que su contenido (8 arriba + 8 abajo) y
la última fila (los botones) salía del recuadro.
**Fix:** `implicitHeight: pwCol.implicitHeight + 2 * Scaling.px(8)`
(suma los márgenes). Así el Rectangle cubre contenido+márgenes y los
botones quedan dentro, con 8px de respiro inferior.
- De paso: se quitó el `onAccepted` duplicado del `pwField` (Enter ya
  dispara `Keys.onReturnPressed`; los dos handlers re-lanzaban `connProc`).
- Aplicado a las 4 barras (niri/mango/hyprland/sway) — QML idénticos
  (md5 9fb9f9e6703cb70316179ed306f17356).
**Verificado:** en forky, con el popup abierto y el panel de contraseña
visible, los botones quedan dentro del recuadro.

## Fix 29 — Popup/indicador Bluetooth: `adapter.devices` no es array JS (2026-10-25)

**Síntoma:** el indicador BT de la barra tiraba
`TypeError: Property 'filter' of object UntypedObjectModel is not a
function` y el hint "Sin dispositivos emparejados..." del popup nunca
aparecía.
**Causa:** en quickshell 0.3.2, `adapter.devices` es un
`UntypedObjectModel` (QAbstractListModel), no un array JS. El array JS
está en `.values` (QObjectList). `.filter()` y `.length` no existen en
el modelo. (Verificado contra
`/usr/lib/x86_64-linux-gnu/qt6/qml/Quickshell/Bluetooth/quickshell-bluetooth.qmltypes`.)
**Fix:** `adapter.devices.filter(...)` → `adapter.devices.values.filter(...)`
(BTIndicator, las 4 barras) y `adapter.devices.length === 0` →
`adapter.devices.values.length === 0` (BTPopup, las 4 barras). La línea
`model: root.available ? root.adapter.devices : []` del ListView queda
como estaba: un `QAbstractListModel` es un modelo válido para `model`.
**Verificado:** tras re-lanzar `qs`, el TypeError desapareció del log y
el hint aparece en el popup (captura).

## Fix 30 — Scan del popup BT: la discovery se detenía sola (2026-10-25)

**Síntoma:** el botón "Buscar dispositivos (8s)" no encontraba nada,
incluso con el dispositivo en modo descubrible; blueman sí los veía.
**Causa:** en BlueZ >= 5.66 la discovery es "propiedad" del cliente
D-Bus que la inició: cuando ese cliente se desconecta,
`btd_adapter_discovery_disconnect()` detiene el escaneo (verificado en
`src/adapter.c` de bluez 5.87, líneas 2471/2552/2877). El comando del
popup era `timeout 8 bluetoothctl scan on`: `bluetoothctl` en forma de
argumentos **sale enseguida** si stdin no es TTY (EOF inmediato), así
que la discovery empezaba y moría en el mismo instante. Confirmando:
log `--debug` de bluetoothd muestra
`start_discovery() → trigger_start_discovery() → discovery_disconnect()
owner :1.852` en el mismo segundo; y `bluetoothctl show` daba
`Discovering: no` durante todo el "scan".
**Fix:** comando por stdin con pipe vivo:
`sh -c "(printf 'scan on\n'; sleep 8) | bluetoothctl >/dev/null 2>&1"`
— bluetoothctl envía el comando y se queda 8s vivo como owner; al
cerrar el pipe sale y BlueZ detiene el scan solo. Los dispositivos
encontrados aparecen solos en `adapter.devices` (el modelo escucha los
cambios de BlueZ). Aplicado a las 4 barras (QML idénticos).
**Verificado:** con el comando nuevo, `busctl get-property ...
Discovering` da `b true` durante los 8s y bluetoothctl imprime
`Discovery started`.
**Nota:** también se descartó un problema de hardware/servicio: dongle
Realtek RTL8852BU (1-3), reset por unbind/bind y HCI reset; el error
`adv_monitor ... Unexpected NULL` del journal es cosmético (el Adv
Monitor Manager se saltea por "LE unavailable" al arrancar y no se
reintenta), no afectaba a la discovery.

## Fix 31 — Popups: "ventana gigante transparente" al abrir (mango-bar, 2026-10-25)

**Síntoma (video de JC):** al abrir el launcher (y el resto de popups),
parecía que se abría una "ventana gigante transparente con sombra" que
permanecía un segundo y luego desaparecía; además el contenido tardaba
~570 ms en pintarse tras el click.
**Diagnóstico:** PPM burst a ~43 fps + frames del video a 30 fps:
- NO hay overlay a pantalla completa: una zona lejana a la tarjeta no
cambia de brillo en ningún frame (mean ≈ 62 constante) → la PanelWindow
full-screen transparente de Quickshell no es la culpable en sí.
- La tarjeta (LauncherPopup 420×952) se pinta con **fade-in** (~66→111 de
brillo en la zona de la tarjeta entre frames) y llega desplazada por un
**slide** — ambas impuestas por **MangoWM**, no por el QML: la config
traía `layer_animations=1` + `layer_animation_type_open=slide`
(duración `animation_duration_open=400`) + `layer_shadows=1`
(`shadows_size=12`, `shadows_blur=15`). El compositor anima/sombrea la
superficie layer-shell como si fuera una ventana normal, y mientras el
QML aún no pinta el contenido se ve la superficie transparente + la
sombra → "ventana gigante transparente con sombra".
**Fix:** en `~/.config/mango/config.conf` (y en
`arch-dotfiles/mango/config.conf` del repo):
- `layer_shadows = 0` (antes `1`) — sin sombra en superficies layer-shell.
- `layer_animations=0` (antes `1`) — sin slide/fade de apertura/cierre
de layers; la tarjeta aparece completa e instantánea.
Las líneas `layer_animation_type_open/close` quedan sin efecto (inofensivas).
Las animaciones de ventanas normales (`animations=1`) no se tocan: solo se
apaga lo que aplica a layer-shell.
**Verificado:** aplicado en la box (backup
`config.conf.bak-20261025-layeranim`; `mango -p` sin errores); el mango
actual arrancó con la config nueva tras un reboot espontáneo de la box.
JC confirmó: "desapareció la sombra y el delay".

## Fix 32 — Paridad arch-dotfiles vs debian-dotfiles (2026-10-25)

**Motivo:** pedido de JC tras el fix de mango ("fijate si no hay arreglos que esten en arch y no en debian"). Auditoría completa: `diff -rq` entre `arch-dotfiles/` y `debian-dotfiles/` + git log de cada archivo con diferencias.

**Resultado:** ningún fix 24-31 quedó afuera de debian (los fixes viven en `.config/quickshell/`, una sola tree compartida, y en los instaladores 01/02/03 que ya distinguen por-OS). El único fix en dotfiles por-OS era el mango (Fix 31), ya aplicado en las dos copias.

**Diferencias viejas (de los dotfiles originales) que sí eran "está en arch y no en debian" → sincronizadas:**

1. **`hypr/hyprland.lua` — polkit agent:** en Arch se arrancaba el agent al iniciar hypr (`polkit-gnome-authentication-agent-1`); en Debian estaba comentado (`-- hl.exec_cmd("lxpolkit")`). Ahora en debian arranca el agent que el instalador realmente instala (trixie: `lxpolkit`, forky: `xfce-polkit`), con una línea que prueba ambos para que el ausente falle en silencio. En Arch no se tocó: el instalador 01 ni instala `polkit-gnome`, así que esa línea allá probablemente es un no-op.
2. **`sway/config.d/50-systemd-user.conf` — `XDG_CURRENT_DESKTOP=sway`:** la versión de Arch lo setea explícito en el env de systemd user (workaround FS#63021 + `set-environment` + `dbus-update-activation-environment`); la de Debian era la simplificada (solo `import-environment`). Quedó sincronizada a la versión completa.

**Lo que queda distinto (intencional, no es fix faltante):**

- Solo en debian: stub `hypr/hyprland.conf` (lo necesita hyprland) y variantes viejas de niri (`01-config.kdl`, `config-arch/`, `config-sid/`) — inofensivas: niri solo lee el `config.kdl` de arriba, que es **idéntico** en ambos árboles.
- `sway/config`: en debian hay un `exec lxpolkit &` que en arch no existe (dirección contraria; en forky ese binario no existe, es no-op). No tocado por no ampliar el alcance.

## Fix 33 — Pase de calidad completo (QA con subagente GUI/diseño/código, 2026-10-27)

**Motivo:** pedido de JC ("hace un pase de calidad con un subagente experto en interfaz
gráfica, diseño, programación"). Subagente con contexto limpio hizo review estática de
las 4 barras (~34k líneas QML), scripts 01-06, `usr/` y `release/debian/`. Sin máquina
de testeo (la box no respondía en la LAN).

**Verificado contra el código (todo confirmado; el subagente no inventó nada):**

### P0
- **NetworkPopup (x4): mensaje de radio invertido.** `nmcli radio wifi on/off` no
  escribe nada en stdout; el mensaje se decidía con `t.indexOf("enabled") >= 0` sobre
  un stdout vacío → SIEMPRE mostraba "✓ Wi-Fi apagado" (incluso al activarlo).
  Fix: nueva prop `lastRadioOn` que guarda la intención en `toggleRadio()`; el mensaje
  se decide por la intención. El estado real se pinta igual (refreshAll relee).

### Deriva entre barras
- **KeybindsPopup (hyprland + mango):** `radius: 8` / `border.width: 1` hardcoded
  (sway/niri ya usaban `Scaling.px`). Escalado en ambos.

### P1
- **NotificationCenterPopup (x4):** no cerraba con Escape (era el único popup con
  `focus: true` que no lo tenía). Fix: `Keys.onEscapePressed: Bridge.notificationsOpen = false`.
- **evince:** 01 (arch) y 02 (trixie) lo instalan, 03 (forky) no. Fix: agregado a
  `pkgs_extra_intermedio` de 03 + a la lista de 06-uninstall. 05-uninstall ya lo traía.
- **05-uninstall-trixie:** faltaban `pipewire-bin libpipewire-0.3-0t64
  libpipewire-0.3-modules gir1.2-atk-1.0 libatk1.0-0t64` (02 los instala vía
  backports fuera del array). Agregados a la lista.
- **06-uninstall-forky:** traía `pcmanfm` (ya no se instala desde 2026-10-24). Quitado.

### P2 (QoL/diseño)
- **Píxeles sin escalar** (hallazgos del subagente + 3 más que el grep amplio sacó):
  - CalendarPopup (x4): `columnSpacing/rowSpacing: 4` → `Scaling.px(4)`
  - LauncherPopup (x4): altas de delegate `28:40` → `Scaling.px(28)/px(40)`
  - WallpaperPicker (x4): 7 bordes/márgenes (1/2/3) → `Scaling.px`
  - NetworkPopup (x4): `spacing: 1` (linea 401) → `Scaling.px(1)`
  - BarConfigPopup (x4): `border.width: 1` (linea 12) → `Scaling.px(1)`
  (los `spacing: 0` se dejan: cero no escala)
- **ConfirmActionPopup (x4):** sin cierre por teclado en una acción destructiva.
  Fix: `focus: true` + `Keys.onEscapePressed: PendingAction.cancel()` +
  `Keys.onEnterPressed: PendingAction.executeNow()`.

### OK (lo que el pase verificó y está bien)
- Sin fugas de timers: los `running: true` persistentes son polling intencional;
  los popups son PanelWindow siempre-instanciados (los Process no se acumulan).
- WallpaperPicker (1104 lineas) sólido: guardas de lista vacía, clamp de índice,
  timeout/429/error en XHR, contador de generación, cache, descarga atómica,
  resize que nunca agranda, fallback curl→wget.
- Navegación por teclado en WallpaperPicker completa; WindowList/ActiveWindow
  manejan campos nulos con fallback.
- Scripts: `set -euo pipefail`, detección por os-release, backups de dotfiles,
  04-uninstall-arch maneja huérfanos con `pacman -Qdtq` (no le falta nada).

### Nuevo: `check-bars.sh` (raiz del repo)
Chequeo pre-release con 2 partes:
1. **Deriva entre barras:** todo archivo que difiera (o exista solo en una barra)
   fuera del allowlist documentado → falla. El allowlist (19 archivos por-WS:
   snippets de config, scripts de helper, modulos con IPC especifico, shell.qml)
   es la lista canónica de "que puede diferir y por que".
2. **Píxeles sin escalar:** grep de literales no nulos en `radius/border.width/
   *Spacing/anchors.margins` sin `Scaling.px` en los modulos de las 4 barras.
Uso: `bash check-bars.sh` (exit 1 = hallazgos). Correrlo antes de cada release.

### Queda para un futuro (no se hace ahora)
- **Directorio `shared/` + qmldir:** popups byte-idénticos (Network, Bluetooth,
  Clock, etc.) viven una sola vez e importados por las 4 barras. Evita que una
  deriva sea posible (la de KeybindsPopup ya se repitió). Refactor grande.
- **Popup base reutilizable** (focus + Escape + geometria/colores estandar):
  unifica el contrato de teclado y la consistencia visual.
- **Foco visible en el boton por defecto** de ConfirmActionPopup (hoy Enter
  acepta sin feedback visual de que el boton "Aceptar ahora" es el default).
- **Versiones de `release/debian/*.deb`:** ly/niri/mango/xwayland-satellite son
  paquetes de terceros; verificar contra los repos cuando la box este de vuelta
  (no bloquea: se instalan solo si faltan).
