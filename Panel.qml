// io.github.cyprusad.voxtype-hal — color picker panel.
//
// Swatches write assets/lens.json (consumed live by Hal.qml, no daemon
// restart needed). This panel only changes the eye's hue — install and
// revert stay in ./install.sh and ./uninstall.sh.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "io.github.cyprusad.voxtype-hal"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property bool halActive: false
    property string lensMode: "hal"
    property string lensColor: "#FF2D2D"

    function open() { root.controller.show(); }
    function close() { root.controller.hide(); }
    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction);
        return false;
    }
    function refreshFromWidget(active, mode, color) {
        halActive = active;
        lensMode = mode;
        lensColor = color;
    }
    function selected(swatch) {
        if (swatch.mode !== lensMode) return false;
        if (swatch.mode !== "custom") return true;
        return String(swatch.color || "").toLowerCase() === String(lensColor || "").toLowerCase();
    }

    // mode "" means: match current lens.json mode for the checkmark
    readonly property var swatches: [
        { label: "HAL Red",  mode: "hal",    color: "#FF2D2D", dot: "#FF2D2D" },
        { label: "System",   mode: "theme",  color: "",        dot: "#8AB4FF" },
        { label: "Amber",    mode: "custom", color: "#FFB84D", dot: "#FFB84D" },
        { label: "Ice Blue", mode: "custom", color: "#66C7FF", dot: "#66C7FF" },
        { label: "Violet",   mode: "custom", color: "#B48CFF", dot: "#B48CFF" }
    ]

    function applySwatch(mode, color) {
        var home = Quickshell.env("HOME") || "";
        if (home.length === 0) return;
        var lensFile = home + "/.config/voxtype/osd/voxtype-hal/assets/lens.json";
        var payload = JSON.stringify({ mode: mode, color: color || "#FF2D2D" });
        applyProcess.command = ["sh", "-c",
            "mkdir -p \"$(dirname '" + lensFile.replace(/'/g, "'\\''") + "')\" && printf '%s' '" + payload.replace(/'/g, "'\\''") + "' > '" + lensFile.replace(/'/g, "'\\''") + "'"];
        applyProcess.running = true;
        lensMode = mode;
        lensColor = color || "#FF2D2D";
    }

    Process {
        id: applyProcess
        running: false
        onExited: function(exitCode) {
            statusLine.text = exitCode === 0
                ? (root.halActive ? "Eye updated — speak to see it." : "Saved. Re-apply the eye with ./install.sh to see it.")
                : "Write failed (exit " + exitCode + ").";
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(280))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction); }

            Column {
                id: content
                width: parent.width
                spacing: Style.space(8)

                Text {
                    width: parent.width
                    text: "HAL Eye"
                    color: root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                }

                Text {
                    id: statusLine
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: root.halActive ? "Eye active — pick a hue." : "Eye not applied (./install.sh to enable)."
                    color: root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                }

                Grid {
                    width: parent.width
                    columns: 5
                    spacing: Style.space(8)

                    Repeater {
                        model: root.swatches
                        delegate: Column {
                            required property var modelData
                            spacing: 2
                            width: 44

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: modelData.dot
                                border.width: root.selected(modelData) ? 2 : 1
                                border.color: root.selected(modelData) ? root.barForeground : "#666666"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applySwatch(modelData.mode, modelData.color)
                                }
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: 10
                                color: root.barForeground
                                text: modelData.label
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 10
                    color: root.barForeground
                    opacity: 0.7
                    text: "System follows your Omarchy theme. Full revert: ./uninstall.sh in the repo."
                }
            }
        }
    }
}
