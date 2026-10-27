import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(10)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property int secondsLeft: 5

    // Teclado (Fix 33: antes solo se podia con el mouse): Escape cancela,
    // Return acepta. Este Rectangle gana el foco cuando la ventana del
    // host (keyboardFocus: Exclusive) queda visible.
    focus: true
    Keys.onEscapePressed: PendingAction.cancel()
    Keys.onEnterPressed: PendingAction.executeNow()

    // Absorbe clicks internos (no hace falta que cierre nada, solo evita
    // que el click "atraviese" hacia lo que esté debajo)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        running: PendingAction.open
        onTriggered: {
            root.secondsLeft -= 1
            if (root.secondsLeft <= 0) {
                countdown.stop()
                PendingAction.executeNow()
            }
        }
    }

    Connections {
        target: PendingAction
        function onOpenChanged() {
            if (PendingAction.open) root.secondsLeft = 5
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(20)
        spacing: Scaling.px(14)

        Text {
            text: PendingAction.label
            color: "#f5e0dc"
            font.bold: true
            font.pixelSize: Scaling.px(16)
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Text {
            text: "Se ejecutará en " + root.secondsLeft + "s"
            color: "#cdd6f4"
            font.pixelSize: Scaling.px(13)
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Scaling.px(12)

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Scaling.px(34)
                radius: Scaling.px(6)
                color: cancelArea.containsMouse ? "#45475a" : "#313244"

                Text {
                    anchors.centerIn: parent
                    text: "Cancelar"
                    color: "#cdd6f4"
                    font.pixelSize: Scaling.px(13)
                }

                MouseArea {
                    id: cancelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: PendingAction.cancel()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Scaling.px(34)
                radius: Scaling.px(6)
                color: okArea.containsMouse ? "#a6adc8" : "#89b4fa"

                Text {
                    anchors.centerIn: parent
                    text: "Aceptar ahora"
                    color: "#1e1e2e"
                    font.bold: true
                    font.pixelSize: Scaling.px(13)
                }

                MouseArea {
                    id: okArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: PendingAction.executeNow()
                }
            }
        }
    }
}
