#!/usr/bin/env bash
################################################
# Script de DESINSTALACIÓN "Clipito Shell" - Debian 14 (Forky)
#
# Quita todo lo que instaló el script de instalación
# (03-install-forky.sh):
#
#   1. RESTAURA los archivos que existían antes de la instalación
#      (desde el backup que el instalador crea en ~/.config-backup/)
#   2. QUITA los paquetes instalados (apt-get purge + autoremove)
#   3. BORRA dotfiles, fuentes, archivos en /usr, mango/scenefx
#      (compilados), backports, estado, logs y backups
#
# Uso:
#   ./06-uninstall-forky.sh            # interactivo (dialog)
#   ./06-uninstall-forky.sh --force    # sin diálogos (autoconfirmado)
#   ./06-uninstall-forky.sh --dry-run  # solo muestra lo que haría
#   ./06-uninstall-forky.sh --force --dry-run
#
# Importante:
#   Ejecutalo como usuario normal (usa sudo por debajo), no como root.
#
# youtube.com/@LinuxenCasa
# https://github.com/jcgamingonlinux/clipito-shell
# Script de instalación: Gabriel Parri - gabeeOS Linux
# Script de desinstalación: JC Gaming On Linux, asistido por JC IA
################################################

set -euo pipefail

# No ejecutar como root (usa sudo por debajo)
if [ "$(whoami)" == "root" ]; then
    echo "Error: Este script no debe ejecutarse como root. Usa un usuario con permisos sudo."
    exit 1
fi

################################################
# Flags
################################################
FORCE=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --force)   FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            echo "Uso: $0 [--force] [--dry-run]"
            exit 0
            ;;
        *)
            echo "Opción desconocida: $arg (usá --help)"
            exit 1
            ;;
    esac
done

# run "comando": ejecuta el comando (o solo lo muestra si es --dry-run)
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY: $*"
    else
        eval "$@"
    fi
}

# sudo -n primero (no pide nada si hay NOPASSWD); si no, sudo -v interactivo
if ! sudo -n true 2>/dev/null && ! sudo -v; then
    echo "Error: El usuario no tiene permisos sudo o no está configurado."
    exit 1
fi

# Log
LOGFILE="$HOME/uninstall_log.txt"
if [ "$DRY_RUN" -eq 0 ]; then
    exec > >(tee -i "$LOGFILE") 2>&1
fi
echo ">> Iniciando desinstalación... (registro: $LOGFILE)"

################################################
# Paquetes que el script de instalación puede instalar
# (unión de todos los niveles y WCs)
################################################
PKGS=(
    # --- básico ---
    acpi alsa-utils curl gpg desktop-base fastfetch ffmpeg firefox-esr
    gvfs gvfs-backends gvfs-fuse mtp-tools pcmanfm pavucontrol playerctl
    pulseaudio-utils synaptic unrar-free xdg-user-dirs xfce4-screenshooter
    xorg xterm xserver-xorg
    # --- backports (audio + varios) ---
    pipewire pipewire-alsa pipewire-pulse wireplumber gdebi nwg-displays
    # --- intermedio ---
    btm btop htop hunspell-es libreoffice libreoffice-gtk3 libreoffice-gtk4
    libreoffice-l10n-es mousepad mpv nuspell ristretto sayonara transmission
    vim wget
    # --- full ---
    audacity build-essential cava cmatrix devscripts fonts-font-awesome
    fonts-roboto gnumeric gparted inkscape inxi mediainfo neovim sox vlc gimp
    # --- WM (comunes) ---
    adwaita-icon-theme breeze-gtk-theme fonts-noto-color-emoji git imagemagick
    libnotify-bin network-manager-applet nwg-look qt-style-kvantum-themes
    quickshell sound-theme-freedesktop swaylock thunar wlr-randr xwayland
    yad zenity
    # --- niri (debs del repo + deps de compilación) ---
    wayland-protocols hwdata seatd pango1.0-tools meson wayland-utils
    xdg-desktop-portal-gtk niri xwayland-satellite alacritty
    libinput-dev libdrm-dev libxkbcommon-dev libpixman-1-dev libdisplay-info-dev
    libliftoff-dev libwayland-dev libwlroots-0.20-dev libcjson-dev
    librust-pangocairo-dev
    # --- mango (foot; mango y scenefx son compilados, ver remove_files) ---
    foot
    # --- sway ---
    sway sway-backgrounds x11-xserver-utils xdg-desktop-portal-wlr
    # --- hyprland ---
    hyprland hyprland-guiutils kitty xdg-desktop-portal-hyprland
    # --- display managers ---
    lightdm lightdm-gtk-greeter sddm sddm-theme-maui
    # --- ly (compilación) ---
    libpam0g-dev libxcb-xkb-dev xauth brightnessctl
    # --- scrcpy (compilación) ---
    libsdl2-2.0-0 adb gcc pkg-config ninja-build libsdl2-dev libavcodec-dev
    libavdevice-dev libavformat-dev libavutil-dev libswresample-dev libusb-1.0-0
    libusb-1.0-0-dev
    # --- virt-manager ---
    qemu-system virt-manager libvirt-daemon-system virt-viewer
    # --- flatpak ---
    flatpak
    # --- fuentes nerd ---
    unzip fontconfig ca-certificates
    # --- arranque ---
    dialog
)

################################################
# Archivos/directorios que el script crea o sobreescribe
################################################
FILES=(
    "$HOME/.config/gtk-3.0"
    "$HOME/.config/quickshell"
    "$HOME/.config/sway"
    "$HOME/.config/hypr"
    "$HOME/.config/niri"
    "$HOME/.config/kitty"
    "$HOME/.config/alacritty"
    "$HOME/.config/foot"
    "$HOME/wallpapers"
    "$HOME/.local/share/fonts/JetBrainsMonoNerd"
    "$HOME/.local/src/scrcpy"
    "$HOME/.local/bin/scrcpy"
    "$HOME/.wm-installer-state"
    "$HOME/install_log.txt"
    "$HOME/.config-backup"
    "/usr/local/bin/askpass-zenity"
    "/usr/local/bin/gparted-xwl"
    "/usr/local/bin/synaptic-xwl"
    "/usr/local/share/applications/gparted-wayland.desktop"
    "/usr/local/share/applications/synaptic-wayland.desktop"
    "/usr/share/wallpapers/clipito-01.png"
    "/usr/share/wayland-sessions/sway.desktop"
    "/usr/share/wayland-sessions/mango.desktop"
    "/etc/sudoers.d/waylandenv"
    # mango + scenefx (compilados con meson/ninja en /usr)
    "/usr/bin/mango"
    "/tmp/mango"
    "/tmp/scenefx"
    # ly (compilado con zig)
    "/opt/zig-x86_64-linux-0.16.0"
    "/tmp/ly"
    "/usr/local/bin/ly"
    "/usr/local/lib/systemd/system/ly@.service"
    # nerd fonts "todas": workspace de compilación
    "$HOME/.cache/nerd-fonts-build"
    "/var/tmp/nerd-fonts-build"
    "/tmp/nerd-fonts-build"
    # clone del repo por defecto
    "/tmp/clipito-shell"
)

# Contadores para el resumen
FILES_RESTORED=0
PKGS_REMOVED=0
FILES_REMOVED=0

################################################
# 1) Restaurar el backup
# El instalador respalda (en ~/.config-backup/<fecha>/) cada archivo
# que existía ANTES de sobreescribirlo, y lo registra en .manifest.
# Restauramos el backup MÁS ANTIGUO: es el estado de antes de la
# primera instalación (estado original del usuario).
################################################
find_oldest_manifest() {
    local m
    m="$(ls -1d "$HOME"/.config-backup/*/.manifest 2>/dev/null | LC_ALL=C sort | head -n1 || true)"
    echo "$m"
}

restore_backup() {
    local manifest="$1"
    local bdir
    bdir="$(dirname "$manifest")"
    echo ">> Restaurando backup: $bdir"

    local tipo original entrada
    while IFS=$'\t' read -r tipo original entrada; do
        [[ -z "${original:-}" || "${original}" == \#* ]] && continue
        if [[ ! -e "$entrada" ]]; then
            echo "  [saltado] no está el respaldo de: $original"
            continue
        fi
        local cp_cmd="cp -a"
        local mk_cmd="mkdir -p"
        [[ "$original" != "$HOME"* ]] && { cp_cmd="sudo cp -a"; mk_cmd="sudo mkdir -p"; }
        run "$mk_cmd '$(dirname "$original")'"
        if [[ -d "$entrada" ]]; then
            run "$cp_cmd '$entrada/.' '$original/'"
        else
            run "$cp_cmd '$entrada' '$original'"
        fi
        echo "  [restaurado] $original"
        FILES_RESTORED=$(( FILES_RESTORED + 1 ))
    done < "$manifest"
}

################################################
# 2) Paquetes flatpak (antes de purgar flatpak)
################################################
remove_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        return 0
    fi
    echo ">> Quitando apps Flatpak..."
    run "flatpak uninstall --all -y" || echo "  [aviso] no se pudo vaciar flatpak"
    run "flatpak remote-delete flathub" || echo "  [aviso] no se pudo quitar el remoto flathub"
}

################################################
# 3) Quitar paquetes
################################################
remove_packages() {
    local to_purge=()
    local p
    for p in "${PKGS[@]}"; do
        if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok"; then
            to_purge+=("$p")
        fi
    done

    if [[ ${#to_purge[@]} -eq 0 ]]; then
        echo ">> No hay paquetes del script instalados."
        return 0
    fi

    echo ">> Purgando ${#to_purge[@]} paquetes..."
    if [ "$DRY_RUN" -eq 1 ]; then
        printf 'DRY: sudo apt-get purge -y %s\n' "${to_purge[*]}"
    else
        sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y "${to_purge[@]}" \
            || echo "  [aviso] hubo errores al purgar algunos paquetes (ver arriba)."
    fi
    PKGS_REMOVED=${#to_purge[@]}

    echo ">> Quitando paquetes huérfanos (autoremove)..."
    run "sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y" \
        || echo "  [aviso] no se pudo completar el autoremove."
}

################################################
# 4) Repo de backports (solo lo que creó el script)
################################################
remove_backports() {
    local f
    for f in /etc/apt/sources.list.d/forky-backports.list /etc/apt/sources.list.d/forky-backports-2.list; do
        [[ -f "$f" ]] || continue
        if grep -qs "^deb http://deb.debian.org/debian forky-backports main" "$f"; then
            echo "  [rm] $f"
            run "sudo rm -f '$f'"
            FILES_REMOVED=$(( FILES_REMOVED + 1 ))
        else
            echo "  [se queda] $f (no fue creado por el script)"
        fi
    done
}

################################################
# 5) Quitar archivos
################################################
remove_files() {
    local f
    local removed=0
    for f in "${FILES[@]}"; do
        if [[ -e "$f" || -L "$f" ]]; then
            local rm_cmd="rm -rf"
            [[ "$f" != "$HOME"* ]] && rm_cmd="sudo rm -rf"
            echo "  [rm] $f"
            run "$rm_cmd '$f'"
            removed=$(( removed + 1 ))
        fi
    done
    FILES_REMOVED=$(( FILES_REMOVED + removed ))

    # scenefx: librerías instaladas en /usr/lib (mango)
    local sl
    while IFS= read -r sl; do
        [[ -z "$sl" ]] && continue
        echo "  [rm] $sl"
        run "sudo rm -f '$sl'"
        FILES_REMOVED=$(( FILES_REMOVED + 1 ))
    done < <(find /usr/lib -name '*scenefx*' 2>/dev/null)

    # Nerd Fonts "todas": el install.sh oficial las pone en ~/.fonts
    if [ -d "$HOME/.fonts" ]; then
        local nf
        while IFS= read -r nf; do
            [[ -z "$nf" ]] && continue
            echo "  [rm] $nf"
            run "rm -f '$nf'"
            FILES_REMOVED=$(( FILES_REMOVED + 1 ))
        done < <(find "$HOME/.fonts" -maxdepth 1 -name 'Nerd*' 2>/dev/null)
        if [ -z "$(ls -A "$HOME/.fonts" 2>/dev/null)" ]; then
            run "rmdir '$HOME/.fonts'"
        fi
    fi

    # /tmp/clipito-shell: solo si es el clone del repo (tiene .git)
    if [ -d "/tmp/clipito-shell/.git" ]; then
        echo "  [rm] /tmp/clipito-shell"
        run "sudo rm -rf '/tmp/clipito-shell'"
        FILES_REMOVED=$(( FILES_REMOVED + 1 ))
    fi
}

################################################
# 6) Limpieza suelta
################################################
cleanup() {
    # SDDM: si queda configurado el tema maui que recién se fue,
    # lo apunto al tema default para que el login no quede en negro
    if grep -rqs "Current=maui" /etc/sddm.conf /etc/sddm.conf.d 2>/dev/null; then
        echo ">> Ajustando SDDM: el tema 'maui' se fue; uso 'debian-theme'"
        run "sudo sed -i 's/Current=maui/Current=debian-theme/g' /etc/sddm.conf" || true
        run "sudo find /etc/sddm.conf.d -name '*.conf' -exec sed -i 's/Current=maui/Current=debian-theme/g' {} +" || true
    fi

    # virt-manager: el instalador agregaba al usuario al grupo libvirt
    if getent group libvirt >/dev/null 2>&1 && id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx libvirt; then
        echo ">> Sacando a $USER del grupo libvirt"
        run "sudo deluser $USER libvirt" || true
    fi
}

################################################
# main
################################################
main() {
    # diálogos (si no está, lo instalo)
    if [ "$FORCE" -eq 0 ] && ! command -v dialog >/dev/null 2>&1; then
        echo "El paquete 'dialog' no está instalado. Instalando…"
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq dialog || {
            echo "No se pudo instalar 'dialog'. Usá --force para no dialogar."; exit 1;
        }
    fi

    local manifest
    manifest="$(find_oldest_manifest)"
    local will_restore="no"
    [[ -n "$manifest" ]] && will_restore="sí"

    if [ "$FORCE" -eq 0 ]; then
        local msg="Va a desinstalar TODO lo que instaló el script de instalación:"
        msg+=$'\n\n'"1. Restaura los archivos que existían antes de la instalación: $will_restore"
        msg+=$'\n'"2. Quita los paquetes (apt-get purge + autoremove)"
        msg+=$'\n'"3. Borra dotfiles, fuentes, /usr, mango/scenefx, backports, estado, logs y backups"
        msg+=$'\n\n'"Cuando se borre el backup ya no se puede volver."
        if ! dialog --title "Desinstalar Clipito Shell (Forky)" --yesno "$msg" 14 78; then
            echo "Desinstalación cancelada."
            exit 0
        fi
    fi

    if [[ -n "$manifest" ]]; then
        restore_backup "$manifest"
    else
        echo ">> No hay backup en ~/.config-backup (nada que restaurar)."
    fi

    remove_flatpak
    remove_packages
    remove_backports
    remove_files
    cleanup

    local summary="Desinstalación completada:"
    summary+=$'\n\n'"Archivos restaurados: $FILES_RESTORED"
    summary+=$'\n'"Paquetes purgados: $PKGS_REMOVED"
    summary+=$'\n'"Archivos/directorios borrados: $FILES_REMOVED"
    summary+=$'\n'"Log: $LOGFILE"
    echo "$summary"

    if [ "$FORCE" -eq 0 ]; then
        dialog --title "Desinstalación completada" --msgbox "$summary" 12 70 || true
    fi
}

main
