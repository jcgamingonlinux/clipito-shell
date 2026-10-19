#!/usr/bin/env bash
################################################
# Script de DESINSTALACIÓN "Clipito Shell" - Arch Linux
#
# Quita todo lo que instaló el script de instalación
# (01-install-arch.sh):
#
#   1. RESTAURA los archivos que existían antes de la instalación
#      (desde el backup que el instalador crea en ~/.config-backup/)
#   2. QUITA los paquetes instalados (pacman -Rns + huérfanos)
#   3. BORRA dotfiles, fuentes, archivos en /usr/local,
#      estado, logs y backups
#
# Uso:
#   ./04-uninstall-arch.sh            # interactivo (dialog)
#   ./04-uninstall-arch.sh --force    # sin diálogos (autoconfirmado)
#   ./04-uninstall-arch.sh --dry-run  # solo muestra lo que haría
#   ./04-uninstall-arch.sh --force --dry-run
#
# Importante:
#   Ejecutalo como usuario normal (usa sudo por debajo), no como root.
#
# youtube.com/@LinuxenCasa
# https://gitlab.com/linux-en-casa/claudito-shell
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
    acpi alsa-utils base-devel curl fastfetch ffmpeg firefox gvfs mtpfs
    network-manager-applet pavucontrol playerctl thunar unrar-free xdg-user-dirs
    xfce4-screenshooter xorg-server xterm
    pipewire pipewire-alsa pipewire-pulse wireplumber
    # --- intermedio ---
    bottom btop htop hunspell-es_any libreoffice-still libreoffice-still-es
    mousepad mpv nuspell ristretto transmission-qt vim wget evince
    # --- full ---
    audacity cava cmatrix otf-font-awesome ttf-roboto gnumeric gparted inkscape
    inxi mediainfo neovim sox vlc gimp
    # --- WM (comunes) ---
    adwaita-icon-theme breeze breeze-gtk noto-fonts-emoji git imagemagick
    ttf-jetbrains-mono-nerd libnotify kvantum sound-theme-freedesktop swaylock
    wlr-randr yad zenity nwg-displays quickshell
    # --- hyprland ---
    hyprland hyprland-guiutils kitty xorg-xwayland xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    # --- niri ---
    alacritty niri xwayland-satellite
    # --- sway ---
    foot sway swaybg xdg-desktop-portal-wlr
    # --- display managers ---
    lightdm lightdm-gtk-greeter sddm ly
    # --- apps adicionales ---
    yay paru flatpak
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
    "$HOME/.wm-installer-state"
    "$HOME/install_log.txt"
    "$HOME/.config-backup"
    "/usr/local/bin/askpass-zenity"
    "/usr/local/bin/gparted-xwl"
    "/usr/local/share/applications/gparted-wayland.desktop"
    "/usr/share/wallpapers/clipito-01.png"
    "/usr/share/wayland-sessions/sway.desktop"
    "/etc/sudoers.d/waylandenv"
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
# 2) Paquetes flatpak (antes de quitar flatpak)
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
    local to_remove=()
    local p
    for p in "${PKGS[@]}"; do
        if pacman -Qi "$p" >/dev/null 2>&1; then
            to_remove+=("$p")
        fi
    done

    if [[ ${#to_remove[@]} -eq 0 ]]; then
        echo ">> No hay paquetes del script instalados."
        return 0
    fi

    echo ">> Quitando ${#to_remove[@]} paquetes..."
    if [ "$DRY_RUN" -eq 1 ]; then
        printf 'DRY: sudo pacman -Rns --noconfirm %s\n' "${to_remove[*]}"
    else
        sudo pacman -Rns --noconfirm "${to_remove[@]}" \
            || echo "  [aviso] hubo errores al quitar algunos paquetes (ver arriba)."
    fi
    PKGS_REMOVED=${#to_remove[@]}

    echo ">> Quitando paquetes huérfanos..."
    run "sudo pacman -Qdtq | grep -v '^base$' | xargs -r sudo pacman -Rns --noconfirm" \
        || echo "  [aviso] no se pudo completar la limpieza de huérfanos."
}

################################################
# 4) Quitar archivos
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
# main
################################################
main() {
    # diálogos (si no está, lo instalo)
    if [ "$FORCE" -eq 0 ] && ! command -v dialog >/dev/null 2>&1; then
        echo "El paquete 'dialog' no está instalado. Instalando…"
        sudo pacman -Syu --needed --noconfirm dialog || {
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
        msg+=$'\n'"2. Quita los paquetes (pacman -Rns + huérfanos)"
        msg+=$'\n'"3. Borra dotfiles, fuentes, /usr/local, estado, logs y backups"
        msg+=$'\n\n'"Cuando se borre el backup ya no se puede volver."
        if ! dialog --title "Desinstalar Clipito Shell (Arch)" --yesno "$msg" 14 78; then
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
    remove_files

    local summary="Desinstalación completada:"
    summary+=$'\n\n'"Archivos restaurados: $FILES_RESTORED"
    summary+=$'\n'"Paquetes quitados: $PKGS_REMOVED"
    summary+=$'\n'"Archivos/directorios borrados: $FILES_REMOVED"
    summary+=$'\n'"Log: $LOGFILE"
    echo "$summary"

    if [ "$FORCE" -eq 0 ]; then
        dialog --title "Desinstalación completada" --msgbox "$summary" 12 70 || true
    fi
}

main
