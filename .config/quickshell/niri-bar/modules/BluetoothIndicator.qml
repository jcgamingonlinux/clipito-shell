import QtQuick
import Quickshell.Bluetooth

Item {
    // Nombre de la pantalla en la que vive esta instancia (la coloca
    // BarModule.qml). La usa Scaling.pxFor() para escalar según la
    // resolucion de ESTA pantalla en vez de la que tiene el foco.
    property string screenName: ""
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    // Si no hay ningún adaptador de Bluetooth detectado (equipo de
    // escritorio sin uno, por ejemplo), el módulo entero queda oculto --
    // igual que el módulo de Batería en equipos sin batería.
    readonly property bool available: root.adapter !== null && root.adapter !== undefined
    readonly property bool btEnabled: root.available && root.adapter.enabled
    readonly property var connectedDevices: root.available
        ? root.adapter.devices.values.filter(function(d) { return d.state === BluetoothDeviceState.Connected })
        : []

    function reportPos() {
        if (root.screenName.length === 0) return
        if (root.screenName !== FocusedScreen.name) return
        let pos = root.mapToItem(null, 0, root.height)
        BarPositions.bluetoothX = pos.x
        BarPositions.bluetoothWidth = root.width
    }
    onXChanged: root.reportPos()
    onWidthChanged: root.reportPos()
    Component.onCompleted: Qt.callLater(root.reportPos)
    Timer { interval: 2000; running: true; repeat: true; onTriggered: root.reportPos() }

    visible: root.available
    implicitWidth: root.available ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: Scaling.pxFor(screenName, 4)

        Text {
            text: "\uf293"
            font.family: "JetBrainsMono Nerd Font"
            // #0082FC es el azul característico de la marca Bluetooth
            // (no hay un hex oficial publicado, pero es el que citan las
            // guías de marca no oficiales a partir del Pantone 2925 C).
            color: root.btEnabled ? "#0082FC" : "#6c7086"
            font.pixelSize: Scaling.pxFor(screenName, 12)
        }
        Text {
            visible: root.btEnabled && root.connectedDevices.length > 0
            text: root.connectedDevices.length === 1
                ? root.connectedDevices[0].name
                : (root.connectedDevices.length + " conectados")
            color: "#89b4fa"
            font.pixelSize: Scaling.pxFor(screenName, 12)
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Bridge.togglePopup("bluetoothPopupOpen")
    }
}
