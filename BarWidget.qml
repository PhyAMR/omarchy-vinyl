import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// A vinyl record drawn in thin lines: the disk spins while the computer plays
// sound, and a wave runs out of the stylus tip shaped by the live output level.
//
// The level comes from a PipeWire peak monitor on the default output, so any
// sound the computer makes drives it — no cava or other helper. The frame timer
// only runs while there is sound or the disk is still coasting to a stop, so an
// idle bar costs nothing.
//
// Hovering swaps the wave for previous / play-pause / next controls. They drive
// whichever MPRIS player the Omarchy media service considers active (Spotify,
// browsers, mpv, …); scrolling over the widget switches between players.
// Clicking the disk toggles play/pause.
BarWidget {
  id: root
  moduleName: "phuniverse.vinyl"

  readonly property int waveLength: setting("waveLength", 44)
  readonly property real lineWidth: setting("lineWidth", 1)
  readonly property real sensitivity: setting("sensitivity", 1.5)
  readonly property color ink: bar ? bar.foreground : "white"

  // ---- Audio level --------------------------------------------------------
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  PwNodePeakMonitor {
    id: peakMonitor
    node: root.sink
    enabled: !!root.sink
  }

  readonly property real rawPeak: sink && sink.audio && sink.audio.muted ? 0 : peakMonitor.peak
  readonly property bool sounding: rawPeak > 0.004

  // ---- Animation state ----------------------------------------------------
  property real level: 0        // smoothed, perceptual (0..1)
  property real spin: 0         // 0 = stopped, 1 = full speed
  property real angle: 0        // disk rotation, radians
  property int tick: 0
  property var samples: []      // newest first: { a: amplitude, p: phase }
  property real waveEnergy: 0

  readonly property bool animating: sounding || spin > 0.002 || waveEnergy > 0.002

  function step() {
    var target = Math.min(1, Math.sqrt(Math.max(0, rawPeak)) * sensitivity * 0.8)
    // Fast attack, slower release, so beats read as pulses.
    level += (target - level) * (target > level ? 0.6 : 0.18)

    spin += ((sounding ? 1 : 0) - spin) * (sounding ? 0.12 : 0.05)
    if (!sounding && spin < 0.002) spin = 0
    angle = (angle + spin * 0.11) % (Math.PI * 2)   // ~33 rpm at full speed

    tick++
    var next = [{ a: level, p: tick * 0.75 }].concat(samples)
    if (next.length > waveLength) next.length = waveLength
    var energy = 0
    for (var i = 0; i < next.length; i++) energy = Math.max(energy, next[i].a)
    samples = next
    waveEnergy = energy
    canvas.requestPaint()
  }

  Timer {
    interval: 33
    repeat: true
    running: root.animating && root.visible
    onTriggered: root.step()
  }

  onInkChanged: canvas.requestPaint()
  onVerticalChanged: canvas.requestPaint()

  // ---- Media player (controls / tooltip) ---------------------------------
  // The media service picks the active player the same way the media keys do;
  // fall back to the first playing MPRIS player if it is not loaded.
  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var player: {
    if (mediaService) return mediaService.activePlayer
    var list = Mpris.players.values
    for (var i = 0; i < list.length; i++) if (list[i].isPlaying) return list[i]
    return list.length > 0 ? list[0] : null
  }
  readonly property bool playing: !!player && player.isPlaying
  readonly property string nowPlaying: {
    if (!player) return "Nothing playing"
    var t = player.trackTitle || player.identity || "Unknown"
    var line = player.trackArtist ? player.trackArtist + " — " + t : t
    var app = player.identity || player.desktopEntry || ""
    return app && app !== t ? line + "  ·  " + app : line
  }

  function act(action) {
    if (!player) return
    if (mediaService) {
      mediaService.runAction(action, false, mediaService.playerKey(player))
    } else if (action === "previous" && player.canGoPrevious) {
      player.previous()
    } else if (action === "next" && player.canGoNext) {
      player.next()
    } else if (action === "playPause" && player.canTogglePlaying) {
      player.togglePlaying()
    }
  }

  readonly property bool showControls: hover.hovered && !!player && !vertical
  property real controlsOpacity: showControls ? 1 : 0
  Behavior on controlsOpacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  onControlsOpacityChanged: canvas.requestPaint()

  // ---- Geometry -----------------------------------------------------------
  readonly property real diskRadius: Math.max(5, (barSize - 8) / 2)
  readonly property real diskX: diskRadius + 3
  readonly property real waveStart: diskX + diskRadius + 3

  implicitHeight: barSize
  implicitWidth: vertical ? barSize : Math.round(waveStart + waveLength + 4)

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      var r = root.diskRadius
      var cx = root.vertical ? width / 2 : root.diskX
      var cy = height / 2
      var c = root.ink
      function ink(a) { return Qt.rgba(c.r, c.g, c.b, a) }
      function circle(radius, alpha) {
        ctx.beginPath()
        ctx.strokeStyle = ink(alpha)
        ctx.arc(cx, cy, radius, 0, Math.PI * 2)
        ctx.stroke()
      }

      ctx.lineWidth = root.lineWidth
      ctx.lineCap = "round"
      ctx.lineJoin = "round"

      // Disk: rim, two grooves, label, spindle.
      circle(r, 0.95)
      circle(r * 0.78, 0.35)
      circle(r * 0.6, 0.25)
      circle(r * 0.34, 0.8)
      ctx.beginPath()
      ctx.fillStyle = ink(0.95)
      ctx.arc(cx, cy, Math.max(0.8, root.lineWidth * 0.9), 0, Math.PI * 2)
      ctx.fill()

      // Light glints on the grooves and a mark on the label: these are what
      // show the disk turning.
      var a = root.angle
      ctx.strokeStyle = ink(0.9)
      ctx.beginPath(); ctx.arc(cx, cy, r * 0.78, a, a + 0.85); ctx.stroke()
      ctx.beginPath(); ctx.arc(cx, cy, r * 0.78, a + Math.PI, a + Math.PI + 0.85); ctx.stroke()
      ctx.strokeStyle = ink(0.6)
      ctx.beginPath(); ctx.arc(cx, cy, r * 0.6, a + 1.6, a + 2.1); ctx.stroke()
      ctx.beginPath()
      ctx.moveTo(cx + Math.cos(a) * r * 0.14, cy + Math.sin(a) * r * 0.14)
      ctx.lineTo(cx + Math.cos(a) * r * 0.32, cy + Math.sin(a) * r * 0.32)
      ctx.stroke()

      if (root.vertical) return

      // Tip: headshell coming in from the top right, stylus resting on the
      // outer groove.
      var sx = cx + r * 0.72
      var sy = cy - r * 0.08
      var hx = cx + r + 2.5
      var hy = cy - r + 0.5
      ctx.strokeStyle = ink(0.95)
      ctx.beginPath()
      ctx.moveTo(hx, Math.max(1, hy - 3))
      ctx.lineTo(hx, hy)
      ctx.lineTo(sx, sy)
      ctx.stroke()
      // Cartridge: a short stroke across the arm at the stylus end.
      var dx = sx - hx, dy = sy - hy
      var len = Math.sqrt(dx * dx + dy * dy) || 1
      var px = -dy / len * 2.2, py = dx / len * 2.2
      var bx = hx + dx * 0.55, by = hy + dy * 0.55
      ctx.beginPath()
      ctx.moveTo(bx - px, by - py)
      ctx.lineTo(bx + px, by + py)
      ctx.stroke()

      // Sound wave leaving the tip: newest sample at the stylus, older ones
      // further out, fading and shrinking as they travel.
      var x0 = root.waveStart
      var n = root.waveLength
      var maxAmp = (height / 2 - 2.5) * 0.85
      var s = root.samples
      var waveAlpha = 1 - root.controlsOpacity
      if (waveAlpha <= 0.01) return
      ctx.beginPath()
      ctx.strokeStyle = ink(0.9 * waveAlpha)
      ctx.moveTo(sx, sy)
      ctx.quadraticCurveTo(x0 - 1, cy, x0, cy)
      for (var i = 0; i < n; i++) {
        var sample = i < s.length ? s[i] : null
        var fade = 1 - i / n
        var amp = sample ? sample.a * maxAmp * (0.35 + 0.65 * fade) : 0
        var y = cy + (sample ? Math.sin(sample.p) * amp : 0)
        ctx.lineTo(x0 + i + 1, y)
      }
      ctx.stroke()

      // Fade the far end out instead of ending the line abruptly.
      var g = ctx.createLinearGradient(x0 + n * 0.55, 0, x0 + n + 1, 0)
      g.addColorStop(0, Qt.rgba(0, 0, 0, 0))
      g.addColorStop(1, Qt.rgba(0, 0, 0, 1))
      ctx.globalCompositeOperation = "destination-out"
      ctx.fillStyle = g
      ctx.fillRect(x0 + n * 0.55, 0, n * 0.45 + 2, height)
      ctx.globalCompositeOperation = "source-over"
    }
  }

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (!root.bar) return
      if (hovered) root.bar.showTooltip(root, root.nowPlaying)
      else root.bar.hideTooltip(root)
    }
  }

  // Whole widget: click the disk for play/pause, scroll to switch players.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    cursorShape: root.player ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.act("playPause")
    onWheel: function(wheel) {
      if (!root.mediaService || wheel.angleDelta.y === 0) return
      root.mediaService.switchSource(wheel.angleDelta.y > 0 ? -1 : 1, false, true)
    }
  }

  // Controls in place of the wave, shown while hovered.
  Row {
    id: controls
    x: root.waveStart + Math.max(0, (root.waveLength + 2 - width) / 2)
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1
    opacity: root.controlsOpacity
    visible: opacity > 0.01

    Repeater {
      model: [
        { action: "previous", glyph: "󰒮" },
        { action: "playPause", glyph: "" },
        { action: "next", glyph: "󰒭" }
      ]

      Item {
        id: control
        required property var modelData
        readonly property bool enabledHere: {
          if (!root.player) return false
          if (modelData.action === "previous") return root.player.canGoPrevious
          if (modelData.action === "next") return root.player.canGoNext
          return root.player.canTogglePlaying || root.player.canPlay || root.player.canPause
        }
        width: Math.max(13, glyph.implicitWidth + 2)
        height: root.barSize

        Text {
          id: glyph
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: control.modelData.glyph || (root.playing ? "󰏤" : "󰐊")
          color: root.ink
          opacity: !control.enabledHere ? 0.3 : (tap.containsMouse ? 1 : 0.75)
          scale: tap.pressed ? 0.85 : 1
          font.family: root.bar ? root.bar.fontFamily : ""
          font.pixelSize: control.modelData.action === "playPause" ? Style.font.body + 2 : Style.font.body
        }

        MouseArea {
          id: tap
          anchors.fill: parent
          hoverEnabled: true
          enabled: control.enabledHere
          cursorShape: Qt.PointingHandCursor
          onClicked: root.act(control.modelData.action)
        }
      }
    }
  }
}
