import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Lee ~/.config/mango/config.conf y muestra los binds definidos con
// "bind[flags]=MODIFICADORES,TECLA,COMANDO,PARAMETROS".
//
// A diferencia de Hyprland (que tiene un parser Lua completo acá porque
// hyprland.lua es Lua de verdad), la config de mango es texto plano línea
// por línea -- mucho más parecido a como se parsean niri/sway -- así que
// no hace falta nada del mecanismo de balanced-parens/locals que tiene la
// versión de Hyprland.
//
// Modo curado (recomendado): si hay comentarios "# @category ..." y
// "# @title ..." antes de un bind, SOLO se muestran esos, agrupados por
// "@category". Sin anotar nada, el modo automático muestra TODOS los
// binds reconocidos con una descripción generada a partir del nombre del
// dispatcher (ver mapa "describe" más abajo -- cubre los dispatchers más
// comunes de la wiki de mango; cualquiera no listado cae a un genérico
// "Nombre (args)").
Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    // Configurable por si tu config vive en otro lado. Default según la
    // wiki de mango (quick-start): ~/.config/mango/config.conf
    property string configPath: "$HOME/.config/mango/config.conf"

    property var entries: []
    property string query: ""
    property string loadError: ""
    property bool curated: false

    FontMetrics {
        id: comboMetrics
        font.pixelSize: Scaling.px(12)
        font.family: "monospace"
    }

    FontMetrics {
        id: descriptionMetrics
        font.pixelSize: Scaling.px(13)
    }

    function shortcutsContentWidth(viewWidth) {
        let widest = 0
        root.grouped.forEach(item => {
            if (item.isHeader) {
                widest = Math.max(widest, descriptionMetrics.advanceWidth(item.text || ""))
            } else {
                let combo = comboMetrics.advanceWidth(item.combo || "") + Scaling.px(14)
                let description = descriptionMetrics.advanceWidth(item.desc || "")
                widest = Math.max(widest, combo + Scaling.px(10) + description + Scaling.px(8))
            }
        })
        return Math.max(viewWidth, Math.ceil(widest))
    }

    function scan() {
        root.entries = []
        root.loadError = ""
        reader.buffer = []
        // A diferencia de Hyprland, acá no se sigue ningún include tipo
        // "source=" -- si dividís tu config.conf en varios archivos,
        // apuntá configPath directo al que tiene los binds, o pedime que
        // lo agregue (es un cambio chico).
        reader.command = ["sh", "-c", "cat \"" + root.configPath.replace(/"/g, "\\\"") + "\" 2>/dev/null"]
        reader.running = true
    }

    Process {
        id: reader
        property var buffer: []
        stdout: SplitParser {
            onRead: (line) => { reader.buffer.push(line) }
        }
        onRunningChanged: {
            if (!running) {
                let text = reader.buffer.join("\n")
                if (text.trim().length === 0) {
                    root.loadError = "No se pudo leer " + root.configPath
                    return
                }
                let result = root.parseMango(text)
                root.entries = result.entries
                root.curated = result.curated
                if (root.entries.length === 0) {
                    root.loadError = "No se encontraron líneas \"bind...=\" en el archivo"
                }
            }
        }
    }

    // Traduce los dispatchers documentados en la wiki de mango (página
    // "keys") a una descripción legible. Lo que no está en este mapa cae
    // al genérico "Nombre (args)".
    function describeDispatcher(dispatcher, args) {
        const map = {
            "spawn": "Ejecutar", "spawn_shell": "Ejecutar (shell)",
            "killclient": "Cerrar ventana", "togglefloating": "Alternar flotante",
            "toggle_all_floating": "Alternar flotante (todas)",
            "togglefullscreen": "Alternar pantalla completa",
            "togglefakefullscreen": "Alternar pantalla completa (fake)",
            "togglemaximizescreen": "Maximizar ventana", "toggleglobal": "Fijar en todos los tags",
            "centerwin": "Centrar ventana flotante", "minimized": "Minimizar (scratchpad)",
            "restore_minimized": "Restaurar minimizada", "toggle_scratchpad": "Alternar scratchpad",
            "toggle_special_tag": "Alternar tag especial (scratchpad)",
            "focusid": "Enfocar ventana por id", "focusdir": "Enfocar dirección",
            "focus_window_or_workspace": "Enfocar dirección o tag adyacente",
            "focusstack": "Ciclar foco en la pila", "focuslast": "Enfocar ventana anterior",
            "switcher": "Selector de miniaturas", "exchange_client": "Intercambiar ventana",
            "exchange_stack_client": "Intercambiar posición en pila",
            "move_client": "Mover ventana", "zoom": "Intercambiar con master",
            "groupjoin": "Unir grupo", "groupfocus": "Enfocar miembro del grupo", "groupleave": "Salir del grupo",
            "view": "Ver tag", "viewtoleft": "Tag anterior", "viewtoright": "Tag siguiente",
            "view_insert": "Ver/crear tag adyacente",
            "viewtoleft_have_client": "Tag anterior (con ventana)",
            "viewtoright_have_client": "Tag siguiente (con ventana)",
            "viewcrossmon": "Ver tag en otro monitor",
            "tag": "Mover ventana a tag", "tagsilent": "Mover ventana a tag (sin enfocar)",
            "tagtoleft": "Mover ventana a tag anterior", "tagtoright": "Mover ventana a tag siguiente",
            "tagcrossmon": "Mover ventana a tag en otro monitor",
            "toggletag": "Alternar tag(s) en la ventana", "toggleview": "Alternar vista de tag (multiview)",
            "comboview": "Ver varios tags a la vez",
            "focusmon": "Enfocar monitor", "tagmon": "Mover ventana a monitor",
            "setlayout": "Cambiar layout", "switch_layout": "Ciclar layout",
            "incnmaster": "Cambiar N° de ventanas master", "setmfact": "Cambiar tamaño del área master",
            "set_proportion": "Fijar proporción (scroller)", "switch_proportion_preset": "Ciclar proporción (scroller)",
            "scroller_stack": "Mover en pila del scroller", "incgaps": "Ajustar separación (gaps)",
            "togglegaps": "Alternar gaps",
            "reload_config": "Recargar configuración", "quit": "Salir de mango",
            "toggleoverview": "Alternar overview", "enteroverview": "Entrar a overview",
            "leaveoverview": "Salir de overview",
            "setkeymode": "Cambiar keymode", "switch_keyboard_layout": "Cambiar layout de teclado",
            "smartmovewin": "Mover ventana flotante", "smartresizewin": "Redimensionar ventana flotante",
            "movewin": "Mover ventana flotante (x,y)", "resizewin": "Redimensionar ventana (ancho,alto)"
        }
        let label = map[dispatcher]
        if (label === undefined) {
            let words = dispatcher.replace(/[._]/g, " ")
            label = words.charAt(0).toUpperCase() + words.slice(1)
        }
        return label + (args && args.length > 0 ? ": " + args : "")
    }

    // "bind[flags]=MODIFICADORES,TECLA,COMANDO,PARAMETROS" -- mismo forma
    // general que la sintaxis clásica de hyprlang, así que se reutiliza
    // básicamente la misma regex.
    function parseMango(text) {
        let lines = text.split("\n")
        let annotated = []
        let annCategory = ""
        let annTitle = null
        let fallback = []
        let fbCategory = ""

        let bindRe = /^bind[a-zA-Z]*\s*=\s*([^,]*),([^,]*),([^,]*),?(.*)$/

        for (let i = 0; i < lines.length; i++) {
            let trimmed = lines[i].trim()
            if (trimmed.length === 0) continue

            let catMatch = trimmed.match(/^#\s*@category\s+(.+)$/)
            if (catMatch) { annCategory = catMatch[1].trim(); annTitle = null; continue }

            let titleMatch = trimmed.match(/^#\s*@title\s+(.+)$/)
            if (titleMatch) { annTitle = titleMatch[1].trim(); continue }

            if (trimmed.startsWith("#")) {
                let t = trimmed.replace(/^#\s?/, "")
                fbCategory = fbCategory ? fbCategory + " " + t : t
                continue
            }

            let bindMatch = trimmed.match(bindRe)
            if (bindMatch) {
                let mods = bindMatch[1].trim()
                let key = bindMatch[2].trim()
                // Los modificadores de mango ya vienen unidos con "+"
                // (ej. "SUPER+ALT"), así que solo hace falta pegar la tecla.
                let combo = mods.length > 0 ? mods + "+" + key : key
                let dispatcher = bindMatch[3].trim()
                let args = (bindMatch[4] || "").trim()
                let action = dispatcher === "spawn" || dispatcher === "spawn_shell"
                    ? "Ejecutar: " + args
                    : root.describeDispatcher(dispatcher, args)

                if (annTitle !== null) {
                    annotated.push({ combo: combo, desc: annTitle, category: annCategory })
                    annTitle = null
                }
                fallback.push({ combo: combo, desc: action, category: fbCategory })
                fbCategory = ""
                continue
            }

            fbCategory = ""
        }

        let useCurated = annotated.length > 0
        return { entries: useCurated ? annotated : fallback, curated: useCurated }
    }

    onOpenChanged: {
        if (root.open) {
            root.scan()
            search.forceActiveFocus()
        } else {
            root.query = ""
        }
    }

    readonly property var grouped: {
        let q = root.query.trim().toLowerCase()
        let filtered = root.entries.filter(e => {
            if (q.length === 0) return true
            return (e.combo + " " + e.desc + " " + e.category).toLowerCase().indexOf(q) !== -1
        })
        let byCategory = {}
        let order = []
        filtered.forEach(e => {
            let fallbackLabel = root.curated ? "Sin categoría" : "Otros atajos"
            let cat = (e.category && e.category.length > 0) ? e.category : fallbackLabel
            if (!byCategory[cat]) { byCategory[cat] = []; order.push(cat) }
            byCategory[cat].push(e)
        })
        let items = []
        order.forEach(cat => {
            items.push({ isHeader: true, text: cat })
            byCategory[cat].forEach(e => items.push(e))
        })
        return items
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(14)
        spacing: Scaling.px(10)

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Atajos de teclado (Mango)"
                color: "#f5e0dc"
                font.bold: true
                font.pixelSize: Scaling.px(14)
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                implicitWidth: Scaling.px(22)
                implicitHeight: Scaling.px(22)
                radius: Scaling.px(4)
                color: closeHoverKeybinds.containsMouse ? "#f38ba8" : "#313244"
                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Scaling.px(11)
                    color: closeHoverKeybinds.containsMouse ? "#1e1e2e" : "#cdd6f4"
                }
                MouseArea {
                    id: closeHoverKeybinds
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.closeRequested()
                }
            }
        }

        TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Buscar atajo…"
            text: root.query
            onTextChanged: root.query = text
            Keys.onEscapePressed: root.closeRequested()
        }

        Text {
            visible: root.loadError.length > 0
            text: root.loadError
            color: "#f38ba8"
            font.pixelSize: Scaling.px(12)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Text {
            visible: root.loadError.length === 0 && root.entries.length > 0
            text: root.curated
                ? "Mostrando solo los atajos documentados con \"@title\""
                : "Sin anotaciones \"@title\" — mostrando todos los binds reconocidos en config.conf"
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
            font.italic: true
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        ListView {
            id: shortcutList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Scaling.px(2)
            model: root.grouped
            contentWidth: root.shortcutsContentWidth(width)

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Item {
                id: delegateRoot
                required property var modelData
                width: shortcutList.contentWidth
                height: delegateRoot.modelData.isHeader ? Scaling.px(30) : Scaling.px(38)

                Text {
                    visible: delegateRoot.modelData.isHeader === true
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: delegateRoot.modelData.text
                    color: "#89b4fa"
                    font.bold: true
                    font.pixelSize: Scaling.px(12)
                }

                RowLayout {
                    visible: delegateRoot.modelData.isHeader !== true
                    anchors.fill: parent
                    anchors.leftMargin: Scaling.px(4)
                    anchors.rightMargin: Scaling.px(4)
                    spacing: Scaling.px(10)

                    Rectangle {
                        Layout.preferredWidth: comboText.implicitWidth + Scaling.px(14)
                        Layout.preferredHeight: Scaling.px(22)
                        radius: Scaling.px(5)
                        color: "#313244"

                        Text {
                            id: comboText
                            anchors.centerIn: parent
                            text: delegateRoot.modelData.combo || ""
                            color: "#cdd6f4"
                            font.pixelSize: Scaling.px(12)
                            font.family: "monospace"
                        }
                    }

                    Text {
                        id: descriptionText
                        Layout.fillWidth: true
                        Layout.preferredWidth: descriptionMetrics.advanceWidth(text)
                        text: delegateRoot.modelData.desc || ""
                        color: "#bac2de"
                        font.pixelSize: Scaling.px(13)
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
                    }
                }
            }
        }

        Text {
            visible: root.entries.length === 0 && root.loadError.length === 0
            text: "Leyendo " + root.configPath + "…"
            color: "#9399b2"
            font.pixelSize: Scaling.px(12)
        }
    }
}
