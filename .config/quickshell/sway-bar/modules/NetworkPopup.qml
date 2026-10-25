import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Popup de red (fix 24, 2026-10-24): antes solo mostraba la IP local.
// Ahora, con NetworkManager instalado (network-manager en los instaladores):
//  - muestra la conexión actual (WiFi y/o cableada)
//  - lista las redes WiFi visibles (nmcli) con señal y candado
//  - permite conectar (con contraseña si hace falta), desconectar,
//    activar/apagar el radio y conectar redes ocultas
//  - si NM no está disponible, cae a leer /sys/class/net (como el indicador)
// Requiere WlrLayershell.keyboardFocus: Exclusive en la ventana contenedora
// (igual que el launcher) para que el TextField reciba teclas.
Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    // ─── estado ──────────────────────────────────────────────
    property bool nmAvailable: false
    property bool wifiRadioOn: false
    property string wifiSsid: ""     // SSID conectado ("" si no)
    property string wifiDev: ""      // interfaz wifi (p. ej. wlp2s0)
    property string ethDev: ""       // interfaz ethernet
    property string ethConn: ""      // nombre de la conexión cableada activa
    property string fbLine: ""       // fallback /sys cuando no hay NM
    property var wifiList: []        // [{ssid, signal, sec}]
    property var lanLines: []        // "dev: ip" (como el popup anterior)
    property var nmConnectedDevs: [] // devices que NM reporta connected
    property string pendingSsid: ""  // red en espera de contraseña
    property string pendingSec: ""   // su seguridad ("" = abierta)
    property string hiddenSsid: ""   // red oculta tipeada a mano
    property string busy: ""         // acción en curso
    property string lastAction: ""   // "connect" | "disconnect" | "radio"
    property string statusMsg: ""    // último resultado (✓/✗)

    // ─── scripts ─────────────────────────────────────────────
    readonly property string statusScript: `
printf 'SCAN\n'
if command -v nmcli >/dev/null 2>&1; then
    printf 'NM:1\n'
    printf 'RADIO:%s\n' "$(nmcli -g WIFI radio wifi 2>/dev/null)"
    nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status 2>/dev/null
else
    printf 'NM:0\n'
fi
# Interfaces up por /sys (excl. lo). NM puede dejarlas "unmanaged"
# (ifupdown/dhcpcd), así que el QML las deduplica contra lo que
# NM reporta como conectado.
for i in /sys/class/net/*/operstate; do
    dev=$(basename "$(dirname "$i")")
    [ "$dev" = "lo" ] && continue
    [ "$(cat "$i" 2>/dev/null)" = "up" ] || continue
    if [ -d "/sys/class/net/$dev/wireless" ]; then
        printf 'FBDEV:%s:wifi\n' "$dev"
    else
        printf 'FBDEV:%s:eth\n' "$dev"
    fi
done
`

    readonly property string wifiScript: `
command -v nmcli >/dev/null 2>&1 || exit 0
nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null
`

    readonly property string lanScript: `ip -4 -o addr show scope global 2>/dev/null | awk '{print $2": "$4}'`

    // ─── procesos ────────────────────────────────────────────
    Process {
        id: statusProc
        command: ["sh", "-c", root.statusScript]
        stdout: SplitParser {
            onRead: (line) => {
                let t = line.trim()
                if (t.length === 0) return
                if (t === "SCAN") {
                    // inicio de un scan nuevo: reseteo para no traer restos
                    root.nmAvailable = false
                    root.wifiRadioOn = false
                    root.wifiSsid = ""
                    root.wifiDev = ""
                    root.ethConn = ""
                    root.ethDev = ""
                    root.fbLine = ""
                    root.nmConnectedDevs = []
                    return
                }
                if (t === "NM:1") { root.nmAvailable = true; return }
                if (t === "NM:0") { root.nmAvailable = false; return }
                if (t.startsWith("RADIO:")) {
                    root.wifiRadioOn = (t.slice(6) === "enabled")
                    return
                }
                if (t.startsWith("FBDEV:")) {
                    // solo si NM no la tiene conectada (dedup)
                    let v = t.slice(6)
                    let idx = v.indexOf(":")
                    let fdev = idx > 0 ? v.slice(0, idx) : v
                    if (root.nmConnectedDevs.indexOf(fdev) < 0)
                        root.fbLine = root.fbLine === "" ? v : root.fbLine + ", " + v
                    return
                }
                // líneas "dev:type:state:conexión"
                let parts = t.split(":")
                if (parts.length < 3) return
                let dev = parts[0]
                let type = parts[1]
                let state = parts[2]
                let conn = parts.slice(3).join(":")
                if (type === "wifi" || type === "ethernet") {
                    let connected = (state.indexOf("connected") === 0)
                    if (type === "wifi") {
                        root.wifiDev = dev
                        root.wifiSsid = connected ? conn : ""
                    } else {
                        root.ethDev = dev
                        root.ethConn = connected ? conn : ""
                    }
                    if (connected) root.nmConnectedDevs = root.nmConnectedDevs.concat([dev])
                }
            }
        }
    }

    Process {
        id: wifiProc
        command: ["sh", "-c", root.wifiScript]
        stdout: SplitParser {
            onRead: (line) => {
                let t = line.trim()
                if (t.length === 0) return
                // "SSID:SIGNAL:SECURITY" (SSID vacío = red oculta, se saltea)
                let parts = t.split(":")
                if (parts.length < 2 || parts[0].length === 0) return
                let l = root.wifiList.slice()
                l.push({ ssid: parts[0], signal: parts[1], sec: parts.slice(2).join(":") })
                root.wifiList = l
            }
        }
    }

    Process {
        id: lanProc
        command: ["sh", "-c", root.lanScript]
        stdout: SplitParser {
            onRead: (line) => {
                let t = line.trim()
                if (t.length === 0) return
                let l = root.lanLines.slice()
                l.push(t)
                root.lanLines = l
            }
        }
    }

    // Proceso "comando suelto" (conectar / desconectar / radio wifi)
    Process {
        id: connProc
        stdout: StdioCollector {
            onStreamFinished: {
                let t = text.trim()
                let action = root.lastAction
                root.busy = ""
                root.lastAction = ""
                let ok = t.indexOf("Error") < 0
                let msg = ""
                if (action === "connect") {
                    ok = t.indexOf("successfully activated") >= 0
                    msg = ok ? "✓ Conectado a " + root.pendingSsid
                             : "✗ No se pudo conectar a " + root.pendingSsid
                } else if (action === "disconnect") {
                    msg = ok ? "✓ Desconectado" : "✗ No se pudo desconectar"
                } else if (action === "radio") {
                    msg = ok ? "✓ Wi-Fi " + (t.indexOf("enabled") >= 0 ? "activado" : "apagado")
                             : "✗ No se pudo cambiar el estado del Wi-Fi"
                }
                root.statusMsg = msg
                root.pendingSsid = ""
                root.pwField.text = ""
                root.refreshAll()
            }
        }
    }

    // ─── funciones ───────────────────────────────────────────
    function refreshAll() {
        root.wifiList = []
        root.lanLines = []
        statusProc.running = true
        wifiProc.running = true
        lanProc.running = true
    }

    function doConnect(pass) {
        let cmd = ["nmcli", "dev", "wifi", "connect", root.pendingSsid]
        if (pass.length > 0) cmd.push("password", pass)
        root.lastAction = "connect"
        root.busy = "Conectando a " + root.pendingSsid + "…"
        connProc.command = cmd
        connProc.running = true
    }

    function disconnectWifi() {
        if (root.wifiDev.length === 0) return
        root.lastAction = "disconnect"
        root.busy = "Desconectando…"
        connProc.command = ["nmcli", "dev", "disconnect", root.wifiDev]
        connProc.running = true
    }

    function toggleRadio() {
        if (!root.nmAvailable) return
        let on = !root.wifiRadioOn
        root.lastAction = "radio"
        root.busy = on ? "Activando Wi-Fi…" : "Apagando Wi-Fi…"
        connProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        connProc.running = true
    }

    function rowClicked(ssid, sec) {
        if (ssid.length === 0) return
        if (ssid === root.wifiSsid) { root.disconnectWifi(); return }
        root.pendingSsid = ssid
        root.pendingSec = sec
        root.statusMsg = ""
        root.pwField.text = ""
        if (sec.length === 0) {
            root.doConnect("")
        } else {
            root.pwField.forceActiveFocus()
        }
    }

    function connectHidden() {
        let s = root.hiddenSsid.trim()
        if (s.length === 0) return
        root.pendingSsid = s
        root.pendingSec = "?"  // fuerza la ventana de contraseña
        root.statusMsg = ""
        root.pwField.text = ""
        root.pwField.forceActiveFocus()
    }

    function anyConnected() {
        return root.wifiSsid.length > 0 || root.ethConn.length > 0
               || root.fbLine.length > 0
    }

    // Textualiza la línea de fallback ("dev: eth, dev2: wifi" → "LAN: dev · WiFi: dev2")
    function fbStatusText() {
        if (root.fbLine.length === 0) return ""
        let parts = []
        let entries = root.fbLine.split(", ")
        for (let j = 0; j < entries.length; j++) {
            let e = entries[j]
            let idx = e.lastIndexOf(":")
            let dev = idx > 0 ? e.slice(0, idx) : e
            let type = idx > 0 ? e.slice(idx + 1) : "eth"
            parts.push((type === "wifi" ? "WiFi: " : "LAN: ") + dev)
        }
        return parts.join("  ·  ")
    }

    function currentStatusText() {
        let parts = []
        if (root.wifiSsid.length > 0) parts.push("WiFi: " + root.wifiSsid)
        if (root.ethConn.length > 0) parts.push("LAN: " + root.ethConn)
        let fb = root.fbStatusText()
        if (fb.length > 0) parts.push(fb)
        if (parts.length === 0) return "Sin conexión"
        return parts.join("  ·  ")
    }

    // ─── apertura / teclado ──────────────────────────────────
    onOpenChanged: {
        if (!root.open) return
        root.refreshAll()
        Qt.callLater(() => {
            if (root.pendingSsid.length > 0) root.pwField.forceActiveFocus()
            else root.forceActiveFocus()
        })
    }

    Keys.onEscapePressed: root.closeRequested()

    // Auto-refresco mientras está abierto
    Timer {
        interval: 15000
        running: root.open
        repeat: true
        onTriggered: root.refreshAll()
    }

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el popup al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(10)
        spacing: Scaling.px(6)

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Red"
                color: "#f5e0dc"
                font.bold: true
                font.pixelSize: Scaling.px(13)
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "✕"
                color: "#9399b2"
                font.pixelSize: Scaling.px(11)
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Scaling.px(4)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

        // ── conexión actual ──
        Text {
            text: "Conexión actual"
            color: "#9399b2"
            font.pixelSize: Scaling.px(10)
            font.bold: true
        }
        Text {
            text: root.currentStatusText()
            color: root.anyConnected() ? "#a6e3a1" : "#f38ba8"
            font.pixelSize: Scaling.px(11)
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        // ── Wi-Fi ──
        ColumnLayout {
            visible: root.nmAvailable
            Layout.fillWidth: true
            spacing: Scaling.px(4)

            Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Wi-Fi"
                    color: "#9399b2"
                    font.pixelSize: Scaling.px(10)
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.wifiRadioOn ? "ON" : "OFF"
                    color: root.wifiRadioOn ? "#a6e3a1" : "#f38ba8"
                    font.pixelSize: Scaling.px(11)
                    font.bold: true
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Scaling.px(4)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleRadio()
                    }
                }
                Text {
                    text: "↻"
                    color: "#89b4fa"
                    font.pixelSize: Scaling.px(13)
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Scaling.px(4)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refreshAll()
                    }
                }
            }

            // lista de redes
            ListView {
                id: wifiView
                Layout.fillWidth: true
                Layout.preferredHeight: Scaling.px(168)
                spacing: 1
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.wifiList
                delegate: Item {
                    width: wifiView.width
                    height: Scaling.px(22)
                    property string ssid: modelData.ssid
                    property string signal: modelData.signal
                    property string sec: modelData.sec

                    Rectangle {
                        anchors.fill: parent
                        color: ma.containsMouse ? "#2a2b3d"
                               : (ssid === root.wifiSsid ? "#26283a" : "transparent")
                        radius: Scaling.px(4)
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Scaling.px(4)
                        anchors.rightMargin: Scaling.px(4)
                        spacing: Scaling.px(6)
                        Text {
                            text: (sec.length > 0 ? "🔒 " : "") + ssid
                            color: ssid === root.wifiSsid ? "#a6e3a1" : "#cdd6f4"
                            font.pixelSize: Scaling.px(11)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: signal
                            color: "#9399b2"
                            font.pixelSize: Scaling.px(10)
                        }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.rowClicked(ssid, sec)
                    }
                }
            }

            Text {
                visible: root.wifiList.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: Scaling.px(16)
                text: root.wifiRadioOn
                      ? "Sin redes visibles — probá ↻"
                      : "Wi-Fi apagado — tocá ON para activar"
                color: "#9399b2"
                font.pixelSize: Scaling.px(10)
                horizontalAlignment: Text.AlignHCenter
            }

            // red oculta
            RowLayout {
                Layout.fillWidth: true
                spacing: Scaling.px(4)
                Text {
                    text: "Red oculta:"
                    color: "#9399b2"
                    font.pixelSize: Scaling.px(10)
                }
                TextField {
                    id: hiddenField
                    Layout.fillWidth: true
                    placeholderText: "SSID"
                    text: root.hiddenSsid
                    onTextChanged: root.hiddenSsid = text
                    font.pixelSize: Scaling.px(11)
                    color: "#cdd6f4"
                    placeholderTextColor: "#6c7086"
                    background: Rectangle {
                        radius: Scaling.px(4)
                        color: "#181825"
                        border.color: hiddenField.activeFocus ? "#89b4fa" : "#45475a"
                        border.width: Scaling.px(1)
                    }
                    Keys.onReturnPressed: root.connectHidden()
                    Keys.onEscapePressed: root.closeRequested()
                }
                Rectangle {
                    width: hiddenOkLabel.implicitWidth + Scaling.px(12)
                    height: Scaling.px(20)
                    radius: Scaling.px(4)
                    color: hiddenOkMa.containsMouse ? "#45475a" : "#313244"
                    Text {
                        id: hiddenOkLabel
                        anchors.centerIn: parent
                        text: "Ir"
                        color: "#f5e0dc"
                        font.pixelSize: Scaling.px(11)
                    }
                    MouseArea {
                        id: hiddenOkMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.connectHidden()
                    }
                }
            }

            // panel de contraseña (visible solo con pendingSsid)
            Rectangle {
                visible: root.pendingSsid.length > 0
                Layout.fillWidth: true
                implicitHeight: pwCol.implicitHeight + 2 * Scaling.px(8)  # (fix 28) márgenes de pwCol
                color: "#181825"
                border.color: "#45475a"
                border.width: Scaling.px(1)
                radius: Scaling.px(6)

                ColumnLayout {
                    id: pwCol
                    anchors.fill: parent
                    anchors.margins: Scaling.px(8)
                    spacing: Scaling.px(4)

                    Text {
                        text: "Conectar a: " + root.pendingSsid
                        color: "#f5e0dc"
                        font.pixelSize: Scaling.px(11)
                        font.bold: true
                    }
                    TextField {
                        id: pwField
                        Layout.fillWidth: true
                        echoMode: TextField.Password
                        placeholderText: "Contraseña"
                        font.pixelSize: Scaling.px(11)
                        color: "#cdd6f4"
                        placeholderTextColor: "#6c7086"
                        background: Rectangle {
                            radius: Scaling.px(4)
                            color: "#1e1e2e"
                            border.color: pwField.activeFocus ? "#89b4fa" : "#45475a"
                            border.width: Scaling.px(1)
                        }
                        Keys.onReturnPressed: root.doConnect(pwField.text)
                        Keys.onEscapePressed: {
                            root.pendingSsid = ""
                            pwField.text = ""
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Scaling.px(4)
                        Rectangle {
                            width: connectLabel.implicitWidth + Scaling.px(16)
                            height: Scaling.px(22)
                            radius: Scaling.px(4)
                            color: connectMa.containsMouse ? "#45475a" : "#313244"
                            Text {
                                id: connectLabel
                                anchors.centerIn: parent
                                text: "Conectar"
                                color: "#f5e0dc"
                                font.pixelSize: Scaling.px(11)
                            }
                            MouseArea {
                                id: connectMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.doConnect(pwField.text)
                            }
                        }
                        Rectangle {
                            width: cancelLabel.implicitWidth + Scaling.px(16)
                            height: Scaling.px(22)
                            radius: Scaling.px(4)
                            color: cancelMa.containsMouse ? "#45475a" : "#313244"
                            Text {
                                id: cancelLabel
                                anchors.centerIn: parent
                                text: "Cancelar"
                                color: "#cdd6f4"
                                font.pixelSize: Scaling.px(11)
                            }
                            MouseArea {
                                id: cancelMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.pendingSsid = ""
                                    root.pwField.text = ""
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        // ── estado de la última acción ──
        Text {
            visible: root.busy !== "" || root.statusMsg !== ""
            Layout.fillWidth: true
            text: root.busy !== "" ? root.busy : root.statusMsg
            color: root.busy !== "" ? "#89b4fa"
                 : (root.statusMsg.indexOf("✓") === 0 ? "#a6e3a1" : "#f38ba8")
            font.pixelSize: Scaling.px(10)
            wrapMode: Text.Wrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

        // ── red cableada (IP) ──
        Text {
            text: "Red cableada"
            color: "#9399b2"
            font.pixelSize: Scaling.px(10)
            font.bold: true
        }
        Repeater {
            model: root.lanLines
            delegate: Text {
                text: modelData
                color: "#cdd6f4"
                font.pixelSize: Scaling.px(11)
            }
        }
        Text {
            visible: root.lanLines.length === 0
            text: "Sin direcciones IPv4 activas"
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
        }

        Item { Layout.fillHeight: true }
    }
}
