import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el calendario al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    property date viewDate: new Date()

    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
    function leadingOffset(y, m) {
        // Lunes = 0 ... Domingo = 6
        return (new Date(y, m, 1).getDay() + 6) % 7
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(12)
        spacing: Scaling.px(8)

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "‹"
                color: "#cdd6f4"
                font.pixelSize: Scaling.px(16)
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() - 1, 1)
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                color: "#f5e0dc"
                font.bold: true
                font.pixelSize: Scaling.px(13)
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "›"
                color: "#cdd6f4"
                font.pixelSize: Scaling.px(16)
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + 1, 1)
                }
            }
        }

        GridLayout {
            columns: 7
            columnSpacing: Scaling.px(4)
            rowSpacing: Scaling.px(4)
            Layout.fillWidth: true

            Repeater {
                model: ["L", "M", "X", "J", "V", "S", "D"]
                delegate: Text {
                    text: modelData
                    color: "#9399b2"
                    font.pixelSize: Scaling.px(11)
                    Layout.preferredWidth: Scaling.px(26)
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Repeater {
                model: root.leadingOffset(root.viewDate.getFullYear(), root.viewDate.getMonth())
                delegate: Item { Layout.preferredWidth: Scaling.px(26); Layout.preferredHeight: Scaling.px(22) }
            }

            Repeater {
                model: root.daysInMonth(root.viewDate.getFullYear(), root.viewDate.getMonth())
                delegate: Rectangle {
                    required property int index
                    Layout.preferredWidth: Scaling.px(26)
                    Layout.preferredHeight: Scaling.px(22)
                    radius: Scaling.px(4)

                    property bool isToday: {
                        let today = new Date()
                        return today.getFullYear() === root.viewDate.getFullYear() &&
                               today.getMonth() === root.viewDate.getMonth() &&
                               today.getDate() === (index + 1)
                    }
                    color: isToday ? "#89b4fa" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        color: isToday ? "#1e1e2e" : "#cdd6f4"
                        font.pixelSize: Scaling.px(11)
                    }
                }
            }
        }
    }
}
