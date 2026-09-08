// io.github.cyprusad.vox-hal — headless service.
//
// Applies the HAL 9000 eye as the Voxtype dictation OSD exactly once:
// copies Hal.qml + voxtype-osd.toml next to the voxtype config, points
// [osd] at them, silences the "recording stopped" notification (the eye
// shows state now), and restarts the voxtype daemon.
//
// Idempotent: does nothing when the HAL eye is already active, and does
// nothing when the user opted out via uninstall.sh (sentinel file).
// Manual install/revert equivalent: ./install.sh / ./uninstall.sh.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string moduleName: "io.github.cyprusad.vox-hal"
    property var shell: null
    property var manifest: null

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string pluginDir: String(Qt.resolvedUrl("Service.qml"))
        .replace(/^file:\/\//, "").replace(/\/Service\.qml$/, "")
    readonly property string targetDir: home + "/.config/voxtype/osd/voxtype-hal"
    readonly property string sentinel: home + "/.config/voxtype/osd/.hal-disabled"

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function applyScript() {
        var pd = shQuote(pluginDir), td = shQuote(targetDir), sent = shQuote(sentinel);
        return "if [ -f " + sent + " ]; then echo SKIPPED_DISABLED; exit 0; fi\n"
            + "cur=$(voxtype config get osd.style 2>/dev/null)\n"
            + "if [ \"$cur\" = " + td + " ]; then echo ALREADY; exit 0; fi\n"
            + "mkdir -p " + td + " " + td + "/assets\n"
            + "cp " + pd + "/voxtype-osd.toml " + pd + "/Hal.qml " + td + "/\n"
            + "if [ ! -f " + td + "/assets/lens.json ]; then cp " + pd + "/assets/lens.json " + td + "/assets/lens.json; fi\n"
            + "voxtype config set osd.frontend quickshell >/dev/null\n"
            + "voxtype config set osd.style " + td + " >/dev/null\n"
            + "voxtype config set osd.palette omarchy >/dev/null\n"
            + "voxtype config set osd.layout custom >/dev/null\n"
            + "voxtype config set output.notification.on_recording_stop false >/dev/null\n"
            + "systemctl --user restart voxtype\n"
            + "echo APPLIED";
    }

    Component.onCompleted: {
        if (home.length === 0) {
            console.warn("[voxtype-hal] HOME unset, skipping auto-apply");
            return;
        }
        applyProcess.running = true;
    }

    Process {
        id: applyProcess
        command: ["sh", "-c", root.applyScript()]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                var line = (data || "").trim();
                if (line.length > 0) console.log("[voxtype-hal] " + line);
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                var line = (data || "").trim();
                if (line.length > 0) console.warn("[voxtype-hal] " + line);
            }
        }
    }
}
