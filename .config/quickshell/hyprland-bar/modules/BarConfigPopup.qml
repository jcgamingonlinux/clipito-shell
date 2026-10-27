import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property bool open: false
    signal closeRequested()
    color: "#1e1e2e"
    radius: Scaling.px(10)
    border.color: "#45475a"
    border.width: Scaling.px(1)

    function labelFor(id) {
        const names = { menu: "Menú", workspaces: "Espacios", activeWindow: "Ventana activa", cpu: "CPU", ram: "RAM", temp: "Temperatura", volume: "Volumen", network: "Red", systray: "Bandeja", notifications: "Notificaciones", keybinds: "Atajos", config: "Ajustes", battery: "Batería", clock: "Reloj", power: "Energía" }
        return names[id] || id
    }
    function nextZone(zone) { return zone === "left" ? "center" : (zone === "center" ? "right" : "left") }
    function zoneLabel(zone) { return zone === "left" ? "Izq." : (zone === "center" ? "Centro" : "Der.") }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(16)
        spacing: Scaling.px(16)

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Configuración de la barra"
                color: "#cdd6f4"
                font.bold: true
                font.pixelSize: Scaling.px(18)
                Layout.fillWidth: true
            }
            Rectangle {
                implicitWidth: Scaling.px(22)
                implicitHeight: Scaling.px(22)
                radius: Scaling.px(4)
                color: closeHoverConfig.containsMouse ? "#f38ba8" : "#313244"
                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Scaling.px(11)
                    color: closeHoverConfig.containsMouse ? "#1e1e2e" : "#cdd6f4"
                }
                MouseArea {
                    id: closeHoverConfig
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.closeRequested()
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#45475a" }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Posición"; color: "#cdd6f4"; Layout.fillWidth: true }
            Button { text: "Arriba"; checkable: true; checked: !BarConfig.barAtBottom; onClicked: { BarConfig.barAtBottom = false; BarConfig.save() } }
            Button { text: "Abajo"; checkable: true; checked: BarConfig.barAtBottom; onClicked: { BarConfig.barAtBottom = true; BarConfig.save() } }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Auto-ocultar"; color: "#cdd6f4"; Layout.fillWidth: true }
            Text {
                text: "La barra se oculta sola tras un momento sin uso y reaparece al acercar el mouse al borde."
                color: "#a6adc8"
                font.pixelSize: Scaling.px(11)
                Layout.preferredWidth: Scaling.px(220)
                wrapMode: Text.Wrap
            }
            CheckBox { checked: BarConfig.autoHide; onToggled: { BarConfig.autoHide = checked; BarConfig.save() } }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Escala: " + BarConfig.scalePercent + "%"; color: "#cdd6f4"; Layout.fillWidth: true }
            Slider {
                from: 70; to: 160; stepSize: 5; value: BarConfig.scalePercent
                onMoved: { BarConfig.scalePercent = Math.round(value); BarConfig.save() }
                Layout.preferredWidth: Scaling.px(180)
            }
        }
        Text { text: "Módulos: ←/→ ordena; zona rota Izq. → Centro → Der."; color: "#a6adc8"; font.pixelSize: Scaling.px(13) }
        Text {
            visible: !BarConfig.modules.some(function(m) { return m.id === "config" && m.enabled })
                && !BarConfig.modules.some(function(m) { return m.id === "configDock" && m.enabled })
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: "#f9e2af"
            font.pixelSize: Scaling.px(12)
            text: "⚠ Ocultaste los módulos \"Ajustes\" y \"Config\": para volver a abrir este panel usá el atajo de teclado de Ajustes, o el del Dock de Config (ambos en el snippet de tu compositor), o corré `quickshell ipc call bar-config toggle`."
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Column {
                width: parent.width
                spacing: Scaling.px(8)
                Repeater {
                    model: BarConfig.modules
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: Scaling.px(34)
                        radius: Scaling.px(5)
                        color: "#313244"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Scaling.px(5)
                            spacing: Scaling.px(5)
                            CheckBox { checked: modelData.enabled; onToggled: BarConfig.update(index, { enabled: checked }) }
                            Text { text: root.labelFor(modelData.id); color: "#cdd6f4"; Layout.fillWidth: true }
                            Button { text: "←"; enabled: index > 0; onClicked: BarConfig.move(index, -1) }
                            Button { text: "→"; enabled: index < BarConfig.modules.length - 1; onClicked: BarConfig.move(index, 1) }
                            Button { text: root.zoneLabel(modelData.zone); onClicked: BarConfig.update(index, { zone: root.nextZone(modelData.zone) }) }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Button { text: "Restaurar"; onClicked: BarConfig.reset() }
            Item { Layout.fillWidth: true }
            Button { text: "Cerrar"; onClicked: root.closeRequested() }
        }
    }
}
