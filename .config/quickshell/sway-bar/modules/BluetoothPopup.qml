import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Bluetooth

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: root.adapter !== null && root.adapter !== undefined

    // Absorbe clicks internos para que no se propaguen al fondo (que
    // cierra el popup al hacer click afuera).
    MouseArea { anchors.fill: parent; onClicked: {} }

    function startScan() {
        // La discovery es "propiedad" del cliente D-Bus que la inició
        // (BlueZ >= 5.66): cuando ese cliente se desconecta, el escaneo
        // se detiene. "bluetoothctl scan on" (forma argumentos) sale
        // enseguida si stdin no es TTY, así que la discovery nunca
        // quedaba activa. Solución: enviar el comando por stdin y
        // mantener el pipe abierto 8s; al cerrar el pipe, bluetoothctl
        // sale y BlueZ detiene el scan solo. Los dispositivos que se
        // encuentran aparecen solos en adapter.devices (Quickshell
        // escucha los cambios de BlueZ por D-Bus).
        scanner.command = ["sh", "-c", "(printf \'scan on\\n\'; sleep 8) | bluetoothctl >/dev/null 2>&1"]
        scanner.running = true
    }
    Process { id: scanner }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(12)
        spacing: Scaling.px(8)

        Text {
            text: "Bluetooth"
            color: "#f5e0dc"
            font.bold: true
            font.pixelSize: Scaling.px(13)
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            visible: !root.available
            text: "No se detectó ningún adaptador de Bluetooth en este equipo."
            color: "#9399b2"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        RowLayout {
            visible: root.available
            Layout.fillWidth: true
            Text {
                text: root.available && root.adapter.enabled ? "Encendido" : "Apagado"
                color: "#cdd6f4"
                Layout.fillWidth: true
            }
            CheckBox {
                checked: root.available && root.adapter.enabled
                onToggled: if (root.available) root.adapter.enabled = checked
            }
        }

        Button {
            visible: root.available && root.adapter.enabled
            text: "Buscar dispositivos (8s)"
            Layout.fillWidth: true
            onClicked: root.startScan()
        }

        ListView {
            id: devicesList
            visible: root.available && root.adapter.enabled
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Scaling.px(4)
            model: root.available ? root.adapter.devices : []

            ScrollBar.vertical: ScrollBar {
                policy: devicesList.contentHeight > devicesList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            delegate: Rectangle {
                id: delegateRoot
                required property var modelData
                width: devicesList.width - Scaling.px(14)
                height: Scaling.px(38)
                radius: Scaling.px(6)
                color: hoverArea.containsMouse ? "#313244" : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Scaling.px(8)
                    anchors.rightMargin: Scaling.px(8)
                    spacing: Scaling.px(8)

                    Text {
                        text: delegateRoot.modelData.state === BluetoothDeviceState.Connected ? "\uf293" : "\uf294"
                        font.family: "JetBrainsMono Nerd Font"
                        color: delegateRoot.modelData.state === BluetoothDeviceState.Connected ? "#89b4fa" : "#9399b2"
                        font.pixelSize: Scaling.px(12)
                    }
                    Text {
                        text: delegateRoot.modelData.name || "(sin nombre)"
                        color: "#cdd6f4"
                        font.pixelSize: Scaling.px(12)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: delegateRoot.modelData.batteryAvailable === true
                        text: Math.round((delegateRoot.modelData.battery || 0) * 100) + "%"
                        color: "#9399b2"
                        font.pixelSize: Scaling.px(10)
                    }
                    Button {
                        text: delegateRoot.modelData.state === BluetoothDeviceState.Connected ? "Desconectar" : "Conectar"
                        onClicked: {
                            if (delegateRoot.modelData.state === BluetoothDeviceState.Connected)
                                delegateRoot.modelData.disconnect()
                            else
                                delegateRoot.modelData.connect()
                        }
                    }
                }

                MouseArea { id: hoverArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
            }
        }

        Text {
            visible: root.available && root.adapter.enabled && root.adapter.devices.values.length === 0
            text: "Sin dispositivos emparejados. Usá \"Buscar dispositivos\" o emparejá con bluetoothctl."
            color: "#9399b2"
            wrapMode: Text.Wrap
            font.pixelSize: Scaling.px(11)
            Layout.fillWidth: true
        }
    }
}
