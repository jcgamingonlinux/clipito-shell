import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    // Solo la instancia del launcher que abre el botón Menu (arriba-izq)
    // muestra estos botones — la centrada por atajo de teclado queda igual.
    property bool showPowerButtons: false

    // Solo esa misma instancia (Launcher #1) se puede redimensionar
    // arrastrando con el mouse -- ver manijas al final del archivo. La
    // centrada (#2) sigue con tamaño fijo, como antes.
    property bool resizable: false

    // Tamaño de arranque (lo que antes se fijaba desde afuera vía
    // "width:"/"height:" directo en shell.qml). Si "resizable" es true,
    // este es solo el punto de partida -- el tamaño real después pasa a
    // vivir en popupWidth/popupHeight, que las manijas van modificando.
    // Si "resizable" es false (Launcher #2), nada más toca
    // popupWidth/popupHeight después de esto, así que el tamaño queda
    // fijo igual que siempre.
    property real initialWidth: Scaling.px(420)
    property real initialHeight: Scaling.px(680)

    property real minWidth: Scaling.px(300)
    property real minHeight: Scaling.px(260)
    // Margen respecto al tamaño de pantalla para el máximo -- así el
    // agrandado nunca desborda ni queda pegado borde a borde.
    property real screenMargin: Scaling.px(40)

    property real popupWidth: initialWidth
    property real popupHeight: initialHeight

    // Único lugar que debería tocar popupWidth/popupHeight (además de
    // las manijas) -- centraliza el clamp a mínimo/máximo para que
    // ningún camino (arranque, arrastre, cambio de pantalla) pueda
    // dejarlo fuera de rango.
    //
    // FIX: en Component.onCompleted, la ventana contenedora todavía no
    // se mostró nunca (arranca invisible) y su "width"/"height" real
    // puede llegar como 0 en ese instante -- eso hacía que el máximo
    // calculado diera NEGATIVO y aplastara el tamaño (guardado o
    // inicial) hasta el mínimo de una, siempre, sin importar qué tamaño
    // se hubiera fijado. Por eso se veía chico "por defecto" y por eso
    // el guardado en disco parecía no servir de nada -- se leía bien,
    // pero quedaba destruido un instante después por este mismo cálculo.
    // Ahora, si el padre todavía no tiene un tamaño real, se aplica SOLO
    // el mínimo (siempre válido) y se deja el máximo para más adelante
    // (ver el segundo llamado a clampSize() en onOpenChanged, cuando la
    // ventana ya seguro está visible).
    function clampSize() {
        let parentReady = root.parent && root.parent.width > 0 && root.parent.height > 0
        root.popupWidth = Math.max(root.minWidth,
            parentReady ? Math.min(root.popupWidth, root.parent.width - root.screenMargin) : root.popupWidth)
        root.popupHeight = Math.max(root.minHeight,
            parentReady ? Math.min(root.popupHeight, root.parent.height - root.screenMargin) : root.popupHeight)
    }

    width: popupWidth
    height: popupHeight

    // El tamaño elegido a mano (solo cuando resizable == true) se guarda
    // en disco -- antes quedaba solo en memoria, así que una nueva sesión
    // de quickshell (ej. cerrar sesión y volver a entrar) siempre
    // arrancaba de nuevo en initialWidth/initialHeight, sin importar el
    // tamaño que se hubiera dejado la vez anterior.
    function loadSize() {
        if (!root.resizable) return
        sizeReader.running = true
    }

    function saveSize() {
        if (!root.resizable) return
        let b64 = Qt.btoa(Math.round(root.popupWidth) + "x" + Math.round(root.popupHeight))
        sizeWriter.command = ["sh", "-c",
            "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + b64 + "' | base64 -d > \"$HOME/.config/quickshell/launcher-size.txt\""]
        sizeWriter.running = true
    }

    property Process sizeReader: Process {
        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/launcher-size.txt\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let m = text.trim().match(/^(\d+)x(\d+)$/)
                if (m) {
                    root.popupWidth = parseInt(m[1])
                    root.popupHeight = parseInt(m[2])
                }
                // Se llama SIEMPRE, haya o no un tamaño guardado -- así el
                // tamaño de arranque (si es la primera vez) también queda
                // sujeto al mismo mínimo/máximo.
                root.clampSize()
            }
        }
    }

    property Process sizeWriter: Process { }

    Component.onCompleted: {
        if (root.resizable) root.loadSize()
        else root.clampSize()
    }

    readonly property var powerActions: [
        { label: "Cerrar sesión", cmd: ["sh", "-c", "hyprctl dispatch \"hl.dsp.exit()\" 2>/dev/null || hyprctl dispatch exit"] },
        { label: "Reiniciar",     action: "reboot" },
        { label: "Apagar",        action: "poweroff" }
    ]

    // Reiniciar/Apagar no traen un cmd fijo (ver PowerCommands.qml): se
    // resuelve acá, recién al ejecutar, para no depender de que la
    // detección systemctl/loginctl/raw ya haya terminado cuando se arma este
    // array. Cerrar sesión no cambia: ya trae su cmd fijo.
    function cmdFor(item) {
        if (item.action === "reboot") return PowerCommands.rebootCmd()
        if (item.action === "poweroff") return PowerCommands.poweroffCmd()
        return item.cmd
    }

    function requestPowerAction(index) {
        let item = root.powerActions[index]
        PendingAction.request(item.label, root.cmdFor(item))
        root.closeRequested()
    }

    // Controlado por quien instancia este componente. Hay dos instancias
    // independientes en shell.qml (una para el botón Menu, otra para el
    // atajo de teclado), cada una con su propio flag en Bridge.
    property bool open: false
    signal closeRequested()

    property string query: ""
    property int selectedIndex: 0

    // Sin búsqueda: primero hasta 6 apps más usadas (según AppUsage), un
    // separador, y el resto en orden alfabético (sin repetir las de arriba).
    // Buscando: lista filtrada normal, ordenada alfabéticamente.
    readonly property var filtered: {
        // Si esta instancia no está abierta (puede haber hasta 4 a la vez:
        // botón Menu + atajo de teclado, por cada monitor), no tiene
        // sentido filtrar/ordenar nada -- nadie lo está mirando. Cortar acá
        // además hace que este binding dependa SOLO de "open" mientras
        // está cerrado: mientras tanto, cambios en AppList.apps ya no
        // disparan un reordenamiento en esta instancia (se vuelve a
        // calcular recién cuando se reabre).
        if (!root.open) return []
        let q = root.query.toLowerCase()
        if (q.length === 0) {
            // Las 8 de arriba son una instantánea fija tomada una sola vez
            // esta sesión (AppUsage.pinnedTopApps) -- se muestran tal cual,
            // sin depender de si siguen instaladas, así aparecen de
            // inmediato y nunca se reordenan ni parpadean mientras el
            // resto de la lista sigue actualizándose abajo.
            let top = AppUsage.pinnedTopApps || []
            let topNames = {}
            top.forEach(a => { topNames[a.name] = true })
            let rest = AppList.apps.filter(a => !topNames[a.name]).slice().sort((a, b) => a.name.localeCompare(b.name))

            if (top.length === 0) return rest
            return top.concat([{ isSeparator: true }]).concat(rest)
        }

        let list = AppList.apps.filter(a => a.name.toLowerCase().indexOf(q) !== -1)
        return list.slice().sort((a, b) => a.name.localeCompare(b.name)).slice(0, 60)
    }

    // El escaneo de .desktop instalados ahora vive en AppList.qml (un
    // singleton que escanea una sola vez por sesión) -- ver ese archivo.
    // Antes cada instancia de este componente (hay 2: botón Menu + atajo
    // de teclado) volvía a escanear todo desde cero cada vez que se abría,
    // lo que se notaba como demora visible con muchas apps instaladas.


    function launch(app) {
        AppUsage.recordLaunch(app.name)

        // Process desechable por lanzamiento, desligado con setsid+&+disown
        // para que nunca bloquee el siguiente lanzamiento.
        let proc = Qt.createQmlObject(
            "import Quickshell.Io; Process { }",
            root,
            "launcherProc"
        )
        proc.command = ["sh", "-c", "setsid " + app.exec + " >/dev/null 2>&1 & disown"]
        proc.runningChanged.connect(() => { if (!proc.running) proc.destroy() })
        proc.running = true

        root.query = ""
        root.closeRequested()
    }

    // Un .desktop puede declarar un icono del tema, una ruta absoluta, o
    // (menos frecuente pero válido) una ruta con "~". Ni Image ni
    // IconImage expanden "~" por su cuenta -- lo tratan como si fuera un
    // nombre de icono de tema y la búsqueda falla en silencio -- por eso
    // se expande acá a mano antes de decidir cómo cargarlo.
    function iconSource(icon) {
        if (!icon || icon.length === 0)
            return Quickshell.iconPath("application-x-executable", true)
        let resolved = icon
        if (resolved === "~" || resolved.startsWith("~/")) {
            let home = Quickshell.env("HOME") || ""
            resolved = home + resolved.slice(1)
        }
        if (resolved.startsWith("/"))
            return "file://" + resolved
        return Quickshell.iconPath(resolved, "application-x-executable")
    }

    // Salta cualquier separador al moverse con las flechas
    function firstSelectable() {
        for (let i = 0; i < root.filtered.length; i++) {
            if (!root.filtered[i].isSeparator) return i
        }
        return 0
    }

    function moveSelection(delta) {
        let i = root.selectedIndex + delta
        while (i >= 0 && i < root.filtered.length && root.filtered[i].isSeparator) i += delta
        if (i >= 0 && i < root.filtered.length) root.selectedIndex = i
    }

    onOpenChanged: {
        if (root.open) {
            root.selectedIndex = 0
            // El listado completo se refresca cada vez que se abre (por si
            // se instaló algo nuevo); las 8 más-usadas NO se tocan acá --
            // quedan fijas por sesión (AppUsage.pinnedTopApps).
            AppList.rescan()
            search.forceActiveFocus()
            // Recién ACÁ es seguro que la ventana contenedora ya está
            // visible (y por lo tanto con un tamaño de pantalla real) --
            // se vuelve a clampear por si el primer intento, en
            // Component.onCompleted, se quedó corto por llegar demasiado
            // temprano (ver el comentario largo en clampSize()).
            if (root.resizable) root.clampSize()
        } else {
            root.query = ""
            root.selectedIndex = 0
        }
    }

    onFilteredChanged: {
        if (root.selectedIndex >= root.filtered.length || (root.filtered[root.selectedIndex] && root.filtered[root.selectedIndex].isSeparator)) {
            root.selectedIndex = root.firstSelectable()
        }
    }

    // Absorbe cualquier click dentro del launcher (incluso en zonas sin
    // widgets, como márgenes) para que NO se propague hacia el fondo de la
    // ventana contenedora, que cierra el launcher al hacer click afuera.
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(14)
        spacing: Scaling.px(10)

        TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Buscar aplicación…"
            text: root.query
            onTextChanged: {
                root.query = text
                root.selectedIndex = root.firstSelectable()
            }
            Keys.onEscapePressed: root.closeRequested()
            Keys.onReturnPressed: {
                if (root.filtered.length > 0 && !root.filtered[root.selectedIndex].isSeparator) {
                    root.launch(root.filtered[root.selectedIndex])
                }
            }
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-1)
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filtered
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: true

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: Scaling.px(8)
                minimumSize: 0.12

                background: Rectangle {
                    implicitWidth: Scaling.px(8)
                    radius: width / 2
                    color: "#313244"
                }

                contentItem: Rectangle {
                    implicitWidth: Scaling.px(5)
                    radius: width / 2
                    color: "#6c7086"
                    opacity: parent.active ? 0.95 : 0.65
                }
            }

            delegate: Item {
                id: delegateRoot
                required property var modelData
                required property int index
                width: list.width
                height: delegateRoot.modelData.isSeparator ? Scaling.px(28) : Scaling.px(40)

                // Separador entre las 8 más usadas (fijas) y el resto
                // alfabético
                Rectangle {
                    visible: delegateRoot.modelData.isSeparator === true
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Scaling.px(4)
                    anchors.rightMargin: Scaling.px(4)
                    height: Scaling.px(2)
                    radius: Scaling.px(1)
                    color: "#45475a"
                }

                Rectangle {
                    visible: !delegateRoot.modelData.isSeparator
                    anchors.fill: parent
                    radius: Scaling.px(6)
                    color: (delegateRoot.index === root.selectedIndex || itemArea.containsMouse) ? "#313244" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Scaling.px(8)
                        anchors.rightMargin: Scaling.px(8)
                        spacing: Scaling.px(10)

                        // Ícono resuelto vía tema de íconos; si no se resuelve,
                        // se ve la inicial del nombre como respaldo.
                        Item {
                            Layout.preferredWidth: Scaling.px(26)
                            Layout.preferredHeight: Scaling.px(26)

                            Rectangle {
                                anchors.fill: parent
                                radius: Scaling.px(5)
                                color: "#45475a"
                                visible: iconImg.status !== Image.Ready

                                Text {
                                    anchors.centerIn: parent
                                    text: delegateRoot.modelData.name && delegateRoot.modelData.name.length > 0 ? delegateRoot.modelData.name.charAt(0).toUpperCase() : "?"
                                    color: "#cdd6f4"
                                    font.pixelSize: Scaling.px(12)
                                    font.bold: true
                                }
                            }

                            IconImage {
                                id: iconImg
                                anchors.fill: parent
                                asynchronous: true
                                property bool triedPixmapFallback: false
                                source: root.iconSource(delegateRoot.modelData.icon)
                                onStatusChanged: {
                                    // Muchos temas minimalistas (ej. Adwaita)
                                    // no traen íconos de apps de terceros.
                                    // Antes de rendirnos (y mostrar el avatar
                                    // con la inicial), probamos la ubicación
                                    // clásica /usr/share/pixmaps.
                                    if (status === Image.Error && !triedPixmapFallback) {
                                        triedPixmapFallback = true
                                        let raw = (delegateRoot.modelData.icon || "").toString()
                                        let name = raw.split("/").pop().replace(/\?.*$/, "").replace(/\.(png|svg|xpm)$/i, "")
                                        if (name.length > 0) source = "file:///usr/share/pixmaps/" + name + ".png"
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: delegateRoot.modelData.name || ""
                            color: "#cdd6f4"
                            font.pixelSize: Scaling.px(12)
                        }
                    }

                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.selectedIndex = delegateRoot.index
                            root.launch(delegateRoot.modelData)
                        }
                    }
                }
            }
        }

        Text {
            visible: root.filtered.length === 0
            text: "Buscando aplicaciones…"
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
        }

        // Botones de energía, solo en la instancia del botón Menu
        RowLayout {
            visible: root.showPowerButtons
            Layout.fillWidth: true
            spacing: Scaling.px(8)

            Repeater {
                model: root.powerActions
                delegate: Rectangle {
                    id: powerBtn
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: Scaling.px(30)
                    radius: Scaling.px(6)
                    color: powerBtnArea.containsMouse ? "#45475a" : "#313244"

                    Text {
                        anchors.centerIn: parent
                        text: powerBtn.modelData.label
                        color: "#cdd6f4"
                        font.pixelSize: Scaling.px(12)
                    }

                    MouseArea {
                        id: powerBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.requestPowerAction(powerBtn.index)
                    }
                }
            }
        }
    }

    // ============================================================
    // --- Manijas de redimensionado (solo si resizable == true) ---
    // ============================================================
    // Las 3 usan el mismo truco: la posición del mouse se lee en
    // coordenadas GLOBALES (mapToGlobal), no locales -- si se usara
    // mouse.x/y locales, cada píxel que se agranda la ventana MUEVE la
    // propia manija (está anclada al borde), y esa manija en movimiento
    // bajo un cursor que no se mueve genera un delta incorrecto
    // (feedback loop). En coordenadas globales, el delta real del mouse
    // entre el press y el momento actual es siempre correcto sin
    // importar cuánto se haya movido la manija mientras tanto.

    // Borde derecho: solo ancho.
    MouseArea {
        id: rightEdgeHandle
        visible: root.resizable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Scaling.px(14) // deja lugar a la esquina
        width: Scaling.px(6)
        cursorShape: Qt.SizeHorCursor
        property real pressGlobalX: 0
        property real pressWidth: 0
        onPressed: (mouse) => {
            let g = mapToGlobal(mouse.x, mouse.y)
            pressGlobalX = g.x
            pressWidth = root.popupWidth
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            let g = mapToGlobal(mouse.x, mouse.y)
            root.popupWidth = pressWidth + (g.x - pressGlobalX)
            root.clampSize()
        }
        onReleased: root.saveSize()
    }

    // Borde inferior: solo alto.
    MouseArea {
        id: bottomEdgeHandle
        visible: root.resizable
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Scaling.px(14) // deja lugar a la esquina
        height: Scaling.px(6)
        cursorShape: Qt.SizeVerCursor
        property real pressGlobalY: 0
        property real pressHeight: 0
        onPressed: (mouse) => {
            let g = mapToGlobal(mouse.x, mouse.y)
            pressGlobalY = g.y
            pressHeight = root.popupHeight
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            let g = mapToGlobal(mouse.x, mouse.y)
            root.popupHeight = pressHeight + (g.y - pressGlobalY)
            root.clampSize()
        }
        onReleased: root.saveSize()
    }

    // Esquina inferior-derecha: ancho y alto juntos. Va última para
    // quedar arriba de las dos manijas de borde en la zona donde se
    // superponen.
    MouseArea {
        id: cornerHandle
        visible: root.resizable
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Scaling.px(16)
        height: Scaling.px(16)
        cursorShape: Qt.SizeFDiagCursor
        property real pressGlobalX: 0
        property real pressGlobalY: 0
        property real pressWidth: 0
        property real pressHeight: 0
        onPressed: (mouse) => {
            let g = mapToGlobal(mouse.x, mouse.y)
            pressGlobalX = g.x
            pressGlobalY = g.y
            pressWidth = root.popupWidth
            pressHeight = root.popupHeight
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            let g = mapToGlobal(mouse.x, mouse.y)
            root.popupWidth = pressWidth + (g.x - pressGlobalX)
            root.popupHeight = pressHeight + (g.y - pressGlobalY)
            root.clampSize()
        }
        onReleased: root.saveSize()

        // Marca visual discreta (3 rayitas diagonales), para que se note
        // que ahí se puede agarrar.
        Canvas {
            anchors.fill: parent
            anchors.margins: Scaling.px(3)
            onPaint: {
                let ctx = getContext("2d")
                ctx.strokeStyle = "#6c7086"
                ctx.lineWidth = 1
                for (let i = 0; i < 3; i++) {
                    let off = i * 4
                    ctx.beginPath()
                    ctx.moveTo(width - off, height)
                    ctx.lineTo(width, height - off)
                    ctx.stroke()
                }
            }
        }
    }
}
