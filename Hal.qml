// Voxtype HAL-9000 experimental OSD.
// Everything lives inside the eye: red lens brightens with voice energy,
// surrounding arc = volume level (with held-peak tick),
// mini bars at the bottom of the lens = scrolling sound waves,
// timer pill at the top of the lens = elapsed dictation time.
// Nothing is drawn outside the circle, over the desktop background.
//
// Contract from OsdSurface.qml (Loader):
//   property string daemonState, property var audio (frameReceived signal),
//   property var theme (color(role, fallback)), property var recipe, assetRoot.
import QtQuick

Item {
    id: root
    property string daemonState: "idle"
    property var audio: null
    property var theme: null
    property var recipe: null
    property string assetRoot: ""

    readonly property bool hudVisible: daemonState !== "idle" && daemonState !== ""
    readonly property bool isRecording: daemonState === "recording" || daemonState === "streaming"
    readonly property bool isTranscribing: daemonState === "transcribing"

    // Raw audio state
    property real peak: 0
    property real rms: 0
    property real heldDb: -120
    property real lastTsMs: 0
    property var ring: []          // recent peaks, newest on right
    property int ringCap: 64

    // Smoothed render state (buttery, not jittery)
    property real energy: 0
    property real smoothPeak: 0
    property real phase: 0
    property real lastTickMs: 0

    // Elapsed-time timer (shown inside the lens)
    property double recStartMs: 0
    property real elapsedSecs: 0
    function fmtTime(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2);
    }

    function colorFor(role, fallback) {
        return theme && theme.color ? theme.color(role, fallback) : fallback;
    }

    function meterFill(db) {
        var floor = -60.0;
        if (!isFinite(db) || db <= floor) return 0.0;
        return Math.max(0, Math.min(1, (Math.min(db, 0) - floor) / -floor));
    }

    onDaemonStateChanged: {
        if (daemonState === "recording" || daemonState === "streaming") {
            // Fresh dictation: start the timer (don't reset mid-streaming flips)
            if (recStartMs <= 0) {
                recStartMs = Date.now();
                elapsedSecs = 0;
            }
        } else if (daemonState === "transcribing") {
            if (recStartMs > 0) {
                elapsedSecs = (Date.now() - recStartMs) / 1000;
                recStartMs = 0;
            }
        } else {
            ring = [];
            peak = 0; rms = 0; energy = 0; smoothPeak = 0;
            heldDb = -120; lastTsMs = 0;
            recStartMs = 0; elapsedSecs = 0;
            canvas.requestPaint();
        }
    }

    Connections {
        target: root.audio
        enabled: root.audio !== null
        function onFrameReceived(p, r, vad, tsMs) {
            root.peak = p;
            root.rms = r;
            var nr = root.ring.slice();
            nr.push(p);
            while (nr.length > root.ringCap) nr.shift();
            root.ring = nr;
            var db = p > 0.0 ? 20 * Math.log10(p) : -120;
            var dt = root.lastTsMs > 0 ? Math.max(0, tsMs - root.lastTsMs) / 1000 : 0.03;
            root.lastTsMs = tsMs;
            if (db > root.heldDb) root.heldDb = db;
            else root.heldDb = Math.max(-120, root.heldDb - 6.0 * dt);
        }
        function onDisconnected() {
            root.ring = [];
            root.peak = 0; root.rms = 0;
            root.heldDb = -120;
        }
    }

    // 60fps smoothing + repaint driver
    Timer {
        interval: 16
        repeat: true
        running: root.hudVisible
        triggeredOnStart: true
        onTriggered: {
            var now = Date.now();
            var dt = root.lastTickMs > 0 ? Math.min(0.05, Math.max(0.001, (now - root.lastTickMs) / 1000)) : 0.016;
            root.lastTickMs = now;
            var targetE = root.isRecording
                ? Math.min(1, Math.max(0, root.rms * 9.0 + root.peak * 1.6))
                : (root.isTranscribing ? 0.35 + 0.2 * Math.sin(root.phase * 3.0) : 0);
            var k = 1 - Math.exp(-10.0 * dt);
            root.energy += (targetE - root.energy) * k;
            var kp = 1 - Math.exp(-14.0 * dt);
            root.smoothPeak += ((root.isRecording ? root.peak : 0) - root.smoothPeak) * kp;
            if (root.isRecording && root.recStartMs > 0) {
                root.elapsedSecs = (now - root.recStartMs) / 1000;
            }
            root.phase += dt;
            canvas.requestPaint();
        }
    }

    // Card: bottom-center, HAL size
    Item {
        id: card
        width: 190
        height: 216
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 52
        opacity: root.hudVisible ? 1 : 0
        scale: root.hudVisible ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Canvas {
            id: canvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            onPaint: {
                var ctx = getContext("2d");
                var W = width, H = height;
                ctx.clearRect(0, 0, W, H);
                if (!root.hudVisible) return;

                var cx = W / 2, cy = 96;
                var R = 82;          // outer metal
                var rBezel = 70;     // black bezel
                var rLens = 56;      // red lens
                var e = Math.max(0, Math.min(1, root.energy));
                var breath = 0.5 + 0.5 * Math.sin(root.phase * 2.0);

                // Dark scrim disc: separates the eye from busy desktop behind it
                ctx.beginPath(); ctx.arc(cx, cy, R + 12, 0, Math.PI * 2);
                ctx.fillStyle = "rgba(0,0,0,0.45)"; ctx.fill();

                // Outer glow when speaking (red halo = HAL is listening)
                if (root.isRecording) {
                    var glowR = R + 26 + e * 18;
                    var glow = ctx.createRadialGradient(cx, cy, R * 0.5, cx, cy, glowR);
                    var ga = 0.10 + e * 0.30;
                    glow.addColorStop(0, "rgba(255,45,45," + ga.toFixed(3) + ")");
                    glow.addColorStop(0.7, "rgba(255,45,45," + (ga * 0.35).toFixed(3) + ")");
                    glow.addColorStop(1, "rgba(255,45,45,0)");
                    ctx.fillStyle = glow;
                    ctx.beginPath(); ctx.arc(cx, cy, glowR, 0, Math.PI * 2); ctx.fill();
                }

                // Brushed-metal outer ring
                ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2);
                ctx.fillStyle = "#17171b"; ctx.fill();
                ctx.lineWidth = 2.5; ctx.strokeStyle = "#3d3d47"; ctx.stroke();
                ctx.beginPath(); ctx.arc(cx, cy, R - 5, 0, Math.PI * 2);
                ctx.lineWidth = 1; ctx.strokeStyle = "rgba(255,255,255,0.10)"; ctx.stroke();

                // Black bezel
                ctx.beginPath(); ctx.arc(cx, cy, rBezel, 0, Math.PI * 2);
                ctx.fillStyle = "#000000"; ctx.fill();

                // Red lens with voice-driven brightness
                var bright = root.isTranscribing ? 0.45 + 0.15 * breath
                    : 0.34 + e * 0.66;
                var g = ctx.createRadialGradient(cx - 6, cy - 8, 2, cx, cy, rLens);
                var c = Math.round(120 + 135 * bright);
                g.addColorStop(0, "rgba(255," + Math.round(90 + 80 * bright) + "," + Math.round(90 + 60 * bright) + ",1)");
                g.addColorStop(0.35, "rgba(" + c + ",18,18,1)");
                g.addColorStop(0.8, "rgba(90,4,4,1)");
                g.addColorStop(1, "rgba(30,0,0,1)");
                ctx.beginPath(); ctx.arc(cx, cy, rLens, 0, Math.PI * 2);
                ctx.fillStyle = g; ctx.fill();

                // Lens glass highlight
                ctx.save();
                ctx.beginPath(); ctx.arc(cx, cy, rLens, 0, Math.PI * 2); ctx.clip();
                ctx.globalAlpha = 0.20;
                ctx.fillStyle = "#ffffff";
                ctx.beginPath();
                ctx.ellipse(cx - 16, cy - 26, 30, 13, -0.5, 0, Math.PI * 2);
                ctx.fill();
                ctx.restore();

                // Hot core: grows + whitens with loudness
                var coreR = 5 + e * 11 + (root.isTranscribing ? breath * 3 : 0);
                var core = ctx.createRadialGradient(cx, cy, 0, cx, cy, coreR * 2.2);
                core.addColorStop(0, "rgba(255,240,240,0.95)");
                core.addColorStop(0.4, "rgba(255,120,120," + (0.55 + e * 0.4).toFixed(3) + ")");
                core.addColorStop(1, "rgba(255,40,40,0)");
                ctx.fillStyle = core;
                ctx.beginPath(); ctx.arc(cx, cy, coreR * 2.2, 0, Math.PI * 2); ctx.fill();
                ctx.fillStyle = "rgba(255,225,225," + (0.75 + e * 0.25).toFixed(3) + ")";
                ctx.beginPath(); ctx.arc(cx, cy, Math.max(2.5, coreR * 0.55), 0, Math.PI * 2); ctx.fill();

                // ---- Volume arc (level meter around the lens) ----
                var liveDb = root.smoothPeak > 0 ? 20 * Math.log10(Math.max(1e-6, root.smoothPeak)) : -120;
                var liveFill = root.meterFill(liveDb);
                var heldFill = root.meterFill(root.heldDb);
                var a0 = Math.PI * 0.75, sweep = Math.PI * 1.5;
                var arcR = rLens + 13;
                function arcPath(f0, f1) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, arcR, a0 + sweep * f0, a0 + sweep * f1);
                }
                // track
                ctx.lineCap = "round";
                ctx.lineWidth = 5;
                ctx.strokeStyle = "rgba(255,255,255,0.14)";
                arcPath(0, 1); ctx.stroke();
                // live level: red -> amber -> white as it gets hot
                if (liveFill > 0.003) {
                    var lg = ctx.createLinearGradient(cx - arcR, cy, cx + arcR, cy);
                    lg.addColorStop(0, "#ff2d2d");
                    lg.addColorStop(0.72, "#ffb84d");
                    lg.addColorStop(1, "#ffffff");
                    ctx.strokeStyle = lg;
                    ctx.lineWidth = 5;
                    ctx.globalAlpha = root.isRecording ? 0.95 : 0.5;
                    arcPath(0, liveFill); ctx.stroke();
                    ctx.globalAlpha = 1;
                }
                // held-peak tick
                if (heldFill > 0.003) {
                    var ha = a0 + sweep * heldFill;
                    var hx = cx + Math.cos(ha) * arcR, hy = cy + Math.sin(ha) * arcR;
                    ctx.fillStyle = "rgba(255,255,255,0.95)";
                    ctx.beginPath(); ctx.arc(hx, hy, 3, 0, Math.PI * 2); ctx.fill();
                }

                // ---- Sound waves: scrolling bars inside lower lens ----
                var bars = 26, bw = 118 / bars, gap = 2;
                var baseY = cy + 40, maxH = 30;
                ctx.save();
                ctx.beginPath(); ctx.arc(cx, cy, rLens - 2, 0, Math.PI * 2); ctx.clip();
                for (var i = 0; i < bars; i++) {
                    var v = 0.06;
                    if (root.ring.length > 0) {
                        var idx = Math.floor(i / bars * root.ring.length);
                        v = Math.max(0, Math.min(1, (root.ring[idx] || 0) * 8.0));
                        v = Math.max(0.06, Math.min(1, v * 0.7 + e * 0.3));
                    } else {
                        v = 0.05 + breath * 0.03;
                    }
                    var h = Math.max(2, maxH * v);
                    var x = cx - 59 + i * (bw + gap / bars);
                    ctx.fillStyle = root.isRecording
                        ? "rgba(255,210,210," + (0.35 + v * 0.55).toFixed(3) + ")"
                        : "rgba(255,200,120," + (0.30 + v * 0.4).toFixed(3) + ")";
                    var by = baseY - h / 2;
                    var r = 1.5;
                    if (bw - gap > 0 && h > 0) {
                        ctx.beginPath();
                        var bx = x, bw2 = Math.max(1.5, bw - 1.2);
                        if (ctx.roundRect) ctx.roundRect(bx, by, bw2, h, r);
                        else ctx.rect(bx, by, bw2, h);
                        ctx.fill();
                    }
                }
                ctx.restore();

                // ---- Status pill, top-inside of the lens ----
                // Recording: elapsed timer. Transcribing: explicit label.
                // (nothing is drawn outside the eye)
                var pillTxt = root.isTranscribing ? "Transcribing…" : root.fmtTime(root.elapsedSecs);
                var pillW = root.isTranscribing ? 84 : 52, pillH = 18, pillY = cy - 36;
                ctx.fillStyle = root.isTranscribing ? "rgba(60,40,5,0.72)" : "rgba(0,0,0,0.55)";
                ctx.beginPath();
                if (ctx.roundRect) ctx.roundRect(cx - pillW / 2, pillY - pillH / 2, pillW, pillH, 9);
                else ctx.rect(cx - pillW / 2, pillY - pillH / 2, pillW, pillH);
                ctx.fill();
                ctx.fillStyle = root.isTranscribing ? "rgba(242,204,77,0.95)" : "rgba(255,235,235,0.92)";
                ctx.font = "600 " + (root.isTranscribing ? "10" : "11") + "px sans-serif";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText(pillTxt, cx, pillY + 0.5);
            }
        }
    }
}
