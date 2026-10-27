import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Lee ~/.config/hypr/hyprland.lua (formato Lua nativo de Hyprland 0.55+,
// con llamadas "hl.bind(...)") y también sigue, de forma best-effort, los
// require("archivo") que encuentre en el archivo principal.
//
// A diferencia de niri/sway (config de texto plano fácil de parsear con
// regex), esto es Lua real: variables, concatenación de strings, loops,
// funciones anónimas como dispatcher, etc. Este parser NO ejecuta Lua —
// solo reconoce los patrones más comunes:
//   hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))
//   hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("..."))   -- resuelve
//     "mainMod" si hay un "local mainMod = "SUPER"" en el archivo
//   hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("..."), { locked = true })
// Binds generados dinámicamente (ej. dentro de un "for i = 1, 10 do")
// NO se pueden resolver sin un intérprete de Lua real, así que se omiten
// silenciosamente tanto en modo curado como automático — es una
// limitación conocida, ver README.
//
// Modo curado (MUY recomendado acá, más todavía que en niri/sway): si
// hay comentarios "-- @category ..." y "-- @title ..." antes de un
// "hl.bind(...)" resoluble, SOLO se muestran esos, agrupados por
// "@category". El modo automático (sin anotar nada) es más limitado que
// en niri/sway porque no todos los dispatchers se pueden resumir sin
// ejecutarlos.
Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    // Configurable por si tu config vive en otro lado (XDG_CONFIG_HOME, etc.)
    property string configPath: "$HOME/.config/hypr/hyprland.lua"

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

    // Conserva el ancho real de cada combinación y descripción para que la
    // lista pueda desplazarse horizontalmente solo si hace falta.
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
        // Concatena el archivo principal + cada archivo que encuentre en
        // un require("archivo") de nivel superior (best-effort: intenta
        // "archivo" y "archivo.lua", relativo al directorio de
        // hyprland.lua si no es una ruta absoluta).
        let cmd = "main=\"" + root.configPath.replace(/"/g, "\\\"") + "\"; " +
                  "cat \"$main\" 2>/dev/null; " +
                  "dir=\"$(dirname \"$main\")\"; " +
                  "grep -oE \"require\\\\([[:space:]]*['\\\"][^'\\\"]+['\\\"][[:space:]]*\\\\)\" \"$main\" 2>/dev/null " +
                  "| sed -E \"s/require\\\\([[:space:]]*['\\\"]([^'\\\"]+)['\\\"][[:space:]]*\\\\)/\\\\1/\" " +
                  "| while IFS= read -r f; do " +
                  "  f=\"${f/#\\~/$HOME}\"; " +
                  "  case \"$f\" in /*) ;; *) f=\"$dir/$f\" ;; esac; " +
                  "  echo; " +
                  "  if [ -f \"$f\" ]; then cat \"$f\" 2>/dev/null; " +
                  "  elif [ -f \"$f.lua\" ]; then cat \"$f.lua\" 2>/dev/null; fi; " +
                  "done"
        reader.command = ["sh", "-c", cmd]
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
                let result = root.parseHyprland(text)
                root.entries = result.entries
                root.curated = result.curated
                if (root.entries.length === 0) {
                    root.loadError = "No se encontraron llamadas \"hl.bind(...)\" resolubles en el archivo"
                }
            }
        }
    }

    // --- utilidades de parseo de una expresión Lua "a mano" ---

    // Dado un texto completo y el índice del "(" que abre una llamada,
    // devuelve el contenido entre paréntesis (sin incluirlos), respetando
    // paréntesis/llaves/corchetes anidados y strings entre comillas.
    function extractBalanced(text, openIdx) {
        let depth = 0
        let inStr = false
        let strCh = ""
        for (let i = openIdx; i < text.length; i++) {
            let c = text[i]
            if (inStr) {
                if (c === strCh && text[i - 1] !== "\\") inStr = false
                continue
            }
            if (c === "\"" || c === "'") { inStr = true; strCh = c; continue }
            if (c === "(") { depth++; continue }
            if (c === ")") {
                depth--
                if (depth === 0) return text.slice(openIdx + 1, i)
                continue
            }
        }
        return null
    }

    // Separa por comas de nivel superior (ignora comas dentro de
    // paréntesis/llaves/corchetes/strings anidados)
    function splitTopLevel(s) {
        let parts = []
        let depth = 0
        let inStr = false
        let strCh = ""
        let current = ""
        for (let i = 0; i < s.length; i++) {
            let c = s[i]
            if (inStr) {
                current += c
                if (c === strCh && s[i - 1] !== "\\") inStr = false
                continue
            }
            if (c === "\"" || c === "'") { inStr = true; strCh = c; current += c; continue }
            if (c === "(" || c === "{" || c === "[") { depth++; current += c; continue }
            if (c === ")" || c === "}" || c === "]") { depth--; current += c; continue }
            if (c === "," && depth === 0) { parts.push(current); current = ""; continue }
            current += c
        }
        if (current.trim().length > 0) parts.push(current)
        return parts.map(p => p.trim())
    }

    // Intenta resolver el primer argumento de hl.bind(...) a un string
    // concreto: literal directo, o concatenación con "..''" de literales y
    // variables "local NOMBRE = "valor"" conocidas. Devuelve null si no
    // se puede resolver (ej. viene de una variable de loop).
    function resolveCombo(expr, locals) {
        let parts = expr.split("..").map(p => p.trim())
        let out = []
        for (let p of parts) {
            let lit = p.match(/^"([^"]*)"$/) || p.match(/^'([^']*)'$/)
            if (lit) { out.push(lit[1]); continue }
            if (Object.prototype.hasOwnProperty.call(locals, p)) { out.push(locals[p]); continue }
            return null
        }
        return out.join("").replace(/\s+/g, " ").trim().replace(/\s*\+\s*/g, "+")
    }

    // Genera una descripción legible del segundo argumento de
    // hl.bind(...) (el dispatcher). Devuelve null si es algo que no se
    // puede resumir sin ejecutar Lua (ej. una función anónima).
    function describeDispatcher(expr, locals) {
        let e = expr.trim()

        let exec = e.match(/^hl\.dsp\.exec_cmd\(([\s\S]*)\)$/)
        if (exec) {
            let arg = exec[1].trim()
            let lit = arg.match(/^"([^"]*)"$/) || arg.match(/^'([^']*)'$/)
            if (lit) return "Ejecutar: " + lit[1]
            if (Object.prototype.hasOwnProperty.call(locals, arg)) return "Ejecutar: " + locals[arg]
            return "Ejecutar: " + arg
        }

        let dsp = e.match(/^hl\.dsp\.([a-zA-Z0-9_.]+)\(/)
        if (dsp) {
            let words = dsp[1].replace(/[._]/g, " ")
            return words.charAt(0).toUpperCase() + words.slice(1)
        }

        return null
    }

    // --- respaldo: sintaxis clásica hyprlang (hyprland.conf, Hyprland
    // anterior a 0.55). Se intenta SOLO si el parseo de Lua no encontró
    // ningún "hl.bind(...)" — así, si apuntás configPath a un
    // hyprland.conf viejo (o todavía no migraste a Lua), el visor igual
    // funciona sin que tengas que cambiar nada más.
    function parseHyprConfLegacy(text) {
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
                let combo = (mods.length > 0 ? mods.split(/\s+/).concat([key]) : [key]).join("+")
                let dispatcher = bindMatch[3].trim()
                let args = (bindMatch[4] || "").trim()
                let action = dispatcher === "exec"
                    ? "Ejecutar: " + args
                    : (dispatcher.charAt(0).toUpperCase() + dispatcher.slice(1) + (args.length > 0 ? " (" + args + ")" : ""))

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

    function parseHyprland(text) {
        let lua = root.parseHyprLua(text)
        if (lua.entries.length > 0) return lua
        return root.parseHyprConfLegacy(text)
    }

    function parseHyprLua(text) {
        // 1) variables locales tipo string: local NOMBRE = "valor"
        let locals = {}
        let localRe = /local\s+(\w+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g
        let lm
        while ((lm = localRe.exec(text)) !== null) {
            locals[lm[1]] = lm[2] !== undefined ? lm[2] : lm[3]
        }

        let lines = text.split("\n")
        let offset = 0
        let lineOffsets = lines.map(l => { let o = offset; offset += l.length + 1; return o })

        let annotated = []
        let annCategory = ""
        let annTitle = null
        let fallback = []
        let fbCategory = ""

        for (let i = 0; i < lines.length; i++) {
            let trimmed = lines[i].trim()
            if (trimmed.length === 0) continue

            let catMatch = trimmed.match(/^--\s*@category\s+(.+)$/)
            if (catMatch) { annCategory = catMatch[1].trim(); annTitle = null; continue }

            let titleMatch = trimmed.match(/^--\s*@title\s+(.+)$/)
            if (titleMatch) { annTitle = titleMatch[1].trim(); continue }

            if (trimmed.startsWith("--")) {
                let t = trimmed.replace(/^--\s?/, "")
                fbCategory = fbCategory ? fbCategory + " " + t : t
                continue
            }

            let callIdx = lines[i].indexOf("hl.bind(")
            if (callIdx === -1) { fbCategory = ""; continue }

            let absOpen = lineOffsets[i] + callIdx + "hl.bind".length
            let inner = root.extractBalanced(text, absOpen)
            if (inner === null) { fbCategory = ""; continue }

            let args = root.splitTopLevel(inner)
            if (args.length < 2) { fbCategory = ""; continue }

            let combo = root.resolveCombo(args[0], locals)
            if (combo === null) {
                // combo dinámico (ej. generado en un for) -> no listable
                annTitle = null
                fbCategory = ""
                continue
            }

            if (annTitle !== null) {
                annotated.push({ combo: combo, desc: annTitle, category: annCategory })
                annTitle = null
            }

            let desc = root.describeDispatcher(args[1], locals)
            if (desc !== null) {
                fallback.push({ combo: combo, desc: desc, category: fbCategory })
            }
            fbCategory = ""
        }

        let useCurated = annotated.length > 0
        return {
            entries: useCurated ? annotated : fallback,
            curated: useCurated
        }
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

    // Absorbe clicks internos para que no se propaguen al fondo (que cierra el popup)
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
                text: "Atajos de teclado (Hyprland)"
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
                : "Sin anotaciones \"@title\" — mostrando lo que se pudo interpretar automáticamente (puede ser incompleto en Lua)"
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
