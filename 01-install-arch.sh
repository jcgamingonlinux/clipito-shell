#!/usr/bin/env bash
set -euo pipefail

####################
# Advertencia - Versión en pruebas -
# Agradecemos la revisión y los comentarios

# Script integrado para instalación y configuración de "Clipito Shell" en Arch Linux y Derivadas
# Combina un menú interactivo (dialog) con instalación robusta de 3 Wayland Compositors,
# Hyprland, Niri y Sway WM.  Además se tienen disponibles unos packs de software, Básico, Intermedio y Full.
# Septiembre de 2026 - Probado en: https://www.youtube.com/@LinuxenCasa

# Créditos:
#
# Gabriel Parri - Desarrollador del Script de Instalación
# https;//sourceforge.net/projects/gabeeoslinux
#
# Colaboración de Alvaro Valdez como Beta Tester
# https://www.youtube.com/@alvarovalcer
#
# CZOTTA y Adolfo Perez - Reportan modulo de bluetooth OK
#
# JC Gaming On Linux - fork, mejoras y testeo, asistido por JC IA
# https://www.youtube.com/@jcgamingonlinux
####################

#
animate_text() {
  local text="$1"
  local delay="${2:-0.01}"
  local newline="${3:-1}"
  local i
  for ((i = 0; i < ${#text}; i++)); do
    local char="${text:$i:1}"
    echo -n "$char"
    sleep "$delay"
  done
  if [ "$newline" -eq 1 ]; then
    echo ""
  fi
}

#################################################
#################################################
# Primer menú de Bienvenida en texto.
#
clear
animate_text "###################################"
animate_text "      Clipito Shell - Arch"
animate_text "###################################"
sleep 0.2
echo "Script integrado para instalación y"
echo "configuración de Wayland Compositors"
echo "en Arch Linux y Derivadas con SystemD"
echo "QuickShell by Claude Code"
animate_text "------------------------------------"
animate_text "https://www.youtube.com/@LinuxenCasa"
animate_text "https://www.youtube.com/@jcgamingonlinux"
animate_text "------------------------------------"
sleep 0.2
echo "Se mostrará un menú hecho con Dialog"
echo "que debes instalar si es que no está"
echo "instalado."
echo "####################################"
echo "Advertencia:  Script en Pruebas."
echo "####################################"
animate_text "."
animate_text ".."
animate_text "..."
sleep 0.2


# Verificar si pacman está instalado
    if ! command -v pacman &> /dev/null; then
        echo -e "ERROR: No se detecta comando pacman - esta distro no está basada en Arch Linux."
	animate_text "Bye, bye..."
	sleep 0.5
        exit 0
    fi


ARCH_DETECTADO="no"
#
if [ -f "/etc/os-release" ]; then
	if grep -q "arch" /etc/os-release; then
		ARCH_DETECTADO="si"
	fi
fi


if [[ "$ARCH_DETECTADO" == "no" ]]; then
		animate_text "No se detecta Arch Linux."
        animate_text "Si estás seguro que esta distro está basada en"
        animate_text "Arch Linux con systemd, puedes continuar."
		animate_text "De otra forma, lo mejor es Salir o Cancelar!"
		animate_text "--------------------------------------------"
fi


animate_text "Presiona [ENTER] para continuar, [ESC] o [Q] para salir."

while true; do
    # -s: ocultar entrada, -n1: un solo caracter
    read -rsn1 tecla

    case "$tecla" in
        "")
            animate_text "Aceptado. Continuando..."
            break # Rompe el bucle para seguir con el script
            ;;
        $'\e'|q|Q)
            animate_text "Cancelado. Saliendo del script..."
            exit 0 # Finaliza el script por completo
            ;;
        *)
            # Opcional: avisar que la tecla no es válida
            # echo "Tecla no reconocida. Usa Enter, Esc o Q."
            ;;
    esac
done


#################################################
# Verificar que el script no se ejecute como root
if [ "$(whoami)" == "root" ]; then
    echo "Error: Este script no debe ejecutarse como root. Usa un usuario con permisos sudo."
    exit 1
fi

# Verificar permisos sudo
if ! sudo -v; then
    echo "Error: El usuario no tiene permisos sudo o no está configurado."
    exit 1
fi

####################
# Constantes y Variables
####################

MAQUINA_VIRTUAL="no"
# WM_X11_INSTALADO="no"

# Repositorio
#
REPOURL="${REPOURL:-https://github.com/jcgamingonlinux/clipito-shell.git}"
# REPOURL="git@github.com:jcgamingonlinux/clipito-shell.git"
REPOLOCAL="${REPOLOCAL:-/tmp/clipito-shell}"

# Modo prueba local: si el script se ejecuta desde la raiz de un checkout de
# clipito-shell, usar ese directorio en vez de clonar desde GitLab. Asi se
# puede probar este repo sin subirlo.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
REPO_EN_LOCAL="no"
if [ -d "$SCRIPT_DIR/.config/quickshell" ] && [ -d "$SCRIPT_DIR/release" ]; then
    REPO_EN_LOCAL="si"
    REPOLOCAL="$SCRIPT_DIR"
fi

# Repositorio de Wallpapers
REPOWALLPAPERS="https://gitlab.com/linux-en-casa/wallpapers.git"
# REPOWALLPAPERS="git@gitlab.com:linux-en-casa/wallpapers.git"
DIRWALLPAPERS="/home/$USER/.config/wallpapers"

# Formato de fecha para la carpeta de respaldo
DATE=$(date +"%Y-%m-%d_%H-%M-%S")

# Directorio donde se guardarán todos los backups de esta ejecución
BACKUPDIR="$HOME/.config-backup/$DATE"
#
#
#
#################################################
#################################################
    # Paquetes comunes a los tres niveles (básico, intermedio y full)
    pkgs_base=(
        acpi
        alsa-utils
        base-devel
	    curl
        fastfetch
        ffmpeg
        firefox
        gvfs
        mtpfs
        pavucontrol
        playerctl
        thunar
        unrar-free
        xdg-user-dirs
        xfce4-screenshooter
        xorg-server
        yazi
        pipewire
        pipewire-alsa
        pipewire-pulse
        wireplumber
    )

#################################################
    # Paquetes exclusivos del nivel intermedio (se suman a pkgs_base)
    pkgs_extra_intermedio=(
        bottom
        btop
        htop
        hunspell-es_any
        libreoffice-still
        libreoffice-still-es
        mousepad
        mpv
        nuspell
        ristretto
        transmission-qt
        vim
        wget
    )


    pkgs_extra_intermedio_backport=(
        evince
    )


#################################################
    # Paquetes exclusivos del nivel full (se suman a pkgs_base + pkgs_extra_intermedio)
    pkgs_extra_full=(
        audacity
        cava
        cmatrix
        otf-font-awesome
        ttf-roboto
        gnumeric
        gparted
        inkscape
        inxi
        mediainfo
        neovim
        sox
        vlc
        gimp
    )






#################################################
    # paquetes si instalo un Waylan Compositor
    # Algunos se repiten con los de arriba
    # para que el script sirva para distros que ya
    # tienen un Entorno Gráfico instalado.
    #

    pkgs_wm_wayland=(
        adwaita-icon-theme
        alsa-utils
	    breeze
	    breeze-gtk
	    curl
        fastfetch
        ffmpeg
	    otf-font-awesome
	    noto-fonts-emoji
        git
        gparted
        gvfs
	    imagemagick
        ttf-jetbrains-mono-nerd
	    libnotify
        mtpfs
	    nwg-look
        pavucontrol
        playerctl
	    kvantum
	    quickshell
	    sound-theme-freedesktop
	    swaylock
        thunar
        unrar-free
	    vim
        wlr-randr
	    xdg-user-dirs
        yad
       	zenity
       	wdisplays
       	pipewire
	    pipewire-alsa
	    pipewire-pulse
	    wireplumber
)


################################################################################
# funciones
################################################################################
#
# Función de backup: recibe la ruta destino que se va a sobreescribir.
# Si existe (archivo o carpeta), lo copia a BACKUPDIR preservando la estructura.
# Además registra el ítem en el manifiesto ($BACKUPDIR/.manifest) para que
# _backup_list_items pueda reconstruir exactamente qué se respaldó, sin
# adivinar por profundidad de directorios.
# Uso:  backup_if_exists "$HOME/.config/rofi"
#       backup_if_exists "$HOME/.config/picom.conf"
backup_if_exists() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        # Calcular ruta relativa respecto a $HOME para reproducir la estructura
        local rel="${target#$HOME/}"
        local dest="$BACKUPDIR/$rel"

	if [ ! -d "$(dirname "$dest")" ]; then
	    mkdir -p "$(dirname "$dest")"
        fi

        cp -a "$target" "$dest"
        printf 'user\t%s\t%s\n' "$target" "$dest" >> "$BACKUPDIR/.manifest"
        echo "  [backup] $target  ->  $dest"
    fi
}


# Función de backup para rutas del sistema (/usr/...).
# Copia (no mueve) el archivo existente a BACKUPDIR preservando la estructura.
# Registra el ítem en el mismo manifiesto que backup_if_exists.
# Uso:  backup_system_if_exists "/usr/local/bin/KeyHintsBSPWM"
#       backup_system_if_exists "/usr/share/wallpapers/clipito-01.png"
backup_system_if_exists() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        # Ruta relativa desde / para reproducir la estructura dentro del backup
        local rel="${target#/}"
        local dest="$BACKUPDIR/system/$rel"


	if [ ! -d "$(dirname "$dest")" ]; then
	    mkdir -p "$(dirname "$dest")"
        fi

        sudo cp -a "$target" "$dest"
        printf 'system\t%s\t%s\n' "$target" "$dest" >> "$BACKUPDIR/.manifest"
        echo "  [backup-system] $target  ->  $dest"
    fi
}



# Definir archivo de log
LOGFILE="$HOME/install_log.txt"
echo "Registro de instalación se guardará en: $LOGFILE"

# función para detectar si estoy en maquina virtual
check_virtual() {
if ! command -v systemd-detect-virt > /dev/null 2>&1; then
	echo "parece que no estoy en systemd"
else
	if [ "$(systemd-detect-virt)" == "none" ]; then
		# echo "Estoy en un equipo real"
		MAQUINA_VIRTUAL="no"
	else
		# echo "Estoy en una maquina virtual"
		MAQUINA_VIRTUAL="si"
	fi
fi
}

################################################
################################################

# Menús Interactivos con Dialog.
# Definición de opciones.
declare -A WM_DESC=(
    [hyprland]="HYPRLAND (Wayland C.)"
    [niri]="NIRI (Scroll Wayland C.)"
    [sway]="Sway WM (wayland C.)"
)

declare -A SOFTWARE_DESC=(
    [basico]="Básico - (Thunar, Firefox ...)"
    [intermedio]="Intermedio - (LibreOffice, mpv ...)"
    [full]="Full - BloatWare al más puro estilo Windows 11"
)

declare -A APPS_DESC=(
    [yay]="yay - AUR Helper"
    [paru]="paru - AUR Helper"
    [flatpak]="flatpak - flathub"
    [nerdfonts-all]="Nerd Fonts (todas ~1.2 GB)"
)

declare -A DM_DESC=(
#     [lightdm]="LightDM - Recomendado"
    [sddm]="SDDM"
    [ly]="ly - Experimental"
)

declare -A FLATPAK_DESC=(
    [md.obsidian.Obsidian]="Obsidian (notas markdown)"
    [com.obsproject.Studio]="OBS Studio (grabación/streaming)"
    [com.obsproject.Studio.Plugin.GStreamerVaapi]="OBS Plugin GStreamer VA-API"
    [com.discordapp.Discord]="Discord (chat)"
    [org.kde.kdenlive]="Kdenlive (editor de video)"
    [org.jitsi.jitsi-meet]="Jitsi Meet (videollamadas)"
    [org.telegram.desktop]="Telegram (mensajería)"
    [com.google.Chrome]="Google Chrome (navegador)"
)

# Estado de selección
declare -A SEL_WM SEL_SOFTWARE SEL_APPS SEL_DM SEL_FLATPAK
for k in "${!WM_DESC[@]}"; do SEL_WM[$k]=0; done
for k in "${!SOFTWARE_DESC[@]}"; do SEL_SOFTWARE[$k]=0; done
for k in "${!APPS_DESC[@]}"; do SEL_APPS[$k]=0; done
for k in "${!DM_DESC[@]}"; do SEL_DM[$k]=0; done
for k in "${!FLATPAK_DESC[@]}"; do SEL_FLATPAK[$k]=0; done

STATE_FILE="$HOME/.wm-installer-state"

#
####################
# Funciones
####################
#
# Función para verificar conectividad
check_internet() {
    if ! ping -c 1 google.com > /dev/null 2>&1; then
        echo "Error: No hay conexión a internet. Verifica tu conexión y reintenta."
        exit 1
    fi
}

# Función para manejar errores no fatales
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        return 1
    fi
    return 0
}


# Asegurar que 'dialog' esté instalado antes de usarlo
ensure_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        echo "El paquete 'dialog' no está instalado. Instalando…"
        check_internet
        sudo pacman -Syu --needed --noconfirm dialog >/dev/null 2>&1 || {
            echo "No se pudo instalar 'dialog'. Abortando."; exit 1;
        }
    fi
}

# Asegurar que 'git' esté instalado antes de usarlo
ensure_git() {
    if ! command -v git >/dev/null 2>&1; then
        echo "El paquete 'git' no está instalado. Instalando…"
        check_internet
        sudo pacman -Syu --needed --noconfirm git >/dev/null 2>&1 || {
            echo "No se pudo instalar 'git'. Abortando."; exit 1;
        }
    fi
}

################################################
################################################
# Cargar y guardar estado
# desmarco software y el Display Manager
# con eso puedo usar el script en la post-instalación
# solo para instalar otros WM
#
load_state() {
    [[ -f "$STATE_FILE" ]] || return 0
    while IFS='=' read -r k v; do
        if [[ $k == wm_* ]]; then
            k=${k#wm_}
            [[ -v WM_DESC[$k] ]] && SEL_WM[$k]=$v || true
#         elif [[ $k == software_* ]]; then
#             k=${k#software_}
#             [[ -v SOFTWARE_DESC[$k] ]] && SEL_SOFTWARE[$k]=$v
        elif [[ $k == apps_* ]]; then
            k=${k#apps_}
            [[ -v APPS_DESC[$k] ]] && SEL_APPS[$k]=$v || true
        elif [[ $k == flatpak_* ]]; then
            k=${k#flatpak_}
            [[ -v FLATPAK_DESC[$k] ]] && SEL_FLATPAK[$k]=$v || true
#         elif [[ $k == dm_* ]]; then
#             k=${k#dm_}
#             [[ -v DM_DESC[$k] ]] && SEL_DM[$k]=$v
        fi
    done < "$STATE_FILE"
    # return 0 explícito: un estado viejo (clave que ya no existe en el menú)
    # no debe matar el script bajo set -e.
    return 0
}

save_state() {
    mkdir -p "$(dirname "$STATE_FILE")"   # si HOME no existe, set -e no mata el script
    : > "$STATE_FILE"
    for k in "${!WM_DESC[@]}"; do printf 'wm_%s=%d\n' "$k" "${SEL_WM[$k]}" >> "$STATE_FILE"; done
    for k in "${!SOFTWARE_DESC[@]}"; do printf 'software_%s=%d\n' "$k" "${SEL_SOFTWARE[$k]}" >> "$STATE_FILE"; done
    for k in "${!APPS_DESC[@]}"; do printf 'apps_%s=%d\n' "$k" "${SEL_APPS[$k]}" >> "$STATE_FILE"; done
    for k in "${!DM_DESC[@]}"; do printf 'dm_%s=%d\n' "$k" "${SEL_DM[$k]}" >> "$STATE_FILE"; done
    for k in "${!FLATPAK_DESC[@]}"; do printf 'flatpak_%s=%d\n' "$k" "${SEL_FLATPAK[$k]}" >> "$STATE_FILE"; done
}

# Menús interactivos con dialog

# Advertencia cuando no se marcó ninguna opción en un menú:
# avisa que hay que elegir al menos una y muestra las teclas a usar.
# Uso: warn_no_selection <título> <detalle de qué elegir>
warn_no_selection() {
    local title="$1"
    local detalle="$2"
    local rc=0
    # || rc=$?: con set -e, un dialog que devuelve 1 (ESC) mataría el script.
    dialog --title "$title" --msgbox \
        "No has seleccionado ninguna opción.\n\n$detalle\n\nTeclas:\n  ESPACIO: marcar / desmarcar una opción\n  ENTER: confirmar la selección\n\nElegí al menos una opción,\no presioná ESC para volver (no cambia la selección actual)." \
        16 80 || rc=$?
    return "$rc"
}

# ¿Se seleccionó al menos un WM? (0 = sí, 1 = no)
wm_selected() {
    local k
    for k in "${!WM_DESC[@]}"; do
        [[ ${SEL_WM[$k]} -eq 1 ]] && return 0
    done
    return 1
}


show_wm_menu() {
    local items=()
    local out=""

    # Recorro hasta que se marque al menos una opción (o se cancele con ESC)
    while true; do
        items=()
        for k in "${!WM_DESC[@]}"; do
            local flag="off"; [[ ${SEL_WM[$k]} -eq 1 ]] && flag="on"
            items+=("$k" "${WM_DESC[$k]}" "$flag")
        done

        out=$(dialog --title "Wayland Compositors" \
            --checklist "Seleccioná WCs (Espacio para marcar, Enter para confirmar):" \
            20 78 10 \
            "${items[@]}" \
            3>&1 1>&2 2>&3) || return 0   # ESC/cancelar: no toco la selección

        # Se marcó algo: lo aplico
        [[ -n "$out" ]] && break

        # No se marcó nada: aviso con las teclas. ENTER reabre el menú;
        # ESC vuelve al menú principal sin tocar la selección actual.
        if ! warn_no_selection "Wayland Compositors" "Para continuar necesitás seleccionar al menos un compositor."; then
            return 0
        fi
    done

    # Checklist => múltiples; limpio y marco lo elegido
    for k in "${!WM_DESC[@]}"; do SEL_WM[$k]=0; done
    for c in $out; do
        c="${c//\"/}"                 # quitar comillas que devuelve dialog
        [[ -v WM_DESC[$c] ]] && SEL_WM[$c]=1
    done

    save_state
}


show_software_menu() {
    local items=()
    local out=""

    while true; do
        items=()
        for k in "${!SOFTWARE_DESC[@]}"; do
            local flag="off"; [[ ${SEL_SOFTWARE[$k]} -eq 1 ]] && flag="on"
            items+=("$k" "${SOFTWARE_DESC[$k]}" "$flag")
        done

        out=$(dialog --title "Paquetes de Software" \
            --radiolist "Seleccioná un Pack de Software (Espacio para marcar, Enter para confirmar):" \
            20 78 10 \
            "${items[@]}" \
            3>&1 1>&2 2>&3) || return 0   # ESC/cancelar: no toco la selección

        [[ -n "$out" ]] && break

        if ! warn_no_selection "Paquetes de Software" "Para continuar necesitás seleccionar al menos un pack."; then
            return 0   # ESC en el aviso: volver al menú principal
        fi
    done

    # Radiolist -> una sola opción activa
    for k in "${!SOFTWARE_DESC[@]}"; do SEL_SOFTWARE[$k]=0; done
    for c in $out; do
        c="${c//\"/}"                 # dialog devuelve comillas
        [[ -v SOFTWARE_DESC[$c] ]] && SEL_SOFTWARE[$c]=1
    done

    save_state
}


show_flatpak_menu() {
    local items=()
    local out=""

    while true; do
        items=()
        for k in "${!FLATPAK_DESC[@]}"; do
            local flag="off"; [[ ${SEL_FLATPAK[$k]} -eq 1 ]] && flag="on"
            items+=("$k" "${FLATPAK_DESC[$k]}" "$flag")
        done

        out=$(dialog --title "Apps Flatpak (Flathub)" \
            --checklist "Seleccioná las apps Flatpak a instalar (Espacio para marcar, Enter para confirmar):" \
            20 78 10 \
            "${items[@]}" \
            3>&1 1>&2 2>&3) || return 0   # ESC/cancelar: no toco la selección

        [[ -n "$out" ]] && break

        if ! warn_no_selection "Apps Flatpak (Flathub)" "Para instalar apps Flatpak necesitás seleccionar al menos una."; then
            return 0   # ESC en el aviso: volver al menú principal
        fi
    done

    for k in "${!FLATPAK_DESC[@]}"; do SEL_FLATPAK[$k]=0; done
    for c in $out; do
        c="${c//\"/}"
        [[ -v FLATPAK_DESC[$c] ]] && SEL_FLATPAK[$c]=1
    done
    save_state
}


show_apps_menu() {
    local items=()
    local out=""

    while true; do
        items=()
        for k in "${!APPS_DESC[@]}"; do
            local flag="off"; [[ ${SEL_APPS[$k]} -eq 1 ]] && flag="on"
            items+=("$k" "${APPS_DESC[$k]}" "$flag")
        done

        out=$(dialog --title "Aplicaciones Adicionales" \
            --checklist "Seleccioná aplicaciones (Espacio para marcar, Enter para confirmar):" \
            20 78 10 \
            "${items[@]}" \
            3>&1 1>&2 2>&3) || return 0   # ESC/cancelar: no toco la selección

        [[ -n "$out" ]] && break

        if ! warn_no_selection "Aplicaciones Adicionales" "Para continuar necesitás seleccionar al menos una aplicación."; then
            return 0   # ESC en el aviso: volver al menú principal
        fi
    done

    for k in "${!APPS_DESC[@]}"; do SEL_APPS[$k]=0; done
    for c in $out; do
        c="${c//\"/}"
        [[ -v APPS_DESC[$c] ]] && SEL_APPS[$c]=1
    done
    save_state

    # Si se seleccionó flatpak, mostrar submenú de apps Flatpak
    if [[ ${SEL_APPS[flatpak]} -eq 1 ]]; then
        show_flatpak_menu
    else
        # Si se deseleccionó flatpak, limpiar selección de apps flatpak
        for k in "${!FLATPAK_DESC[@]}"; do SEL_FLATPAK[$k]=0; done
        save_state
    fi
}


show_dm_menu() {
    local items=()
    local out=""

    while true; do
        items=()
        for k in "${!DM_DESC[@]}"; do
            local flag="off"; [[ ${SEL_DM[$k]} -eq 1 ]] && flag="on"
            items+=("$k" "${DM_DESC[$k]}" "$flag")
        done

        out=$(dialog --title "Display Managers" \
            --radiolist "Seleccioná uno o varios DMs (Espacio para marcar, Enter para confirmar):" \
            20 78 10 \
            "${items[@]}" \
            3>&1 1>&2 2>&3) || return 0   # ESC/cancelar: no toco la selección

        [[ -n "$out" ]] && break

        if ! warn_no_selection "Display Managers" "Para continuar necesitás seleccionar al menos un display manager."; then
            return 0   # ESC en el aviso: volver al menú principal
        fi
    done

    # Radiolist => una sola opción
    for k in "${!DM_DESC[@]}"; do SEL_DM[$k]=0; done
    for c in $out; do
        c="${c//\"/}"
        [[ -v DM_DESC[$c] ]] && SEL_DM[$c]=1
    done
    save_state
}


show_summary() {
    local summary="Resumen de la configuración:\n\n"
    summary+="Wayland Compositors:\n"
    for k in "${!WM_DESC[@]}"; do
        [[ ${SEL_WM[$k]} -eq 1 ]] && summary+="- ${WM_DESC[$k]}\n"
    done
    summary+="\nPaquete de Software:\n"
    for k in "${!SOFTWARE_DESC[@]}"; do
        [[ ${SEL_SOFTWARE[$k]} -eq 1 ]] && summary+="- ${SOFTWARE_DESC[$k]}\n"
    done
    summary+="\nAplicaciones Adicionales:\n"
    for k in "${!APPS_DESC[@]}"; do
        [[ ${SEL_APPS[$k]} -eq 1 ]] && summary+="- ${APPS_DESC[$k]}\n"
    done
    if [[ ${SEL_APPS[flatpak]} -eq 1 ]]; then
        summary+="\n  Apps Flatpak seleccionadas:\n"
        local hay_flatpak=0
        for k in "${!FLATPAK_DESC[@]}"; do
            if [[ ${SEL_FLATPAK[$k]} -eq 1 ]]; then
                summary+="  · ${FLATPAK_DESC[$k]}\n"
                hay_flatpak=1
            fi
        done
        [[ $hay_flatpak -eq 0 ]] && summary+="  (ninguna app seleccionada)\n"
    fi
    summary+="\nDisplay Manager:\n"
    for k in "${!DM_DESC[@]}"; do
        [[ ${SEL_DM[$k]} -eq 1 ]] && summary+="- ${DM_DESC[$k]}\n"
    done
    dialog --title "Resumen" --msgbox "$summary" 20 78 || true
}


show_leeme_menu() {

    local msg="\

Script de Instalación \"Clipito Shell - Arch\"
y Software para Arch Linux y Derivadas - 64 Bits.

youtube.com/@LinuxenCasa
https://github.com/jcgamingonlinux/clipito-shell
Script by Gabriel Parri - gabeeOS Linux
JC Gaming On Linux - fork, mejoras y testeo, asistido por JC IA

Importante:
Este script está ajustado para Arch Linux

Podría funcionar en otra distro siempre y cuando
esté basada en Arch con systemd.


Más detalles en el repositorio:
https://github.com/jcgamingonlinux/clipito-shell"



    dialog --title "Instrucciones - Leeme" --msgbox "$msg" 20 78 || true

}


#
################################################
#
################################################
#
#########################
# Instalación de paquetes
#########################

clear

install_selected() {
    # Iniciar el registro de instalación
    exec > >(tee -i "$LOGFILE") 2>&1
    echo ">> Iniciando instalación..."
    check_internet

    # Registro del estado de paquetes ANTES de instalar: permite a la
    # desinstalación quitar solo lo que ESTE script agregó (y no paquetes
    # que ya vinieran de la distro, ej. CachyOS).
    PACMAN_BEFORE="$HOME/.wm-installer-packages-before"
    # Si pacman falla (p. ej. lock de DB), NO dejar un snapshot vacío/parcial:
    # con antes=vacío el diff marcaría TODOS los paquetes del sistema como
    # "nuevos" y la desinstalación intentaría quitar casi todo. Sin snapshot,
    # el 04 usa la lista estática (más conservadora).
    if ! pacman -Qq > "$PACMAN_BEFORE" 2>/dev/null; then
        echo ">> [aviso] no se pudo registrar el snapshot de paquetes (pacman -Qq falló): la desinstalación usará la lista estática."
        rm -f "$PACMAN_BEFORE"
    fi

    sudo pacman -Syu curl --needed --noconfirm || check_error "No se pudo actualizar el sistema."



    ############################################
    # Instalación de quickshell
    sudo pacman -S --needed --noconfirm quickshell



    ############################################

    #############################################
    # Ahora instalo el pack de software.

    # Instalar paquetes de software según selección
    for k in "${!SOFTWARE_DESC[@]}"; do
        if [[ ${SEL_SOFTWARE[$k]} -eq 1 ]]; then
            echo ">> Instalando paquete $k..."
            case "$k" in
                basico)
                    sudo pacman -S --needed --noconfirm "${pkgs_base[@]}" || check_error "No se pudieron instalar las aplicaciones básicas."
                    ;;
                intermedio)
                    sudo pacman -S --needed --noconfirm "${pkgs_base[@]}" "${pkgs_extra_intermedio[@]}" || check_error "No se pudieron instalar las aplicaciones intermedias."
                    ;;
                full)
                    sudo pacman -S --needed --noconfirm "${pkgs_base[@]}" "${pkgs_extra_intermedio[@]}" "${pkgs_extra_full[@]}" || check_error "No se pudieron instalar las aplicaciones completas."
                    ;;
            esac
        fi
    done

    #############################################
    # descargar los dot-files del repo de gitlab
    # lo descargo en /tmp para que no haya problemas con el directorio actual

    if [ "$REPO_EN_LOCAL" = "si" ]; then
        # Modo prueba: usar el repo desde donde se ejecuta el script, sin clonar
        echo "Modo local: usando el repositorio en $REPOLOCAL (no se clona desde GitLab)"
    else
        echo "Descargando configuraciones desde GitLab..."
        # borro el subdrectorio si su existe
        #
        if [ -d "$REPOLOCAL" ]; then
            echo "borrando directorio"
            sudo rm -rf "$REPOLOCAL"
        fi

        cd /tmp
        # clonar explícitamente al destino esperado
        git clone "$REPOURL" "$REPOLOCAL" || { echo "Error: No se pudo clonar el repositorio de dotfiles."; exit 1; }
    fi


################################################
################################################
#
# crear los directorios y copiar los archivos comunes a todos los Wayland Compositors

    # Instalar paquetes básicos para los Wayland Compositors
    if [[ ${SEL_WM[hyprland]} -eq 1 || ${SEL_WM[niri]} -eq 1 || \
          ${SEL_WM[sway]} -eq 1 ]]; then


    # Crear directorios necesarios para los dot-files y archivos de configuracion
    for dir in "$HOME/.config" "$HOME/.local" "$HOME/.local/share" "$HOME/.local/src" \
               "/usr/share/wallpapers" "$HOME/.config/quickshell" \
	       "$HOME/.local/share/icons" "/usr/local/bin" "$HOME/wallpapers"; do
        if [ ! -d "$dir" ]; then
            if [[ "$dir" == /usr/* ]]; then
                sudo mkdir -p "$dir" || check_error "No se pudo crear el directorio $dir."
            else
                mkdir -p "$dir" || check_error "No se pudo crear el directorio $dir."
            fi
        fi
    done

    cd $REPOLOCAL/.config/
    backup_if_exists "$HOME/.config/gtk-3.0"
    cp -r gtk-3.0/ ~/.config/ || check_error "No se pudieron copiar los dotfiles a ~/.config."
    cd $REPOLOCAL/usr/share/wallpapers/
    backup_system_if_exists "/usr/share/wallpapers/clipito-01.png"
    sudo cp clipito-01.png /usr/share/wallpapers/ || check_error "No se pudo copiar el fondo de pantalla a /usr/share/wallpapers."





    ###############################

    echo "Instalando paquetes básicos para WM con Wayland..."
    sudo pacman -S --needed --noconfirm "${pkgs_wm_wayland[@]}" || check_error "No se pudieron instalar los paquetes básicos."

    for dir in "$HOME/.config" "$HOME/.local" "$HOME/.local/share" \
               "/usr/share/wallpapers" "/usr/share/wayland-sessions" "/usr/local/bin"; do
        if [ ! -d "$dir" ]; then
            if [[ "$dir" == /usr/* ]]; then
                sudo mkdir -p "$dir" || check_error "No se pudo crear el directorio $dir."
            else
                mkdir -p "$dir" || check_error "No se pudo crear el directorio $dir."
            fi
        fi
    done


            # configurar permisos para abrir algunas apps como gparted

		    echo 'Defaults env_keep += "XDG_RUNTIME_DIR WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS"' | sudo tee /etc/sudoers.d/waylandenv
                    sudo chmod 440 /etc/sudoers.d/waylandenv

		    pkgs_sway_wayland_gui=(
                        gparted
                    )
            sudo pacman -S --needed --noconfirm "${pkgs_sway_wayland_gui[@]}"
		    # configurar para que gparted se lance
		    # usando zenity y paso a paso de G. Parri
		    sudo mkdir -p /usr/local/share/applications/
		    cd $REPOLOCAL/usr/local/share/applications/
		    backup_system_if_exists "/usr/local/share/applications/gparted-wayland.desktop"
		    sudo cp gparted-wayland.desktop  /usr/local/share/applications/
		    cd $REPOLOCAL/usr/local/bin/
		    backup_system_if_exists "/usr/local/bin/askpass-zenity"
		    backup_system_if_exists "/usr/local/bin/gparted-xwl"
		    sudo cp askpass-zenity gparted-xwl /usr/local/bin/


    ########################################################################
    #
    # Copiar archivos de configuración inicial del WC con quickshell
    # Fija el wallpaper, el tamaño del launcher, posición de los módulos
    # en la barra de quickshell
    # solo por precaución, si existe un archivo shell en quickshell lo borro
    # de lo contrario no arranca la configuración de los WC.
    ########################################################################

    for file in   "$HOME/wallpapers/clipito-01.png" "$HOME/.config/quickshell/bar-layout.tsv" \
               "$HOME/.config/quickshell/launcher-size.txt" "$HOME/.config/quickshell/wallpaper-fillmode.txt" \
	       "$HOME/.config/quickshell/wallpaper-path.txt" "$HOME/.config/quickshell/shell.qml"; do

        if [ -f "$file" ]; then
            backup_if_exists "$file"
            rm -f "$file"
        fi

    done

    cd $REPOLOCAL/.config/quickshell
    cp bar-layout.tsv launcher-size.txt wallpaper-fillmode.txt wallpaper-path.txt ~/.config/quickshell || check_error "No se pudieron copiar los archivos de configuracion del WC de quickshell"
    cp $REPOLOCAL/wallpapers/clipito-01.png ~/wallpapers || check_error "No se pudieron copiar los archivos de configuracion del WC de quickshell"


    # Crear directorios del home del usuario
    echo "Creando directorios del home del usuario..."
    xdg-user-dirs-update


    fi


########################################################
########################################################

# Instalar wayland compositors

    for k in "${!WM_DESC[@]}"; do

        if [[ ${SEL_WM[$k]} -eq 1 ]]; then
            echo ">> Instalando $k..."
            case "$k" in

                hyprland)
                    pkgs_hyprland=(
                        hyprland
                        hyprland-guiutils
                        kitty
                        xorg-xwayland
                        xdg-desktop-portal-hyprland
                        xdg-desktop-portal-gtk
                    )
                    sudo pacman -S --needed --noconfirm "${pkgs_hyprland[@]}" || check_error "No se pudo instalar hyprland"

                    backup_if_exists "$HOME/.config/hypr"

                    if [ -d "$HOME/.config/hypr" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/hypr"
                    fi

                    cd $REPOLOCAL/.config/arch-dotfiles
                    cp -r hypr/ $HOME/.config/ || check_error "No se pudieron copiar los dotfiles a ~/.config."

                    backup_if_exists "$HOME/.config/kitty"
                    if [ -d "$HOME/.config/kitty" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/kitty"
                    fi
                    cd $REPOLOCAL/.config/
                    cp -r kitty/ $HOME/.config/ || check_error "No se pudieron copiar los dotfiles a ~/.config."

                    backup_if_exists "$HOME/.config/quickshell/hyprland-bar"

                    if [ -d "$HOME/.config/quickshell/hyprland-bar" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/quickshell/hyprland-bar"
                    fi

                    cp -r $REPOLOCAL/.config/quickshell/hyprland-bar/ $HOME/.config/quickshell/hyprland-bar || check_error "No se pudieron copiar los dotfiles a ~/.config."

                    ;;


                niri)
                    pkgs_niri=(
                        alacritty
                        niri
                        xdg-desktop-portal-gtk
                        xorg-xwayland
                        xwayland-satellite
                    )
                    sudo pacman -S --needed --noconfirm "${pkgs_niri[@]}" || check_error "No se pudo instalar niri"



                    backup_if_exists "$HOME/.config/niri"

                    if [ -d "$HOME/.config/niri" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/niri"
                    fi

                    cd $REPOLOCAL/.config/arch-dotfiles
                    cp -r niri/ $HOME/.config/ || check_error "No se pudieron copiar los dotfiles a ~/.config."

                    backup_if_exists "$HOME/.config/alacritty"
                    if [ -d "$HOME/.config/alacritty" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/alacritty"
                    fi
                    cd $REPOLOCAL/.config/
                    cp -r alacritty/ $HOME/.config/ || check_error "No se pudieron copiar los dotfiles a ~/.config."

                    backup_if_exists "$HOME/.config/quickshell/niri-bar"

                    if [ -d "$HOME/.config/quickshell/niri-bar" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/quickshell/niri-bar"
                    fi

                    cp -r $REPOLOCAL/.config/quickshell/niri-bar/ $HOME/.config/quickshell/niri-bar || check_error "No se pudieron copiar los dotfiles a ~/.config."

                    ;;

                sway)
                    pkgs_sway=(
                        foot
                        sway
                        swaybg
                        xdg-desktop-portal-gtk
                        xdg-desktop-portal-wlr
                        xorg-xwayland
                    )
                    sudo pacman -S --needed --noconfirm "${pkgs_sway[@]}" || check_error "No se pudo instalar sway."

                    backup_if_exists "$HOME/.config/sway"

                    if [ -d "$HOME/.config/sway" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/sway"
                    fi

                    cd $REPOLOCAL/.config/arch-dotfiles
                    cp -r sway/ $HOME/.config/ || check_error "No se pudieron copiar los dotfiles a ~/.config."

                    backup_if_exists "$HOME/.config/foot"
                    if [ -d "$HOME/.config/foot" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/foot"
                    fi
                    cd $REPOLOCAL/.config/
                    cp -r foot/ $HOME/.config/ || check_error "No se pudieron copiar los dotfiles a ~/.config."

                    backup_if_exists "$HOME/.config/quickshell/sway-bar"

                    if [ -d "$HOME/.config/quickshell/sway-bar" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/quickshell/sway-bar"
                    fi

              	    cp -r $REPOLOCAL/.config/quickshell/sway-bar/ $HOME/.config/quickshell/sway-bar || check_error "No se pudieron copiar los dotfiles a ~/.config."

                    if [[ "$MAQUINA_VIRTUAL" == "si" ]]; then
                            if [ -f "/usr/share/wayland-sessions/sway.desktop" ]; then
                                sudo rm -r /usr/share/wayland-sessions/sway.desktop
                                cd $REPOLOCAL/usr/share/wayland-sessions
                                backup_system_if_exists "/usr/share/wayland-sessions/sway.desktop"
                           	    sudo cp sway.desktop /usr/share/wayland-sessions/ || check_error "No se pudieron copiar los dotfiles a ~/.config."
                           	fi
                    fi

		    ;;

            esac
        fi
    done

########################################################

    # Instalar display managers
    for k in "${!DM_DESC[@]}"; do
        if [[ ${SEL_DM[$k]} -eq 1 ]]; then
            echo ">> Instalando DM $k..."

	    ###  primero deshabilito el display manager activo si es que hay alguno
	    if [ -z "$(systemctl list-units --type=service | grep -i "display manager")" ]; then
		    echo "parece que no hay un display manager activo"
	    else
		    echo "deshabilito el display manager activo"
	            buscarDM=$(systemctl list-units --type=service | grep -i "display manager")
		    DM=$(echo $buscarDM | awk '{print $1}')
		    sudo systemctl disable $DM
	    fi

            case "$k" in
                lightdm)
                    sudo pacman -S --needed --noconfirm lightdm lightdm-gtk-greeter
                    # check_error "No se pudo instalar LightDM." || exit 1
		    sudo systemctl enable lightdm.service
                    # check_error "No se pudo activar LightDM." || exit 1
                    ;;

                ly)
                    sudo pacman -S --needed --noconfirm ly
                    # check_error "No se pudo instalar ly." || exit 1
		    sudo systemctl enable ly@tty2.service
                    # check_error "No se pudo activar ly." || exit 1
                    ;;

                sddm)
                    sudo pacman -S --needed --noconfirm sddm
                    # check_error "No se pudo instalar SDDM." || exit 1
		    sudo systemctl enable sddm.service
                    # check_error "No se pudo activar SDDM." || exit 1
                    ;;

            esac
        fi
    done


########################################################
# Instalar aplicaciones adicionales

   # Evitar duplicados: si se eligió "todas", salteamos la ligera (JBM)
    local INSTALL_ALL_NF="${SEL_APPS[nerdfonts-all]:-0}"

    for k in "${!APPS_DESC[@]}"; do
        if [[ ${SEL_APPS[$k]} -eq 1 ]]; then
            echo ">> Instalando aplicación $k..."
            case "$k" in

	       yay)

               if [ -d "/tmp/yay" ]; then
                    sudo rm -rf "/tmp/yay" || check_error "No se pudo borrar /tmp/yay."
               fi
	       cd /tmp
	       sudo pacman -Syu --needed --noconfirm base-devel go git
	       git clone https://aur.archlinux.org/yay.git
	       cd yay
	       makepkg -si
	       ;;


	       paru)

               if [ -d "/tmp/paru" ]; then
                    sudo rm -rf "/tmp/paru" || check_error "No se pudo borrar /tmp/paru."
               fi
	       cd /tmp
	       sudo pacman -Syu --needed --noconfirm base-devel go git
	       git clone https://aur.archlinux.org/paru.git
	       cd paru
	       makepkg -si
	       ;;




                flatpak)
                # Instalar flatpak y agregar Flathub
                sudo pacman -S --needed --noconfirm flatpak || check_error "No se pudo instalar flatpak."

                # Agregar remoto flathub si no existe (modo sistema)
                flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || check_error "No se pudo añadir el repositorio Flathub."

                # Actualizar metadatos y reparar cache (mejor esfuerzo)
                flatpak update -y --appstream || true
                flatpak repair -y || true

                sleep 2

                # (Opcional) Preinstalar runtime KDE (tolerante a fallos)
                # flatpak install -y flathub org.kde.Platform//6.8 || true

                # --- INSTALAR APPS SELECCIONADAS EN EL SUBMENÚ FLATPAK ---
                failed=()
                for app in "${!FLATPAK_DESC[@]}"; do
                    if [[ ${SEL_FLATPAK[$app]} -eq 1 ]]; then
                        echo ">> Instalando $app…"
                        if ! flatpak install -y flathub "$app"; then
                            echo "Falló la instalación de $app, continúo."
                            failed+=("$app")
                        fi
                    fi
                done

                # Resumen de fallos (no interrumpe el script)
                if ((${#failed[@]})); then
                    echo "===== RESUMEN FLATPAK ====="
                    echo "Fallaron estas apps:"
                    for f in "${failed[@]}"; do echo " - $f"; done
                    echo "==========================="
                else
                    echo "Todas las apps Flatpak se instalaron correctamente."
                fi
                ;;




               nerdfonts-all)
                    echo "Instalando TODAS las Nerd Fonts (~1.2 GB)…"

                    # Dependencias mínimas
                    sudo pacman -S --needed --noconfirm git unzip fontconfig curl ca-certificates || {
                        echo "No se pudieron instalar dependencias (git/unzip/fontconfig/curl)."; exit 1; }

                    # Función para elegir un directorio de trabajo en un FS nativo Linux (ext4/xfs)
                    pick_workdir() {
                        for d in "$HOME/.cache" "/var/tmp" "/tmp"; do
                            [[ -d "$d" ]] || continue
                            fstype=$(df -T "$d" | awk 'NR==2{print $2}')
                            if [[ "$fstype" == "ext4" || "$fstype" == "xfs" || "$fstype" == "btrfs" ]]; then
                                echo "$d"
                                return 0
                            fi
                        done
                        echo "$HOME"  # fallback (igual probamos)
                    }

                    BASE="$(pick_workdir)"
                    WORKDIR="$BASE/nerd-fonts-build"
                    echo "Usando directorio de trabajo: $WORKDIR"
                    rm -rf "$WORKDIR"
                    mkdir -p "$WORKDIR"
                    cd "$WORKDIR" || { echo "No se pudo entrar a $WORKDIR"; exit 1; }

                    # Chequeo de espacio libre (~3 GB recomendado para estar holgado)
                    FREE_KB=$(df -k "$WORKDIR" | awk 'NR==2{print $4}')
                    if [[ "${FREE_KB:-0}" -lt 3000000 ]]; then   # ~3 GB
                        echo "Error: espacio libre insuficiente en $WORKDIR (recomendado >3 GB)."; exit 1
                    fi

                    echo "Clonando repo oficial (shallow)…"
                    if ! git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git; then
                        echo "Error: no se pudo clonar el repo nerd-fonts."; exit 1
                    fi

                    cd nerd-fonts || { echo "No se pudo entrar al directorio nerd-fonts."; exit 1; }

                    # Instalación oficial
                    if ./install.sh; then
                        fc-cache -f || true
                        echo "Instalación de TODAS las Nerd Fonts finalizada."

                        # Limpieza automática del workspace (solo si todo salió bien)
                        cd "$HOME" || true
                        rm -rf "$WORKDIR"
                        echo "Limpieza: se eliminó $WORKDIR"
                    else
                        echo "Error: falló ./install.sh."
                        echo "Posibles causas: filesystem no nativo (NTFS/exFAT) o permisos."
                        echo "Sugerencias:"
                        echo "  - Probá correr de nuevo: el script ya elige /var/tmp si está disponible (ext4)."
                        echo "  - Verificá que haya >3 GB libres en $WORKDIR."
                        echo "Dejo $WORKDIR para inspección."
                        exit 1
                    fi
                    ;;


            esac
        fi
    done

    # Registro de los paquetes NUEVOS que instaló este script (diff antes/después).
    # Si el instalador se reejecutaba, se une con el registro anterior.
    NEWPKGS="$HOME/.wm-installer-packages-new"
    if [ -f "$PACMAN_BEFORE" ]; then
        diff <(sort "$PACMAN_BEFORE") <(sort <(pacman -Qq)) | awk '/^>/{print $2}' >> "$NEWPKGS" 2>/dev/null || true
        if [ -f "$NEWPKGS" ]; then
            sort -u "$NEWPKGS" -o "$NEWPKGS"
            echo ">> Paquetes instalados por este script: $(wc -l < "$NEWPKGS") (registro: $NEWPKGS)"
        fi
    fi

    dialog --title "Instalación" --msgbox "Instalación completada. Por favor, cierra sesión o reinicia para aplicar los cambios. Selecciona tu WM/DM en el gestor de inicio de sesión. Consulta $LOGFILE para detalles." 10 60 || true
    exec > /dev/tty 2>&1
    clear   # <<< limpia la pantalla al terminar todo el proceso
}


# Pantalla de bienvenida (se muestra antes del menú)
show_welcome() {
    # Info útil para mostrar
    local host user distro ver fecha
    host="$(hostnamectl 2>/dev/null | grep hostname | awk '{print $3}' || true)"   # sin systemd/no hay match: no mata el script
    user="$USER"
    distro="$(. /etc/os-release 2>/dev/null; echo "${NAME:-Debian}")"
    ver="$(. /etc/os-release 2>/dev/null; echo "${VERSION:-}")"
    fecha="$(date '+%Y-%m-%d %H:%M:%S')"

    # Mensaje (podés personalizarlo)
    local msg="\
Script de Instalación \"Clipito Shell - Arch\"
y Software para Arch Linux - 64 Bits y derivadas.

youtube.com/@LinuxenCasa
https://github.com/jcgamingonlinux/clipito-shell
Script by Gabriel Parri - gabeeOS Linux
JC Gaming On Linux - fork, mejoras y testeo, asistido por JC IA

Sistema Operativo:  ${distro} ${ver}
Usuario: ${user}   ---   Equipo: ${host}
Fecha: ${fecha}

Este script de instalación:
  • Instala Wayland Compositors / Display Managers seleccionados.
  • Aplica configuración de Clipito Shell y dotfiles de (Hyprland/Niri/Sway WM), si corresponde.
  • Ofrece paquetes y extras opcionales (incluye Flatpak y Fuentes Nerd Fonts)

Registro de instalación:  ${LOGFILE}

¿Deseas continuar?"

    # Cuadro con Sí/No
    # if/else directo (no "if [[ $? -ne 0 ]]" a la línea siguiente): con
    # set -e, un dialog suelto que devuelve 1 (No) mataría el script.
    if dialog --title "Instalador Arch - Bienvenida" \
           --yesno "$msg" 25 78; then
        :
    else
        # Si el usuario elige "No" o cancela, salimos
        clear
        echo "Instalación cancelada por el usuario."
        exit 0
    fi

    # (Opcional) mini pantalla de “Preparando…”
    dialog --title "Preparando" --infobox "Comprobando requisitos…" 5 50 || true
    sleep 1
}

#
##############################
#
##############################
#

##############################
# Restaurar backup de dotfiles
##############################

# Lista los ítems respaldados de un backup dado, leyendo el manifiesto que
# backup_if_exists / backup_system_if_exists escriben durante la instalación.
# Emite líneas:  tipo TAB ruta_original TAB ruta_en_backup
# No se reconstruye nada por profundidad de directorio: el manifiesto es la
# única fuente de verdad, así que cada ítem respaldado aparece siempre
# individualmente sin importar cuán anidado esté (p. ej. los archivos sueltos
# dentro de .config/quickshell/).
_backup_list_items() {
    local bdir="$1"
    local manifest="$bdir/.manifest"

    [[ -f "$manifest" ]] || return 0

    while IFS=$'\t' read -r tipo original entrada; do
        [[ -z "$tipo" ]] && continue
        printf '%s\t%s\t%s\n' "$tipo" "$original" "$entrada"
    done < "$manifest"
}


restore_backup() {
    local chosen_date="$1"
    local bdir="$HOME/.config-backup/$chosen_date"

    # Archivo temporal de índice: idx TAB tipo TAB destino TAB fuente
    local idx_file
    idx_file="$(mktemp /tmp/restore_idx.XXXXXX)"

    local items=()
    local idx=0

    while IFS=$'\t' read -r tipo original entrada; do
        printf '%s\t%s\t%s\t%s\n' "$idx" "$tipo" "$original" "$entrada" >> "$idx_file"
        items+=("$idx" "$original" "off")
        idx=$(( idx + 1 ))
    done < <(_backup_list_items "$bdir")

    if [[ ${#items[@]} -eq 0 ]]; then
        rm -f "$idx_file"
        dialog --title "Restaurar backup" \
               --msgbox "No se encontraron archivos en el backup:\n$bdir" 8 70 || true
        return 0
    fi

    # Checklist con todos los ítems del backup
    local selected
    # || {...}: con set -e, cancelar (rc=1) sin este guard mataría el script.
    selected=$(dialog --title "Restaurar backup: $chosen_date" \
        --checklist "Seleccioná los archivos/carpetas a restaurar\n(Espacio para marcar, Enter para confirmar):" \
        22 78 15 \
        "${items[@]}" \
        3>&1 1>&2 2>&3) || { rm -f "$idx_file"; return 0; }

    # Confirmación antes de sobreescribir
    # if/else directo (no "if [[ $? -ne 0 ]]" a la línea siguiente): con
    # set -e, un dialog suelto que devuelve 1 (No) mataría el script.
    if dialog --title "Confirmar restauración" \
           --yesno "¿Restaurar los archivos seleccionados?\nSe sobreescribirá el contenido actual." \
           8 60; then
        :
    else
        rm -f "$idx_file"
        return 0
    fi

    local ok=0 fail=0
    for sel in $selected; do
        sel="${sel//\"/}"

        local line
        line=$(grep -m1 "^${sel}"$'\t' "$idx_file" 2>/dev/null)
        [[ -z "$line" ]] && continue

        local tipo original src
        IFS=$'\t' read -r _ tipo original src <<< "$line"
        local dest_parent
        dest_parent="$(dirname "$original")"

        if [[ "$tipo" == "user" ]]; then
            mkdir -p "$dest_parent"
            # Si ya existe algo en destino, renombrarlo con sufijo .prev
            [[ -e "$original" ]] && mv "$original" "${original}.prev_$(date +%H%M%S)"
            if cp -a "$src" "$original"; then
                echo "  [restaurado] $original"
                ok=$(( ok + 1 ))
            else
                echo "  [error] No se pudo restaurar $original"
                fail=$(( fail + 1 ))
            fi
        else
            sudo mkdir -p "$dest_parent"
            if sudo cp -a "$src" "$original"; then
                echo "  [restaurado-system] $original"
                ok=$(( ok + 1 ))
            else
                echo "  [error] No se pudo restaurar $original"
                fail=$(( fail + 1 ))
            fi
        fi
    done

    rm -f "$idx_file"

    dialog --title "Restauración completada" \
           --msgbox "Restaurados: $ok archivo(s).\nErrores: $fail.\n\nRevisa la terminal para ver el detalle." \
           10 60 || true
}


show_restore_menu() {
    local backupbase="$HOME/.config-backup"

    if [[ ! -d "$backupbase" ]]; then
        dialog --title "Restaurar backup" \
               --msgbox "No existe el directorio de backups:\n$backupbase\n\nAún no se ha realizado ninguna instalación con backup." \
               10 70 || true
        return 0
    fi

    # Fechas disponibles en orden cronológico inverso (más reciente primero)
    local dates=()
    while IFS= read -r d; do
        [[ -n "$d" ]] && dates+=("$d")
    done < <(ls -1r "$backupbase" 2>/dev/null)

    if [[ ${#dates[@]} -eq 0 ]]; then
        dialog --title "Restaurar backup" \
               --msgbox "No hay backups disponibles en:\n$backupbase" \
               8 60 || true
        return 0
    fi

    # Construir opciones para --menu con conteo de archivos
    local menu_items=()
    for d in "${dates[@]}"; do
        local n
        n=$(find "$backupbase/$d" -mindepth 1 \( -type f -o -type l \) 2>/dev/null | wc -l)
        menu_items+=("$d" "${n} archivo(s) respaldado(s)")
    done

    local chosen
    # || return 0: con set -e, cancelar (rc=1) sin este guard mataría el
    # script; así "Cancelar" vuelve al menú principal.
    chosen=$(dialog --title "Restaurar backup" \
        --menu "Seleccioná la fecha del backup a restaurar:" \
        20 78 10 \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3) || return 0

    restore_backup "$chosen"
}

main() {
    load_state
    ensure_dialog
    ensure_git
    check_virtual

# Mostrar pantalla de bienvenida
    show_welcome


    while true; do

        # versión con "restore" incluida
        action=$(dialog --title "Menú Principal" --menu "Selecciona una opción:" 20 78 7 \
            "wm" "Window Manager a instalar" \
            "software" "Pack de Software" \
            "apps" "Aplicaciones Adicionales" \
            "dm" "Display Manager a instalar" \
            "summary" "Resumen de la configuración" \
            "restore" "Restaurar backup de dotfiles" \
            "leeme" "Instrucciones - leeme!" \
            "install" "Instálalo $USER, instálalo!" \
            3>&1 1>&2 2>&3) || exit 0

#         # versión sin "restore"
#         action=$(dialog --title "Menú Principal" --menu "Selecciona una opción:" 20 78 7 \
#             "wm" "Window Manager a instalar" \
#             "software" "Pack de Software" \
#             "apps" "Aplicaciones Adicionales" \
#             "dm" "Display Manager a instalar" \
#             "summary" "Resumen de la configuración" \
#             "leeme" "Instrucciones - leeme!" \
#             "install" "Instálalo $USER, instálalo!" \
#             3>&1 1>&2 2>&3) || exit 0

        case "$action" in
            wm) show_wm_menu ;;
            *)
                # Sin WM seleccionado, las demás secciones avisan que falta
                # el WM y, tras Aceptar, vuelven al menú principal.
                if ! wm_selected; then
                    dialog --title "Falta el Window Manager" --msgbox \
                        "Todavía no seleccionaste ningún Window Manager.\n\nVole al menú principal y elegí primero el WM (opción 1) antes de continuar." \
                        12 70 || true
                    continue
                fi
                case "$action" in
                    software) show_software_menu ;;
                    apps) show_apps_menu ;;
                    dm) show_dm_menu ;;
                    summary) show_summary ;;
                    restore) show_restore_menu ;;
                    leeme) show_leeme_menu ;;
                    install) install_selected; exit 0 ;;
                esac
                ;;
        esac
    done

}

# si se cancela la instalación no funciona hacer un clear pues 14 líneas más arriba se cambia
# el orden de las salidas y entradas estandar.
# así que aqui dejo varios "echos" para que al menos el cursor quede al final de la pantalla.

for num in {1..10}
do
	echo .
	echo ..
	echo ...
done

main "$@"

