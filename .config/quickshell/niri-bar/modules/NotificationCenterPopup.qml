import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    // Controlado por quien instancia este componente, igual que el
    // launcher/power menu: permite dar foco de teclado al abrir y
    // resetear la selección.
    property bool open: false

    property int selectedIndex: 0

    function clampSelection() {
        if (Notifications.history.length === 0) {
            root.selectedIndex = 0
        } else if (root.selectedIndex >= Notifications.history.length) {
            root.selectedIndex = Notifications.history.length - 1
        } else if (root.selectedIndex < 0) {
            root.selectedIndex = 0
        }
    }

    function deleteSelected() {
        if (Notifications.history.length === 0) return
        let entry = Notifications.history[root.selectedIndex]
        if (entry) Notifications.removeFromHistory(entry.historyId)
    }

    onOpenChanged: {
        if (root.open) {
            root.selectedIndex = 0
            root.forceActiveFocus()
        }
    }

    // Si se borra una notificación (desde acá o desde otro lado), la
    // selección se ajusta para no quedar apuntando fuera de rango.
    Connections {
        target: Notifications
        function onHistoryChanged() { root.clampSelection() }
    }

    focus: true
    Keys.onEscapePressed: Bridge.notificationsOpen = false
    Keys.onUpPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)
    Keys.onDownPressed: root.selectedIndex = Math.min(Notifications.history.length - 1, root.selectedIndex + 1)
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_X) {
            root.deleteSelected()
            event.accepted = true
        }
    }

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el desplegable al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(10)
        spacing: Scaling.px(8)

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Notificaciones"
                color: "#f5e0dc"
                font.bold: true
                font.pixelSize: Scaling.px(13)
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "Limpiar todas"
                color: "#89b4fa"
                font.pixelSize: Scaling.px(11)

                MouseArea {
                    anchors.fill: parent
                    onClicked: Notifications.clearHistory()
                }
            }
        }

        Text {
            visible: Notifications.history.length > 0
            text: "↑↓: moverse · X: borrar"
            color: "#9399b2"
            font.pixelSize: Scaling.px(10)
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Scaling.px(6)
            model: Notifications.history
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: true

            delegate: Rectangle {
                id: delegateRoot
                required property var modelData
                required property int index
                width: list.width
                implicitHeight: col.implicitHeight + 12
                radius: Scaling.px(6)
                color: (delegateRoot.index === root.selectedIndex) ? "#45475a" : "#313244"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Scaling.px(6)
                    spacing: Scaling.px(6)

                    ColumnLayout {
                        id: col
                        Layout.fillWidth: true
                        spacing: Scaling.px(2)

                        Text {
                            text: delegateRoot.modelData.appName + (delegateRoot.modelData.summary ? " — " + delegateRoot.modelData.summary : "")
                            color: "#f5e0dc"
                            font.bold: true
                            font.pixelSize: Scaling.px(11)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: delegateRoot.modelData.body.length > 0
                            text: delegateRoot.modelData.body
                            color: "#cdd6f4"
                            font.pixelSize: Scaling.px(11)
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }

                    // Botón X: borra solo esta notificación del historial
                    Rectangle {
                        Layout.preferredWidth: Scaling.px(20)
                        Layout.preferredHeight: Scaling.px(20)
                        Layout.alignment: Qt.AlignTop
                        radius: Scaling.px(4)
                        color: deleteArea.containsMouse ? "#f38ba8" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: deleteArea.containsMouse ? "#1e1e2e" : "#9399b2"
                            font.pixelSize: Scaling.px(11)
                        }

                        MouseArea {
                            id: deleteArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Notifications.removeFromHistory(delegateRoot.modelData.historyId)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: root.selectedIndex = delegateRoot.index
                }
            }
        }

        Text {
            visible: Notifications.history.length === 0
            text: "Sin notificaciones recientes"
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
        }
    }
}
