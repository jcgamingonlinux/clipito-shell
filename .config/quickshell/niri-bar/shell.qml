//@ pragma UseQApplication
// Íconos de apps que no cargan ("display", "preferences-system-network",
// etc. -- ver README): probablemente no hay un tema de íconos configurado
// a nivel Qt en esta sesión (típico en niri/sway/Hyprland sin qt5ct/
// qt6ct). Para forzar uno instalado en el sistema, buscá el nombre EXACTO
// de la carpeta con "ls /usr/share/icons" (ej. Papirus, Adwaita, breeze) y
// activá la linea de abajo agregandole el "@" que le falta a proposito
// (asi queda inerte hasta que la edites vos):
// pragma IconTheme NOMBRE-DE-TU-TEMA
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./modules"

ShellRoot {

    // Fondo de pantalla: una ventana por monitor en la capa Background del
    // layer-shell, mostrando la imagen elegida en el selector (Wallpaper.current).
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bgWindow
            property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "black"

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // FIX: sin esto, el compositor calculaba el área del wallpaper
            // descontando el espacio reservado (exclusiveZone) de la barra
            // en el momento en que esta ventana se crea -- y no lo
            // reajustaba después si esa reserva cambiaba (ej. al
            // auto-ocultarse la barra), dejando un hueco del color de
            // fondo del compositor donde antes estaba la barra. -1 le dice
            // que ignore cualquier zona exclusiva ajena y ocupe siempre la
            // pantalla completa.
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.namespace: "niri-bar-wallpaper"

            Image {
                anchors.fill: parent
                source: Wallpaper.current.length > 0 ? "file://" + Wallpaper.current : ""
                // "fill" (default, antes hardcodeado): recorta manteniendo
                // proporción, llena toda la pantalla. "center": tamaño
                // original sin escalar, centrada (deja franjas del color de
                // fondo de esta ventana -- "black" -- si la imagen es más
                // chica que la pantalla). "stretch": estirada exacta a la
                // pantalla, sin mantener proporción.
                fillMode: Wallpaper.fillMode === "center" ? Image.Pad
                    : (Wallpaper.fillMode === "stretch" ? Image.Stretch : Image.PreserveAspectCrop)
                asynchronous: true
            }
        }
    }

    // Una barra por cada monitor conectado
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            property var modelData
            screen: modelData

            // Auto-ocultar: revealed controla tanto el desplazamiento visual
            // del contenido (ver Bar.qml) como el exclusiveZone reservado.
            // Se mantiene visible mientras el mouse esté encima o haya un
            // popup de esta barra abierto; si no, se repliega tras un rato.
            property bool revealed: true
            // Bridge.barForceHidden es compartido entre todas las pantallas
            // (ver Bridge.qml) -- lo setea el IPC "bar-visibility".
            readonly property bool effectivelyRevealed: revealed && !Bridge.barForceHidden

            function requestReveal() { hideTimer.stop(); revealed = true }
            function requestHideSoon() { if (BarConfig.autoHide) hideTimer.restart() }

            Timer {
                id: hideTimer
                interval: 1200
                onTriggered: {
                    if (BarConfig.autoHide && !barHover.hovered
                        && !(Bridge.anyPopupOpen && modelData.name === FocusedScreen.name))
                        barWindow.revealed = false
                }
            }

            // Si se abre un popup de esta barra mientras está oculta, se
            // vuelve a mostrar (los popups se anclan justo debajo/encima).
            property bool popupOpenHere: Bridge.anyPopupOpen && modelData.name === FocusedScreen.name
            // FIX: al cerrarse un popup (ej. Ajustes) hay que volver a
            // programar el ocultamiento -- antes solo se reaccionaba a que
            // se abriera (popupOpenHere == true), asi que tras cerrar un
            // popup el auto-ocultado quedaba "pausado" el resto de la sesion
            // (hasta reiniciar quickshell), porque nada volvia a arrancar el
            // hideTimer si el mouse ya no se movia sobre la barra.
            onPopupOpenHereChanged: {
                if (popupOpenHere) requestReveal()
                else requestHideSoon()
            }

            Connections {
                target: BarConfig
                function onAutoHideChanged() {
                    if (BarConfig.autoHide) barWindow.requestHideSoon()
                    else barWindow.requestReveal()
                }
            }

            Component.onCompleted: if (BarConfig.autoHide) requestHideSoon()

            anchors {
                top: !BarConfig.barAtBottom
                bottom: BarConfig.barAtBottom
                left: true
                right: true
            }

            // FIX: "color: transparent" no se estaba renderizando como
            // realmente transparente en Sway -- quedaba una franja gris
            // sólida del alto completo (34px) donde debería no verse nada.
            // En vez de depender de que esa transparencia funcione, la
            // ventana en sí se achica a ~2px cuando está oculta: haya o no
            // problema de canal alfa, lo que quede visible es mínimo. El
            // contenido (Bar) se sigue desplazando fuera de vista con el
            // transform de siempre, y como Wayland recorta la superficie a
            // su tamaño real, cualquier resto queda clippeado a esos 2px.
            implicitHeight: barWindow.effectivelyRevealed
                ? Scaling.pxFor(modelData.name, 34)
                : 1  // 1px fijo, sin escalar: si se escalara podría redondear a 0 a factores bajos
            // FIX: aunque el contenido (Bar) se desliza fuera de vista, la
            // ventana en sí seguía pintando este fondo oscuro a tamaño
            // completo -- por eso quedaba una franja opaca tapando lo que
            // hubiera debajo. Transparente cuando está oculta.
            color: barWindow.effectivelyRevealed ? "#1e1e2e" : "transparent"

            WlrLayershell.layer: WlrLayer.Top
            // Con auto-ocultar activo y la barra replegada, solo se reserva
            // una franja mínima (para que siga habiendo un borde detectable
            // por el mouse); revelada u ordinaria, reserva el alto completo.
            // FIX: antes reservaba 2px al ocultarse -- ese resto quedaba
            // sin poder usarse por otras ventanas. En 0 el compositor puede
            // usar el espacio completo; el detector de hover (HoverHandler de
            // mas abajo) sigue funcionando igual porque no depende del
            // exclusiveZone, solo de que la superficie siga ahi.
            WlrLayershell.exclusiveZone: barWindow.effectivelyRevealed ? Scaling.pxFor(modelData.name, 34) : 0
            WlrLayershell.namespace: "niri-bar"

            // Detector de hover fijo al borde de la ventana (no se mueve con
            // el transform del contenido), para poder "despertar" la barra
            // acercando el mouse aunque esté deslizada fuera de vista.
            HoverHandler {
                id: barHover
                onHoveredChanged: hovered ? barWindow.requestReveal() : barWindow.requestHideSoon()
            }

            Bar {
                anchors.fill: parent
                anchors.leftMargin: Scaling.pxFor(modelData.name, 8)
                anchors.rightMargin: Scaling.pxFor(modelData.name, 8)
                // 2px fijos (sin escalar) arriba/abajo -- deja al
                // contenido de la barra siempre un poco separado del borde
                // real de la ventana, para que no queden pixeles sueltos
                // (antialiasing de íconos/texto) asomando en la franja de
                // 1px cuando la barra está oculta.
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                screenName: modelData.name
                barWindow: barWindow
                revealed: barWindow.effectivelyRevealed
            }
        }
    }

    // Panel de configuración, accesible también con `quickshell ipc call bar-config toggle`.
    Variants {
        model: Quickshell.screens
        PanelWindow {
            property var modelData
            visible: Bridge.barConfigOpen && modelData.name === Bridge.barConfigScreen
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "niri-bar-config"
            // El fondo absorbe los clicks (para que no lleguen a las apps
            // de atrás) pero ya NO cierra el panel -- Ajustes tiene su
            // propio botón X y se pidió que solo se cierre con eso.
            MouseArea { anchors.fill: parent; onClicked: {} }
            BarConfigPopup { open: Bridge.barConfigOpen; onCloseRequested: Bridge.barConfigOpen = false; anchors.centerIn: parent; width: Math.max(Scaling.px(520), 480); height: Math.max(Scaling.px(620), 540) }
        }
    }
    IpcHandler { target: "bar-config"; function toggle(): void { Bridge.togglePopupFresh("barConfigOpen") } }

    // Atajo de teclado externo para prender/apagar el auto-ocultado de la
    // barra sin pasar por el panel de Ajustes:
    // `quickshell ipc call autohide toggle`
    IpcHandler {
        target: "autohide"
        function toggle(): void {
            BarConfig.autoHide = !BarConfig.autoHide
            BarConfig.save()
        }
    }

    // Ocultar/mostrar la barra a la fuerza, en todas las pantallas, sin
    // tocar la preferencia de auto-ocultado. Pensado para engancharse a
    // eventos del compositor -- ver el listener de fullscreen de Hyprland
    // en README.md -- pero sirve para cualquier script externo:
    //   quickshell ipc call bar-visibility hide
    //   quickshell ipc call bar-visibility show
    //   quickshell ipc call bar-visibility toggle
    IpcHandler {
        target: "bar-visibility"
        function hide(): void { Bridge.barForceHidden = true }
        function show(): void { Bridge.barForceHidden = false }
        function toggle(): void { Bridge.barForceHidden = !Bridge.barForceHidden }
    }

    // El listado de apps del launcher se escanea una sola vez por sesión
    // (ver AppList.qml). Si instalás algo nuevo y no querés esperar al
    // próximo login, podés forzar un re-escaneo a mano:
    //   quickshell ipc call app-list rescan
    IpcHandler {
        target: "app-list"
        function rescan(): void { AppList.rescan() }
    }

    // Cierra TODOS los popups de la barra (incluidos Wallpaper, Atajos y
    // Listado de ventanas, que viven en la capa "Overlay" -- por encima
    // de cualquier ventana normal, siempre, por protocolo). Pensado para
    // anteponerlo a herramientas como capturadores de pantalla que si no
    // quedan tapadas detrás:
    //   quickshell ipc call panic closeAll
    // Ejemplo de atajo de captura que cierra esto primero:
    //   sh -c "quickshell ipc call panic closeAll; sleep 0.05; xfce4-screenshooter"
    IpcHandler {
        target: "panic"
        function closeAll(): void { Bridge.closeTransientPopups() }
    }

    // Toasts de notificaciones (siempre montado; se muestra solo si hay activas)
    Variants {
        model: Quickshell.screens

            PanelWindow {
            id: toastWindow
            property var modelData
            visible: Notifications.active.length > 0 && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; right: true }
            margins.top: 36
            margins.right: 8

            implicitWidth: Scaling.px(320)
            implicitHeight: toastsContent.implicitHeight
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "niri-bar-toasts"

            NotificationToasts { id: toastsContent; anchors.fill: parent }
        }
    }

    // Historial de notificaciones (desplegable) — pantalla completa
    // transparente para poder cerrar al hacer click afuera, igual que
    // el launcher y el power menu.
    Variants {
        model: Quickshell.screens

            PanelWindow {
            id: notifCenterWindow
            property var modelData
            visible: Bridge.notificationsOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "niri-bar-notification-center"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.notificationsOpen = false
            }

            NotificationCenterPopup {
                open: Bridge.notificationsOpen

                // FIX: anchors.top/bottom no aceptan un booleano en un Item
                // normal (a diferencia de PanelWindow) -- esa asignacion fallaba
                // en silencio y el popup quedaba siempre pegado a y:0 (arriba),
                // sin importar la posicion real de la barra. Se reemplaza por un
                // y explicito calculado a partir de BarConfig.barAtBottom.
                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.notificationsX + BarPositions.notificationsWidth / 2 - width / 2), parent.width - width - 8)
                width: Scaling.px(320)
                height: Scaling.px(360)
            }
        }
    }

    // --- Launcher #1: abierto con click en el botón Menu, arriba a la izquierda ---
    // Ventana a pantalla completa (transparente) para poder detectar clicks
    // "afuera" del launcher y cerrarlo; el contenido real se posiciona con
    // anchors dentro de esta ventana.
    Variants {
        model: Quickshell.screens

            PanelWindow {
            id: menuLauncherWindow
            property var modelData
            visible: Bridge.menuLauncherOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "niri-bar-launcher-menu"

            // Fondo: cualquier click fuera del launcher lo cierra
            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.menuLauncherOpen = false
            }

            LauncherPopup {
                open: Bridge.menuLauncherOpen
                onCloseRequested: Bridge.menuLauncherOpen = false
                showPowerButtons: true
                resizable: true

                // FIX: anchors.top/bottom no aceptan un booleano en un Item
                // normal (a diferencia de PanelWindow) -- esa asignacion fallaba
                // en silencio y el popup quedaba siempre pegado a y:0 (arriba),
                // sin importar la posicion real de la barra. Se reemplaza por un
                // y explicito calculado a partir de BarConfig.barAtBottom.
                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.menuX + BarPositions.menuWidth / 2 - width / 2), parent.width - width - 8)
                initialWidth: Scaling.px(420)
                initialHeight: Scaling.px(952)
            }
        }
    }

    // --- Launcher #2: abierto con el atajo de teclado, centrado en pantalla ---
    Variants {
        model: Quickshell.screens

            PanelWindow {
            id: shortcutLauncherWindow
            property var modelData
            visible: Bridge.shortcutLauncherOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "niri-bar-launcher-shortcut"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.shortcutLauncherOpen = false
            }

            LauncherPopup {
                open: Bridge.shortcutLauncherOpen
                onCloseRequested: Bridge.shortcutLauncherOpen = false

                anchors.centerIn: parent
                width: Scaling.px(520)
                height: Math.min(Scaling.px(720), parent.height - Scaling.px(80))
            }
        }
    }

    // Atajo de teclado externo: permite invocar
    // `quickshell ipc call launcher toggle` para abrir/cerrar el launcher
    // centrado sin tener que hacer click en el botón Menu.
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            Bridge.togglePopupFresh("shortcutLauncherOpen")
        }
    }

    // --- Listado de ventanas abiertas (como "rofi -show window"), centrado ---
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: windowListWindow
            property var modelData
            visible: Bridge.windowListOpen && modelData.name === Bridge.windowListScreen
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "niri-bar-windowlist"

            // El fondo absorbe el click (para que no le llegue a las
            // apps de atrás) pero ya NO cierra la ventana -- se pidió
            // que solo se cierre con Esc o el botón X del propio panel.
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            WindowListPopup {
                open: Bridge.windowListOpen
                onCloseRequested: Bridge.windowListOpen = false

                anchors.centerIn: parent
                width: Scaling.px(460)
                height: Math.min(Scaling.px(520), parent.height - Scaling.px(80))
            }
        }
    }

    // `quickshell ipc call windowlist toggle` -- también hay un atajo de
    // teclado (Mod+Grave) en el snippet del compositor.
    IpcHandler {
        target: "windowlist"
        function toggle(): void {
            Bridge.togglePopupFresh("windowListOpen")
        }
    }

    // --- Visor de atajos de teclado, centrado en pantalla ---
    Variants {
        model: Quickshell.screens

            PanelWindow {
            id: keybindsWindow
            property var modelData
            visible: Bridge.keybindsOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "niri-bar-keybinds"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.keybindsOpen = false
            }

            KeybindsPopup {
                open: Bridge.keybindsOpen
                onCloseRequested: Bridge.keybindsOpen = false

                anchors.centerIn: parent
                width: Scaling.px(560)
                height: Scaling.px(620)
            }
        }
    }

    // Atajo de teclado externo: `quickshell ipc call keybinds toggle`
    IpcHandler {
        target: "keybinds"
        function toggle(): void {
            Bridge.togglePopupFresh("keybindsOpen")
        }
    }

    // --- Dock de accesos rápidos (Config), centrado en pantalla ---
    Variants {
        model: Quickshell.screens

            PanelWindow {
            id: configDockWindow
            property var modelData
            visible: Bridge.configDockOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "niri-bar-config-dock"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.configDockOpen = false
            }

            ConfigDockPopup {
                open: Bridge.configDockOpen
                onCloseRequested: Bridge.configDockOpen = false

                // Mismo patrón que CpuPopup/RamPopup/etc.: se ancla debajo
                // del módulo Config si la barra está arriba, o encima si
                // está abajo, y sigue a BarPositions.configDockX/Width si
                // el módulo cambia de zona (izquierda/centro/derecha) o de
                // ancho. anchors.top/bottom no aceptan un booleano en un
                // Item normal, por eso el y explícito en vez de anchors.
                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.configDockX + BarPositions.configDockWidth / 2 - width / 2), parent.width - width - 8)
                width: Scaling.px(320)
                height: Scaling.px(100)
            }
        }
    }

    // Atajo de teclado externo: `quickshell ipc call config-dock toggle`
    IpcHandler {
        target: "config-dock"
        function toggle(): void {
            Bridge.togglePopupFresh("configDockOpen")
        }
    }

    // Calendario desplegable (superficie propia, así puede "flotar" sobre la barra)
    Variants {
        model: Quickshell.screens

            PanelWindow {
            id: calendarWindow
            property var modelData
            visible: Bridge.calendarOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "niri-bar-calendar"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.calendarOpen = false
            }

            CalendarPopup {
                // FIX: anchors.top/bottom no aceptan un booleano en un Item
                // normal (a diferencia de PanelWindow) -- esa asignacion fallaba
                // en silencio y el popup quedaba siempre pegado a y:0 (arriba),
                // sin importar la posicion real de la barra. Se reemplaza por un
                // y explicito calculado a partir de BarConfig.barAtBottom.
                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.clockX + BarPositions.clockWidth / 2 - width / 2), parent.width - width - 8)
                width: Scaling.px(260)
                height: Scaling.px(260)
            }
        }
    }

    // Popup de IP local, al hacer click en el indicador de red
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: networkPopupWindow
            property var modelData
            visible: Bridge.networkPopupOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            // (fix 24, 2026-10-24) Exclusive para que el TextField del
            // NetworkPopup reciba teclas (contraseña), como el launcher
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.namespace: "niri-bar-network-popup"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.networkPopupOpen = false
            }

            NetworkPopup {
                open: Bridge.networkPopupOpen
                onCloseRequested: Bridge.networkPopupOpen = false

                
                // FIX: anchors.top/bottom no aceptan un booleano en un Item
                // normal (a diferencia de PanelWindow) -- esa asignacion fallaba
                // en silencio y el popup quedaba siempre pegado a y:0 (arriba),
                // sin importar la posicion real de la barra. Se reemplaza por un
                // y explicito calculado a partir de BarConfig.barAtBottom.
                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.lanX + BarPositions.lanWidth / 2 - width / 2), parent.width - width - 8)
                // (fix 24, 2026-10-24) tamaño del nuevo popup de red (WiFi)
                width: Scaling.px(340)
                height: Scaling.px(560)
            }
        }
    }

    // Popup de CPU (hilos + uso por núcleo), al hacer click en el indicador de CPU
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: cpuPopupWindow
            property var modelData
            visible: Bridge.cpuPopupOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.namespace: "niri-bar-cpu-popup"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.cpuPopupOpen = false
            }

            CpuPopup {
                open: Bridge.cpuPopupOpen
                onCloseRequested: Bridge.cpuPopupOpen = false

                
                // FIX: anchors.top/bottom no aceptan un booleano en un Item
                // normal (a diferencia de PanelWindow) -- esa asignacion fallaba
                // en silencio y el popup quedaba siempre pegado a y:0 (arriba),
                // sin importar la posicion real de la barra. Se reemplaza por un
                // y explicito calculado a partir de BarConfig.barAtBottom.
                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.cpuX + BarPositions.cpuWidth / 2 - width / 2), parent.width - width - 8)
                width: Scaling.px(220)
                height: Scaling.px(220)
            }
        }
    }

    // Popup de Batería (AC/descargando/crítico), al hacer click en el indicador
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: batteryPopupWindow
            property var modelData
            visible: Bridge.batteryPopupOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.namespace: "niri-bar-battery-popup"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.batteryPopupOpen = false
            }

            BatteryPopup {
                open: Bridge.batteryPopupOpen
                onCloseRequested: Bridge.batteryPopupOpen = false

                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.batteryX + BarPositions.batteryWidth / 2 - width / 2), parent.width - width - 8)
                width: Scaling.px(220)
                height: Scaling.px(150)
            }
        }
    }

    // Popup de Bluetooth (encender/apagar, dispositivos, conectar/desconectar)
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bluetoothPopupWindow
            property var modelData
            visible: Bridge.bluetoothPopupOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.namespace: "niri-bar-bluetooth-popup"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.bluetoothPopupOpen = false
            }

            BluetoothPopup {
                open: Bridge.bluetoothPopupOpen
                onCloseRequested: Bridge.bluetoothPopupOpen = false

                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.bluetoothX + BarPositions.bluetoothWidth / 2 - width / 2), parent.width - width - 8)
                width: Scaling.px(260)
                height: Math.min(Scaling.px(340), parent.height - Scaling.px(80))
            }
        }
    }

    // Popup de RAM (total/usada), al hacer click en el indicador de RAM
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: ramPopupWindow
            property var modelData
            visible: Bridge.ramPopupOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.namespace: "niri-bar-ram-popup"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.ramPopupOpen = false
            }

            RamPopup {
                open: Bridge.ramPopupOpen
                onCloseRequested: Bridge.ramPopupOpen = false

                
                // FIX: anchors.top/bottom no aceptan un booleano en un Item
                // normal (a diferencia de PanelWindow) -- esa asignacion fallaba
                // en silencio y el popup quedaba siempre pegado a y:0 (arriba),
                // sin importar la posicion real de la barra. Se reemplaza por un
                // y explicito calculado a partir de BarConfig.barAtBottom.
                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.ramX + BarPositions.ramWidth / 2 - width / 2), parent.width - width - 8)
                width: Scaling.px(200)
                height: Scaling.px(110)
            }
        }
    }

    // Popup de temperatura, al hacer click en el indicador TEMP
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: tempPopupWindow
            property var modelData
            visible: Bridge.tempPopupOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.namespace: "niri-bar-temp-popup"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.tempPopupOpen = false
            }

            TempPopup {
                open: Bridge.tempPopupOpen
                onCloseRequested: Bridge.tempPopupOpen = false

                
                // FIX: anchors.top/bottom no aceptan un booleano en un Item
                // normal (a diferencia de PanelWindow) -- esa asignacion fallaba
                // en silencio y el popup quedaba siempre pegado a y:0 (arriba),
                // sin importar la posicion real de la barra. Se reemplaza por un
                // y explicito calculado a partir de BarConfig.barAtBottom.
                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.tempX + BarPositions.tempWidth / 2 - width / 2), parent.width - width - 8)
                width: Scaling.px(200)
                height: Scaling.px(140)
            }
        }
    }

    // El OSD aparece mientras cambia con rueda/teclas multimedia. Al hacer
    // click en VOL queda abierto e interactivo hasta cerrarlo con click afuera,
    // Escape o un nuevo click en VOL. Usa el
    // mismo anclaje a pantalla completa que el resto de los popups —
    // anclar solo "top" (como se hacía antes) llevaba a algunos
    // compositores a reservarle una franja exclusiva de espacio, empujando
    // hacia abajo el fondo de pantalla y la barra cada vez que aparecía.
    // exclusiveZone: -1 refuerza explícitamente que nunca debe reservar nada.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: volumeOsdWindow
            property var modelData
            visible: (Bridge.volumeOsdVisible || Bridge.volumePopupOpen) && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: Bridge.volumePopupOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.namespace: "niri-bar-volume-osd"

            MouseArea {
                anchors.fill: parent
                enabled: Bridge.volumePopupOpen
                onClicked: Bridge.volumePopupOpen = false
            }

            VolumeOsdPopup {
                
                // FIX: anchors.top/bottom no aceptan un booleano en un Item
                // normal (a diferencia de PanelWindow) -- esa asignacion fallaba
                // en silencio y el popup quedaba siempre pegado a y:0 (arriba),
                // sin importar la posicion real de la barra. Se reemplaza por un
                // y explicito calculado a partir de BarConfig.barAtBottom.
                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.volX + BarPositions.volWidth / 2 - width / 2), parent.width - width - 8)
                width: Scaling.px(220)
                height: Scaling.px(58)
            }
        }
    }

    // --- Power menu #1: abierto con click en el botón Power, arriba a la derecha ---
    Variants {
        model: Quickshell.screens

            PanelWindow {
            id: menuPowerWindow
            property var modelData
            visible: Bridge.menuPowerOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "niri-bar-power-menu"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.menuPowerOpen = false
            }

            PowerMenuPopup {
                open: Bridge.menuPowerOpen
                onCloseRequested: Bridge.menuPowerOpen = false

                // FIX: anchors.top/bottom no aceptan un booleano en un Item
                // normal (a diferencia de PanelWindow) -- esa asignacion fallaba
                // en silencio y el popup quedaba siempre pegado a y:0 (arriba),
                // sin importar la posicion real de la barra. Se reemplaza por un
                // y explicito calculado a partir de BarConfig.barAtBottom.
                anchors.left: parent.left
                y: BarConfig.barAtBottom ? (parent.height - height - Scaling.px(36)) : Scaling.px(36)
                anchors.leftMargin: Math.min(Math.max(8, BarPositions.powerX + BarPositions.powerWidth / 2 - width / 2), parent.width - width - 8)
                width: Scaling.px(200)
                height: Scaling.px(190)
            }
        }
    }

    // --- Power menu #2: abierto con el atajo de teclado, centrado en pantalla ---
    Variants {
        model: Quickshell.screens

            PanelWindow {
            id: shortcutPowerWindow
            property var modelData
            visible: Bridge.shortcutPowerOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "niri-bar-power-shortcut"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.shortcutPowerOpen = false
            }

            PowerMenuPopup {
                open: Bridge.shortcutPowerOpen
                onCloseRequested: Bridge.shortcutPowerOpen = false

                anchors.centerIn: parent
                width: Scaling.px(240)
                height: Scaling.px(220)
            }
        }
    }

    // Atajo de teclado externo para el menú de energía centrado:
    // `quickshell ipc call powermenu toggle`
    IpcHandler {
        target: "powermenu"
        function toggle(): void {
            Bridge.togglePopupFresh("shortcutPowerOpen")
        }
    }

    // Selector de fondo de pantalla, centrado, abierto con atajo de teclado
    Variants {
        model: Quickshell.screens

            PanelWindow {
            id: wallpaperPickerWindow
            property var modelData
            visible: Bridge.wallpaperPickerOpen && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "niri-bar-wallpaper-picker"

            // El fondo absorbe los clicks (para que no lleguen a las apps
            // de atrás) pero ya NO cierra el selector -- se pidió que
            // solo se cierre con Escape o su botón X, no al hacer click
            // afuera como un launcher.
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            WallpaperPicker {
                open: Bridge.wallpaperPickerOpen
                onCloseRequested: Bridge.wallpaperPickerOpen = false

                anchors.centerIn: parent
                // 4x4 miniaturas: celdas de 168x106 escaladas, más
                // margenes/fila de título, el panel de tags a la derecha
                // (Scaling.px(160) + spacing) y lugar para el scrollbar.
                // Ancho ampliado de 720 a 900 para que el panel de tags no
                // le quite columnas a la grilla (sigue entrando 4x4).
                width: Math.min(Scaling.px(900), parent.width - Scaling.px(40))
                height: Math.min(Scaling.px(540), parent.height - Scaling.px(60))
            }
        }
    }

    // Atajo de teclado externo para el selector de fondo:
    // `quickshell ipc call wallpaper toggle`
    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            Bridge.togglePopupFresh("wallpaperPickerOpen")
        }
    }

    // Confirmación con cuenta regresiva para cerrar sesión/reiniciar/apagar.
    // Se dispara desde PendingAction (usado por el launcher y los 2 power
    // menus), centrada en pantalla. No se cierra con click afuera a
    // propósito -- es una accion seria, asi que exige Cancelar, Aceptar
    // ahora, o dejar que corra la cuenta regresiva.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: confirmActionWindow
            property var modelData
            visible: PendingAction.open && modelData.name === FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.namespace: "niri-bar-confirm-action"

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ConfirmActionPopup {
                anchors.centerIn: parent
                width: Scaling.px(320)
                height: Scaling.px(160)
            }
        }
    }

    // Red de seguridad para click afuera en OTRA pantalla (no la que
    // tiene el foco). Los popups de arriba ya se cierran solos con click
    // afuera en la MISMA pantalla (su propio MouseArea) y al cambiar de
    // pantalla enfocada (Bridge.closeScreenBoundPopups(), vía
    // FocusedScreen) -- pero en Sway, hacer click en una pantalla sin
    // ventanas (fondo vacío) no siempre hace que swaymsg reporte esa
    // pantalla como enfocada: el modelo de foco de Sway (heredado de i3)
    // sigue a las ventanas/contenedores, no al puntero, así que un click
    // sin ninguna ventana de por medio a veces no dispara ningún evento
    // de foco. Sin ese evento, FocusedScreen.name nunca cambiaba y el
    // popup quedaba abierto en la pantalla original, ignorando el click
    // en la otra. (niri y Hyprland no tienen este problema -- ahí el
    // click SÍ actualiza el output/monitor enfocado igual, con o sin
    // ventana -- pero esta red de seguridad no les molesta: en esos dos
    // solo duplica, sin efecto extra, el cierre que ya iba a pasar solo.)
    //
    // Esta ventana existe en TODAS las pantallas que NO sean la enfocada
    // mientras haya un popup de este tipo abierto, y solo sirve para
    // atajar ese click directamente ahí mismo (sin depender de ningún
    // IPC de foco) y cerrar el popup.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: otherScreenCatcherWindow
            property var modelData
            visible: Bridge.anyScreenBoundPopupOpen && modelData.name !== FocusedScreen.name
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "niri-bar-other-screen-catcher"

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.closeScreenBoundPopups()
            }
        }
    }
}
