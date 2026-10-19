#!/usr/bin/env bash
set -euo pipefail

####################
# Advertencia - Versión en pruebas -
# Agradecemos la revisión y los comentarios

# Script integrado para instalación y configuración de "Clipito Shell" en Linux Debian 13 Trixie
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
animate_text "      Clipito Shell - Trixie"
animate_text "###################################"
sleep 0.2
echo "Script integrado para instalación y"
echo "configuración de Wayland Compositors"
echo "en Debian GNU/Linux 13 Trixie"
echo "QuickShell by Claude Code"
animate_text "------------------------------------"
animate_text "https://www.youtube.com/@LinuxenCasa"
animate_text "------------------------------------"
sleep 0.2
echo "Se mostrará un menú hecho con Dialog"
echo "que debo instalar si es que no está"
echo "instalado."
echo "####################################"
echo "Advertencia:  Script en Pruebas."
echo "####################################"
animate_text "."
animate_text ".."
animate_text "..."
sleep 0.2

# Verificar si apt está instalado
    if ! command -v apt &> /dev/null; then
        echo -e "ERROR: No se detecta comando apt - esta distro no está basada en Debian."
	animate_text "Bye, bye..."
	sleep 0.5
        exit 0
    fi


TRIXIE_DETECTADO="no"
#
if [ -f "/etc/os-release" ]; then
	if grep -q "trixie" /etc/os-release; then
		TRIXIE_DETECTADO="si"
	fi
fi


if [[ "$TRIXIE_DETECTADO" == "no" ]]; then
		animate_text "No se detecta la Distro Linux Debian 13 Trixie."
        animate_text "Si estás seguro que esta distro está basada en"
        animate_text "Debian 13 Trixie, puedes continuar."
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
REPOURL="https://github.com/jcgamingonlinux/clipito-shell.git"
# REPOURL="git@github.com:jcgamingonlinux/clipito-shell.git"
REPOLOCAL="/tmp/clipito-shell"

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
	    curl
	    gpg
        desktop-base
        fastfetch
        ffmpeg
        firefox-esr
        gvfs
        gvfs-backends
        gvfs-fuse
        lxpolkit
        mtp-tools
        network-manager-applet
        pavucontrol
        playerctl
        pulseaudio-utils
        synaptic
        thunar
        unrar-free
        xdg-user-dirs
        xfce4-screenshooter
        xorg
        xterm
    )

    pkgs_base_backports=(
        pipewire
        pipewire-alsa
        pipewire-pulse
        wireplumber
        gdebi
    )

#################################################
    # Paquetes exclusivos del nivel intermedio (se suman a pkgs_base)
    pkgs_extra_intermedio=(
        btm
        btop
        htop
        hunspell-es
        libreoffice
        libreoffice-gtk3
        libreoffice-gtk4
        libreoffice-l10n-es
        mousepad
        mpv
        nuspell
        ristretto
        sayonara
        transmission
        vim
        wget
    )


    pkgs_extra_intermedio_backports=(
        evince
    )


#################################################
    # Paquetes exclusivos del nivel full (se suman a pkgs_base + pkgs_extra_intermedio)
    pkgs_extra_full=(
        audacity
        build-essential
        cava
        cmatrix
        devscripts
        fonts-font-awesome
        fonts-roboto
        gnumeric
        gparted
        inkscape
        inxi
        mediainfo
        neovim
        openshot-qt
        remmina
        remmina-plugin-spice
        sox
        vlc
    )


    pkgs_extra_full_backports=(
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
	    breeze-gtk-theme
	    curl
	    desktop-base
        fastfetch
        ffmpeg
	    fonts-font-awesome
	    fonts-noto-color-emoji
        git
        gparted
	    gpg
        gvfs
        gvfs-backends
        gvfs-fuse
	    imagemagick
	    libnotify-bin
        lxpolkit
        mtp-tools
        network-manager-gnome
	    network-manager-applet
	    nwg-look
        pavucontrol
        playerctl
	    qt-style-kvantum-themes
	    quickshell
        synaptic
	    sound-theme-freedesktop
	    swaylock
        thunar
        unrar-free
	    vim
        wlr-randr
	    xdg-user-dirs
        xwayland
        yad
       	zenity
    )


    pkgs_wm_wayland_backports=(
	nwg-displays
	pipewire
	pipewire-alsa
	pipewire-pulse
	wireplumber
)


################################################################################
# funciones
################################################################################
#
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

instalar_backports() {

    ############################################
    # repositorios de backports
    backup_system_if_exists "/etc/apt/sources.list.d/trixie-backports.list"

    # crear directorio sources.list.d  en caso que no exista
    if [ ! -d "/etc/apt/sources.list.d" ]; then
	    sudo mkdir -p /etc/apt/sources.list.d
    fi


    if ! apt-cache policy | grep -q backports; then
	    if [ ! -f "/etc/apt/sources.list.d/trixie-backports.list" ]; then
		    echo "deb http://deb.debian.org/debian trixie-backports main" |   sudo tee /etc/apt/sources.list.d/trixie-backports.list
	    else
		    echo "deb http://deb.debian.org/debian trixie-backports main" |   sudo tee /etc/apt/sources.list.d/trixie-backports-2.list
            fi

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
#     [niri]="NIRI (Scroll Wayland C.)"
    [sway]="Sway WM (wayland C.)"
)

declare -A SOFTWARE_DESC=(
    [basico]="Básico - (Thunar, Firefox ...)"
    [intermedio]="Intermedio - (LibreOffice, mpv ...)"
    [full]="Full - Todo el BloatWare de Paquetes"
)

declare -A APPS_DESC=(
#     [scrcpy]="scrcpy (screen mirroring)"
#     [virt-manager]="Virt-Manager (virtualization)"
    [flatpak]="flatpak - flathub"
    [nerdfonts-jbm]="JetBrainsMono Nerd Font (ligero)"
    [nerdfonts-all]="Nerd Fonts (todas ~1.2 GB)"
)

declare -A DM_DESC=(
#     [lightdm]="LightDM"
    [sddm]="SDDM theme-maui - Recomendado"
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
        sudo DEBIAN_FRONTEND=noninteractive apt-get update -yq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq dialog || {
            echo "No se pudo instalar 'dialog'. Abortando."; exit 1;
        }
    fi
}

# Asegurar que 'git' esté instalado antes de usarlo
ensure_git() {
    if ! command -v git >/dev/null 2>&1; then
        echo "El paquete 'git' no está instalado. Instalando…"
        check_internet
        sudo DEBIAN_FRONTEND=noninteractive apt-get update -yq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq git || {
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
            [[ -v WM_DESC[$k] ]] && SEL_WM[$k]=$v
#         elif [[ $k == software_* ]]; then
#             k=${k#software_}
#             [[ -v SOFTWARE_DESC[$k] ]] && SEL_SOFTWARE[$k]=$v
        elif [[ $k == apps_* ]]; then
            k=${k#apps_}
            [[ -v APPS_DESC[$k] ]] && SEL_APPS[$k]=$v
        elif [[ $k == flatpak_* ]]; then
            k=${k#flatpak_}
            [[ -v FLATPAK_DESC[$k] ]] && SEL_FLATPAK[$k]=$v
#         elif [[ $k == dm_* ]]; then
#             k=${k#dm_}
#             [[ -v DM_DESC[$k] ]] && SEL_DM[$k]=$v
        fi
    done < "$STATE_FILE"
}

save_state() {
    : > "$STATE_FILE"
    for k in "${!WM_DESC[@]}"; do printf 'wm_%s=%d\n' "$k" "${SEL_WM[$k]}" >> "$STATE_FILE"; done
    for k in "${!SOFTWARE_DESC[@]}"; do printf 'software_%s=%d\n' "$k" "${SEL_SOFTWARE[$k]}" >> "$STATE_FILE"; done
    for k in "${!APPS_DESC[@]}"; do printf 'apps_%s=%d\n' "$k" "${SEL_APPS[$k]}" >> "$STATE_FILE"; done
    for k in "${!DM_DESC[@]}"; do printf 'dm_%s=%d\n' "$k" "${SEL_DM[$k]}" >> "$STATE_FILE"; done
    for k in "${!FLATPAK_DESC[@]}"; do printf 'flatpak_%s=%d\n' "$k" "${SEL_FLATPAK[$k]}" >> "$STATE_FILE"; done
}

# Menús interactivos con dialog

show_wm_menu() {
    local items=()

    for k in "${!WM_DESC[@]}"; do
        local flag="off"; [[ ${SEL_WM[$k]} -eq 1 ]] && flag="on"
        items+=("$k" "${WM_DESC[$k]}" "$flag")
    done

    local out
    out=$(dialog --title "Wayland Compositors" \
        --checklist "Seleccioná WCs (Espacio para marcar, Enter para confirmar):" \
        20 78 10 \
        "${items[@]}" \
        3>&1 1>&2 2>&3) || return 0

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
    for k in "${!SOFTWARE_DESC[@]}"; do
        local flag="off"; [[ ${SEL_SOFTWARE[$k]} -eq 1 ]] && flag="on"
        items+=("$k" "${SOFTWARE_DESC[$k]}" "$flag")
    done

    local out
    out=$(dialog --title "Paquetes de Software" \
        --radiolist "Seleccioná un Pack de Software (Espacio para marcar, Enter para confirmar):" \
        20 78 10 \
        "${items[@]}" \
        3>&1 1>&2 2>&3) || return 0

    # Si no se eligió nada (poco probable en radiolist), no toco el estado previo
    [[ -z "$out" ]] && return 0

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
    for k in "${!FLATPAK_DESC[@]}"; do
        local flag="off"; [[ ${SEL_FLATPAK[$k]} -eq 1 ]] && flag="on"
        items+=("$k" "${FLATPAK_DESC[$k]}" "$flag")
    done

    local out
    out=$(dialog --title "Apps Flatpak (Flathub)" \
        --checklist "Seleccioná las apps Flatpak a instalar (Espacio para marcar, Enter para confirmar):" \
        20 78 10 \
        "${items[@]}" \
        3>&1 1>&2 2>&3) || return 0

    for k in "${!FLATPAK_DESC[@]}"; do SEL_FLATPAK[$k]=0; done
    for c in $out; do
        c="${c//\"/}"
        [[ -v FLATPAK_DESC[$c] ]] && SEL_FLATPAK[$c]=1
    done
    save_state
}


show_apps_menu() {
    local items=()
    for k in "${!APPS_DESC[@]}"; do
        local flag="off"; [[ ${SEL_APPS[$k]} -eq 1 ]] && flag="on"
        items+=("$k" "${APPS_DESC[$k]}" "$flag")
    done

    local out
    out=$(dialog --title "Aplicaciones Adicionales" \
        --checklist "Seleccioná aplicaciones (Espacio para marcar, Enter para confirmar):" \
        20 78 10 \
        "${items[@]}" \
        3>&1 1>&2 2>&3) || return 0

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
    for k in "${!DM_DESC[@]}"; do
        local flag="off"; [[ ${SEL_DM[$k]} -eq 1 ]] && flag="on"
        items+=("$k" "${DM_DESC[$k]}" "$flag")
    done

    local out
    out=$(dialog --title "Display Managers" \
        --radiolist "Seleccioná uno o varios DMs (Espacio para marcar, Enter para confirmar):" \
        20 78 10 \
        "${items[@]}" \
        3>&1 1>&2 2>&3) || return 0

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
    dialog --title "Resumen" --msgbox "$summary" 20 78
}


show_leeme_menu() {

    local msg="\

Script de Instalación \"Clipito Shell - Trixie\"
y Software para Debian GNU/Linux 13/Trixie - 64 Bits.

youtube.com/@LinuxenCasa
https://github.com/jcgamingonlinux/clipito-shell
Script by Gabriel Parri - gabeeOS Linux.

Agradecimientos a Johan David M. por la compilación de los
paquetes de quickshell y niri.

Importante:
Este script está ajustado para la distribución
Debian GNU/Linux 13 Trixie.
Podría funcionar en otra distro siempre y cuando
esté basada en Trixie con systemd.

Instalar por lo menos la fuente JetBrains Mono Nerd Font
que es la fuente que se usa por defecto en esta configuración.

Más detalles en el repositorio:
https://github.com/jcgamingonlinux/clipito-shell"



    dialog --title "Instrucciones - Leeme" --msgbox "$msg" 20 78

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
    sudo apt update
    check_error "No se pudo actualizar el índice de paquetes." || exit 1
    sudo apt upgrade -y
    check_error "No se pudo actualizar el sistema." || exit 1


    #############################################
    # Instalo el pack de software.

    # Instalar paquetes de software según selección
    for k in "${!SOFTWARE_DESC[@]}"; do
        if [[ ${SEL_SOFTWARE[$k]} -eq 1 ]]; then
            instalar_backports
            sudo apt update
            echo ">> Instalando paquete $k..."
            case "$k" in
                basico)
                    sudo apt install -y "${pkgs_base[@]}"
                    sudo apt install -y -t trixie-backports "${pkgs_base_backports[@]}"
                    check_error "No se pudieron instalar las aplicaciones básicas." || exit 1
                    ;;
                intermedio)
                    sudo apt install -y "${pkgs_base[@]}" "${pkgs_extra_intermedio[@]}"
                    sudo apt install -y -t trixie-backports "${pkgs_base_backports[@]}" "${pkgs_extra_intermedio_backports[@]}"
                    check_error "No se pudieron instalar las aplicaciones intermedias." || exit 1
                    ;;
                full)
                    sudo apt install -y "${pkgs_base[@]}" "${pkgs_extra_intermedio[@]}" "${pkgs_extra_full[@]}"
                    sudo apt install -y -t trixie-backports "${pkgs_base_backports[@]}" "${pkgs_extra_intermedio_backports[@]}" "${pkgs_extra_full_backports[@]}"
                    check_error "No se pudieron instalar las aplicaciones completas." || exit 1
                    ;;
            esac

        fi
    done

    #############################################

    # descargar los dot-files del repo de gitlab
    # lo descargo en /tmp para que no haya problemas con el directorio actual

    echo "Descargando configuraciones desde GitLab..."
    # borro el subdrectorio si es que ya existe
    #
    if [ -d "$REPOLOCAL" ]; then
        echo "borrando directorio"
        sudo rm -rf "$REPOLOCAL"
    fi

    cd /tmp
    # clonar explícitamente al destino esperado
    git clone "$REPOURL" "$REPOLOCAL" || { echo "Error: No se pudo clonar el repositorio de dotfiles."; exit 1; }


################################################
################################################
#
# crear los directorios y copiar los archivos comunes a todos los Wayland Compositors

    # Instalar paquetes básicos para los Wayland Compositors
    if [[ ${SEL_WM[hyprland]} -eq 1  || \
          ${SEL_WM[sway]} -eq 1 ]]; then


    instalar_backports
    sudo apt update
    # Esto resuelve el conflicto de paquetes desde backports
    # en caso que no se seleccione ningún paquete de software
    sudo apt install -y -t trixie-backports pipewire \
                    pipewire-bin \
                    pipewire-alsa \
                    libpipewire-0.3-0t64 \
                    libpipewire-0.3-modules
    sudo apt install -y -t trixie-backports gir1.2-atk-1.0 libatk1.0-0t64

    sudo apt install -y -t trixie-backports quickshell


    # Crear directorios necesarios para los dot-files y archivos de configuracion
    for dir in "$HOME/.config" "$HOME/.local" "$HOME/.local/share" "$HOME/.local/src" \
               "/usr/share/wallpapers" "/etc/apt/sources.list.d" "$HOME/.config/quickshell" \
	       "$HOME/.local/share/icons" "/usr/local/bin" "$HOME/wallpapers"; do
        if [ ! -d "$dir" ]; then
            if [[ "$dir" == /usr/* || "$dir" == /etc/apt/sources.list.d ]]; then
                sudo mkdir -p "$dir"
                check_error "No se pudo crear el directorio $dir." || exit 1
            else
                mkdir -p "$dir"
                check_error "No se pudo crear el directorio $dir." || exit 1
            fi
        fi
    done

    cd $REPOLOCAL/.config/
    backup_if_exists "$HOME/.config/gtk-3.0"
    cp -r gtk-3.0/ ~/.config/
    check_error "No se pudieron copiar los dotfiles a ~/.config." || exit 1
    cd $REPOLOCAL/usr/share/wallpapers/
    backup_system_if_exists "/usr/share/wallpapers/clipito-01.png"
    sudo cp clipito-01.png /usr/share/wallpapers/
    check_error "No se pudo copiar el fondo de pantalla a /usr/share/wallpapers." || exit 1

    ###############################

    echo "Instalando paquetes básicos para WM con Wayland..."
    sudo apt install -y "${pkgs_wm_wayland_backports[@]}"
    sudo apt install -y "${pkgs_wm_wayland[@]}"
    check_error "No se pudieron instalar los paquetes básicos." || exit 1

    for dir in "$HOME/.config" "$HOME/.local" "$HOME/.local/share" \
               "/usr/share/wallpapers" "/usr/share/wayland-sessions" "/usr/local/bin"; do
        if [ ! -d "$dir" ]; then
            if [[ "$dir" == /usr/* ]]; then
                sudo mkdir -p "$dir"
                check_error "No se pudo crear el directorio $dir." || exit 1
            else
                mkdir -p "$dir"
                check_error "No se pudo crear el directorio $dir." || exit 1
            fi
        fi
    done


    # Crear directorios del home del usuario
    echo "Creando directorios del home del usuario..."
    xdg-user-dirs-update

            # configurar permisos para abrir algunas apps como gparted

		    echo 'Defaults env_keep += "XDG_RUNTIME_DIR WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS"' | sudo tee /etc/sudoers.d/waylandenv
                    sudo chmod 440 /etc/sudoers.d/waylandenv

		    pkgs_sway_wayland_gui=(
                        gparted
                        synaptic
                    )
            sudo apt install -y "${pkgs_sway_wayland_gui[@]}"
		    # configurar para que synaptic y gparted se lancen
		    # usando zenity y paso a paso de G. Parri
		    sudo mkdir -p /usr/local/share/applications/
		    cd $REPOLOCAL/usr/local/share/applications/
		    backup_system_if_exists "/usr/local/share/applications/gparted-wayland.desktop"
		    backup_system_if_exists "/usr/local/share/applications/synaptic-wayland.desktop"
		    sudo cp gparted-wayland.desktop synaptic-wayland.desktop /usr/local/share/applications/
		    cd $REPOLOCAL/usr/local/bin/
		    backup_system_if_exists "/usr/local/bin/askpass-zenity"
		    backup_system_if_exists "/usr/local/bin/gparted-xwl"
		    backup_system_if_exists "/usr/local/bin/synaptic-xwl"
		    sudo cp askpass-zenity gparted-xwl synaptic-xwl /usr/local/bin/


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
    cp bar-layout.tsv launcher-size.txt wallpaper-fillmode.txt wallpaper-path.txt ~/.config/quickshell
    check_error "No se pudieron copiar los archivos de configuracion del WC de quickshell" || exit 1
    cp $REPOLOCAL/wallpapers/clipito-01.png ~/wallpapers
    check_error "No se pudieron copiar los archivos de configuracion del WC de quickshell" || exit 1


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
			xdg-desktop-portal-hyprland
			xdg-desktop-portal-gtk
                    )
                    sudo apt install -t trixie-backports -y "${pkgs_hyprland[@]}"
                    check_error "No se pudo instalar hyprland" || exit 1

                    backup_if_exists "$HOME/.config/hypr"

                    if [ -d "$HOME/.config/hypr" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/hypr"
                    fi

                    cd $REPOLOCAL/.config/debian-dotfiles
                    cp -r hypr/ $HOME/.config/
                    check_error "No se pudieron copiar los dotfiles a ~/.config." || exit 1

                    backup_if_exists "$HOME/.config/quickshell/hyprland-bar"

                    if [ -d "$HOME/.config/quickshell/hyprland-bar" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/quickshell/hyprland-bar"
                    fi

		            cp -r $REPOLOCAL/.config/quickshell/hyprland-bar/ $HOME/.config/quickshell/hyprland-bar
                    check_error "No se pudieron copiar los dotfiles a ~/.config." || exit 1

                    ;;


                niri)
                    pkgs_niri=(
                        alacritty
                       	xdg-desktop-portal-gtk
                        xwayland-satellite
                    )
                    sudo apt install -y "${pkgs_niri[@]}"
		            # esto me instala gdm y detiene la instalación pues ya está sddm
		            # sudo apt install -y --no-install-recommends xdg-desktop-portal-gnome
		            sudo apt install -y --no-install-recommends niri
                    check_error "No se pudo instalar niri" || exit 1


                    backup_if_exists "$HOME/.config/niri"

                    if [ -d "$HOME/.config/niri" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/niri"
                    fi

                    cd $REPOLOCAL/.config/debian-dotfiles
                    cp -r niri/ $HOME/.config/
                    check_error "No se pudieron copiar los dotfiles a ~/.config." || exit 1

                    backup_if_exists "$HOME/.config/quickshell/niri-bar"

                    if [ -d "$HOME/.config/quickshell/niri-bar" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/quickshell/niri-bar"
                    fi

		            cp -r $REPOLOCAL/.config/quickshell/niri-bar/ $HOME/.config/quickshell/niri-bar
                    check_error "No se pudieron copiar los dotfiles a ~/.config." || exit 1


                    ;;

                sway)
                    pkgs_sway=(
                        foot
                        sway
                        sway-backgrounds
                        x11-xserver-utils
			xdg-desktop-portal-gtk
                        xdg-desktop-portal-wlr
                    )
                    sudo apt install -y "${pkgs_sway[@]}"
                    check_error "No se pudo instalar sway." || exit 1

                    backup_if_exists "$HOME/.config/sway"

                    if [ -d "$HOME/.config/sway" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/sway"
                    fi

                    cd $REPOLOCAL/.config/debian-dotfiles
                    cp -r sway/ $HOME/.config/
                    check_error "No se pudieron copiar los dotfiles a ~/.config." || exit 1

                    backup_if_exists "$HOME/.config/quickshell/sway-bar"

                    if [ -d "$HOME/.config/quickshell/sway-bar" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.config/quickshell/sway-bar"
                    fi

		            cp -r $REPOLOCAL/.config/quickshell/sway-bar/ $HOME/.config/quickshell/sway-bar
                    check_error "No se pudieron copiar los dotfiles a ~/.config." || exit 1


                    if [[ "$MAQUINA_VIRTUAL" == "si" ]]; then
                            if [ -f "/usr/share/wayland-sessions/sway.desktop" ]; then
				    sudo rm -r /usr/share/wayland-sessions/sway.desktop
				    cd $REPOLOCAL/usr/share/wayland-sessions
				    backup_system_if_exists "/usr/share/wayland-sessions/sway.desktop"
				    sudo cp sway.desktop /usr/share/wayland-sessions/
				fi
                    fi

                    check_error "No se pudieron copiar los dotfiles a ~/.config." || exit 1
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
                    sudo DEBIAN_FRONTEND=noninteractive apt install -y lightdm lightdm-gtk-greeter
                    # check_error "No se pudo instalar LightDM." || exit 1
		    sudo systemctl enable --force lightdm.service
                    # check_error "No se pudo activar LightDM." || exit 1
                    ;;

                sddm)
                    sudo DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends sddm sddm-theme-maui
                    # check_error "No se pudo instalar SDDM." || exit 1
		    sudo systemctl enable --force sddm.service
                    # check_error "No se pudo activar SDDM." || exit 1
                    ;;

                ly)

                    if [ -d "/tmp/ly" ]; then
                        echo "borrando directorio temporal de ly"
                        sudo rm -rf "/tmp/ly"
                    fi

                    sudo apt install -y build-essential libpam0g-dev libxcb-xkb-dev xauth \
			                xserver-xorg brightnessctl git wget
                    cd /tmp
                    wget https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz

                    sudo tar -xvf zig-x86_64-linux-0.16.0.tar.xz -C /opt
                    git clone https://codeberg.org/fairyglade/ly.git
                    cd /tmp/ly/
                    /opt/zig-x86_64-linux-0.16.0/zig build
                    sudo /opt/zig-x86_64-linux-0.16.0/zig build installexe
                    sudo systemctl enable --force ly@tty2.service
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
                scrcpy)
                    sudo apt install -y libsdl2-2.0-0 adb wget gcc git pkg-config meson ninja-build \
                        libsdl2-dev libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev \
                        libswresample-dev libusb-1.0-0 libusb-1.0-0-dev
                    check_error "No se pudieron instalar las dependencias de scrcpy." || exit 1

                    # borro archivos de scrcpy si existen
                    if [ -d "$HOME/.local/src/scrcpy" ]; then
                        echo "borrando directorio"
                        sudo rm -rf "$HOME/.local/src/scrcpy"
                    fi

                    cd ~/.local/src/
                    if ! git clone https://github.com/Genymobile/scrcpy; then
                        echo "Error: No se pudo clonar el repositorio de scrcpy."
                        exit 1
                    fi
                    cd scrcpy/
                    ./install_release.sh
                    check_error "No se pudo instalar scrcpy." || exit 1
                    cd
                    ;;
                virt-manager)
                    sudo apt install -y qemu-system virt-manager libvirt-daemon-system virt-viewer
                    check_error "No se pudo instalar virt-manager." || exit 1
		    sudo adduser $USER libvirt
                    ;;

                flatpak)
                # Instalar flatpak y agregar Flathub
                sudo apt install -y flatpak
                check_error "No se pudo instalar flatpak." || exit 1

                # Agregar remoto flathub si no existe (modo sistema)
                flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
                check_error "No se pudo añadir el repositorio Flathub." || exit 1

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


                 nerdfonts-jbm)
                    if [[ "$INSTALL_ALL_NF" -eq 1 ]]; then
                        echo "Saltando JetBrainsMono Nerd Font (ligero): seleccionaste 'Nerd Fonts (todas)'."
                    else
                        echo "Instalando JetBrainsMono Nerd Font (ligero)…"
                        sudo apt install -y unzip fontconfig curl ca-certificates || {
                            echo "No se pudieron instalar dependencias (unzip/fontconfig/curl)."; exit 1; }
                        tmpd="$(mktemp -d)"; cd "$tmpd"
                        JBM_ZIP_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
                        if ! curl -fL --retry 3 --retry-delay 2 -o JetBrainsMono.zip "$JBM_ZIP_URL"; then
                            echo "Error: no se pudo descargar JetBrainsMono.zip desde Nerd Fonts releases."
                            exit 1
                        fi
                        mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerd"
                        unzip -oq JetBrainsMono.zip -d "$HOME/.local/share/fonts/JetBrainsMonoNerd"
                        fc-cache -f || true
                        cd "$HOME"
                        echo "JetBrainsMono Nerd Font instalada en ~/.local/share/fonts/JetBrainsMonoNerd"
                    fi
                    ;;


               nerdfonts-all)
                    echo "Instalando TODAS las Nerd Fonts (~1.2 GB)…"

                    # Dependencias mínimas
                    sudo apt install -y git unzip fontconfig curl ca-certificates || {
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

    dialog --title "Instalación" --msgbox "Instalación completada. Por favor, cierra sesión o reinicia para aplicar los cambios. Selecciona tu WM/DM en el gestor de inicio de sesión. Consulta $LOGFILE para detalles." 10 60
    exec > /dev/tty 2>&1
    clear   # <<< limpia la pantalla al terminar todo el proceso
}


# Pantalla de bienvenida (se muestra antes del menú)
show_welcome() {
    # Info útil para mostrar
    local host user distro ver fecha
    host="$(hostname)"
    user="$USER"
    distro="$(. /etc/os-release 2>/dev/null; echo "${NAME:-Debian}")"
    ver="$(. /etc/os-release 2>/dev/null; echo "${VERSION:-}")"
    fecha="$(date '+%Y-%m-%d %H:%M:%S')"

    # Mensaje (podés personalizarlo)
    local msg="\
Script de Instalación \"Clipito Shell - Trixie\"
y Software para Debian GNU/Linux 13/Trixie - 64 Bits.

youtube.com/@LinuxenCasa
https://github.com/jcgamingonlinux/clipito-shell
Script by Gabriel Parri - gabeeOS Linux

Sistema Operativo:  ${distro} ${ver}
Usuario: ${user}   ---   Equipo: ${host}
Fecha: ${fecha}

Este script de instalación:
  • Instala Wayland Compositors / Display Managers seleccionados.
  • Aplica configuración de Clipito Shell y dotfiles de (Hyprland/Niri/Sway WM), si corresponde.
  • Ofrece paquetes y extras opcionales (incluye Flatpak y Fuentes Nerd Fonts)

Registro de instalación:  ${LOGFILE}

Antes de continuar debes activar las líneas del código fuente
de los paquetes (empiezan por deb-src ) en /etc/apt/sources.list

¿Deseas continuar?"

    # Cuadro con Sí/No
    dialog --title "Instalador Trixie - Bienvenida" \
           --yesno "$msg" 25 78

    # Si el usuario elige "No" o cancela, salimos
    if [[ $? -ne 0 ]]; then
        clear
        echo "Instalación cancelada por el usuario."
        exit 0
    fi

    # (Opcional) mini pantalla de “Preparando…”
    dialog --title "Preparando" --infobox "Comprobando requisitos…" 5 50
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
               --msgbox "No se encontraron archivos en el backup:\n$bdir" 8 70
        return 0
    fi

    # Checklist con todos los ítems del backup
    local selected
    selected=$(dialog --title "Restaurar backup: $chosen_date" \
        --checklist "Seleccioná los archivos/carpetas a restaurar\n(Espacio para marcar, Enter para confirmar):" \
        22 78 15 \
        "${items[@]}" \
        3>&1 1>&2 2>&3)
    local dlg_ret=$?

    if [[ $dlg_ret -ne 0 || -z "$selected" ]]; then
        rm -f "$idx_file"
        return 0
    fi

    # Confirmación antes de sobreescribir
    dialog --title "Confirmar restauración" \
           --yesno "¿Restaurar los archivos seleccionados?\nSe sobreescribirá el contenido actual." \
           8 60
    if [[ $? -ne 0 ]]; then
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
           10 60
}


show_restore_menu() {
    local backupbase="$HOME/.config-backup"

    if [[ ! -d "$backupbase" ]]; then
        dialog --title "Restaurar backup" \
               --msgbox "No existe el directorio de backups:\n$backupbase\n\nAún no se ha realizado ninguna instalación con backup." \
               10 70
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
               8 60
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
    chosen=$(dialog --title "Restaurar backup" \
        --menu "Seleccioná la fecha del backup a restaurar:" \
        20 78 10 \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3)
    local dlg_ret=$?

    [[ $dlg_ret -ne 0 || -z "$chosen" ]] && return 0

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
            software) show_software_menu ;;
            apps) show_apps_menu ;;
            dm) show_dm_menu ;;
            summary) show_summary ;;
            restore) show_restore_menu ;;
            leeme) show_leeme_menu ;;
            install) install_selected; exit 0 ;;
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

