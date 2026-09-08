// io.github.cyprusad.voxtype-hal — bar widget entry point.
//
// A small eye dot for the bar: HAL red while the eye is the active OSD,
// grey otherwise. Click toggles the color panel. Status re-checked on
// open and every 30 s so the dot tracks `voxtype config` changes made
// elsewhere (TUI, scripts).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarWidget {
    id: root
    moduleName: "io.github.cyprusad.voxtype-hal"

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    property bool halActive: false
    property string lensMode: "hal"

    function open() { if (panelLoader.item) panelLoader.item.open(); }
    function close() { if (panelLoader.item) panelLoader.item.close(); }
    function toggle() { if (panelLoader.item) panelLoader.item.toggle(); }
    function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch(); }

    function injectPanel() {
        if (!panelLoader.item) return;
        panelLoader.item.bar = root.bar;
        panelLoader.item.anchorItem = button;
        panelLoader.item.hostWidget = root;
    }

    function refreshStatus() {
        if (!statusProcess.running) statusProcess.running = true;
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()
    Component.onCompleted: refreshStatus()

    Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: root.refreshStatus()
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel();
            Qt.callLater(root.injectPanel);
        }
    }

    // Reads the live voxtype config; never writes.
    Process {
        id: statusProcess
        command: ["sh", "-c", "voxtype config get osd.style 2>/dev/null; echo ---; cat ~/.config/voxtype/osd/voxtype-hal/assets/lens.json 2>/dev/null"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            property string buf: ""
            onRead: function(data) { buf += (data || "") + "\n"; }
        }
        onExited: function() {
            var parts = statusProcess.stdout.buf.split("---");
            var style = (parts[0] || "").trim();
            root.halActive = style.length > 0 && style.indexOf("voxtype-hal") >= 0;
            try {
                var o = JSON.parse((parts[1] || "").trim() || "{}");
                root.lensMode = String(o.mode || "hal");
                var hx = String(o.color || "#FF2D2D");
                if (panelLoader.item && "refreshFromWidget" in panelLoader.item) {
                    panelLoader.item.refreshFromWidget(root.halActive, root.lensMode, hx);
                }
            } catch (e) {
                root.lensMode = "hal";
                if (panelLoader.item && "refreshFromWidget" in panelLoader.item) {
                    panelLoader.item.refreshFromWidget(root.halActive, "hal", "#FF2D2D");
                }
            }
            statusProcess.stdout.buf = "";
        }
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.halActive ? "◉" : "○"
        tooltipText: root.halActive ? "HAL eye OSD — open color picker" : "Voxtype HAL eye (inactive)"
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) {
                root.refreshStatus();
                root.toggle();
            }
        }
    }
}
