import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A map of the desk in the bar, which is also the workspace switcher: one
// small screen per monitor, left to right and sized like the real ones. Each
// holds only the workspace it is on (1-10 per monitor, as omarchy.workspaces
// numbers them), drawn inside that workspace's layout shape: a square tiles, a
// circle scrolls, a triangle floats. The focused screen is drawn in the
// accent. Click the focused screen to cycle its layout (as Super + L does),
// scroll on it to step through its workspaces, and click another screen to
// focus it. It replaces omarchy.workspaces in the bar, and answers its
// refresh IPC.
BarWidget {
  id: root
  moduleName: "rahulj.desk-map"

  readonly property color ink: root.bar ? root.bar.barForeground : Commons.Color.bar.text
  readonly property color accent: Commons.Color.accent

  // ---- the screens, as they sit on the desk
  readonly property var screens: {
    var list = Hyprland.monitors ? Hyprland.monitors.values.slice() : []
    list.sort(function(a, b) { return a.x - b.x })
    return list
  }
  function logicalWidth(m) { return m.width / (m.scale || 1) }
  function logicalHeight(m) { return m.height / (m.scale || 1) }
  readonly property real tallest: {
    var h = 1
    for (var i = 0; i < screens.length; i++) h = Math.max(h, logicalHeight(screens[i]))
    return h
  }
  readonly property real maxHeight: Math.round(root.barSize * 0.66)

  // ---- the focused monitor's workspaces, as omarchy.workspaces lists them
  readonly property int slots: 10
  readonly property var monitor: Hyprland.focusedMonitor
  readonly property string monitorName: root.monitor ? String(root.monitor.name) : ""

  property var blocks: ({})
  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }
  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  function blockOf(id) { return Math.floor((id - 1) / root.slots) }
  function slotOf(id) { return id > 0 ? (id - 1) % root.slots + 1 : 0 }
  function slotLabel(id) { var s = root.slotOf(id); return s === 0 ? "·" : (s === root.slots ? "0" : String(s)) }

  function activeWorkspaceId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }
  readonly property int block: {
    var b = root.blocks[root.monitorName]
    if (b !== undefined) return b
    var active = root.activeWorkspaceId()
    return active > 0 ? root.blockOf(active) : 0
  }
  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) if (values[i].id === id) return values[i]
    return null
  }
  // The first five of the monitor's own, any of the rest that exist, then
  // workspaces only visiting it from an unplugged monitor.
  function workspaceIds() {
    var base = root.block * root.slots
    var ids = [base + 1, base + 2, base + 3, base + 4, base + 5]
    var guests = []
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id <= 0) continue
      if (root.blockOf(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (values[i].monitor && values[i].monitor.name === root.monitorName) {
        guests.push(id)
      }
    }
    ids.sort(function(a, b) { return a - b })
    guests.sort(function(a, b) { return a - b })
    return ids.concat(guests)
  }

  function run(command) { if (root.bar) root.bar.run(command) }
  function dispatch(expression) { root.run("hyprctl dispatch " + Util.shellQuote(expression)) }
  function focusWorkspace(id) {
    if (root.blockOf(id) === root.block) root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")")
    else root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
  }
  function focusMonitor(name) { root.dispatch("hl.dsp.focus({ monitor = \"" + name + "\" })") }

  property real wheelAccumulator: 0
  function scrollWorkspaces(delta) {
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return
    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeWorkspaceId())
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  // ---- the layout of the workspace each screen shows: read for all of them
  // at once and cached per workspace; a layout only changes through the
  // layout commands (which send the refresh IPC) or a config reload.
  property var modes: ({})
  property bool modesStale: false
  function shownIds() {
    var ids = []
    for (var i = 0; i < root.screens.length; i++) {
      var w = root.screens[i].activeWorkspace
      if (w && w.id > 0) ids.push(w.id)
    }
    return ids
  }
  function modeOf(id) { return root.modes[id] || "dwindle" }
  function readModes(force) {
    var want = root.shownIds().filter(function(id) { return force || root.modes[id] === undefined })
    if (want.length === 0) return
    if (modeProc.running) { root.modesStale = true; return }
    modeProc.command = ["bash", "-c", "for id in \"$@\"; do printf '%s %s\\n' \"$id\" \"$(omarchy-hyprland-workspace-layout-current \"$id\")\"; done", "_"].concat(want.map(String))
    modeProc.running = true
  }
  function refresh() {
    root.modes = ({})
    root.readModes(true)
  }
  // The layout commands act on the focused workspace.
  function cycleLayout() { root.run("omarchy-hyprland-workspace-layout-toggle") }

  Component.onCompleted: refresh()
  onScreensChanged: root.readModes(false)
  Timer { id: settle; interval: 120; onTriggered: root.readModes(false) }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "configreloaded") root.refresh()
      if (name === "workspacev2" || name === "moveworkspacev2" || name === "changeworkspaceid" || name === "focusedmonv2") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
        settle.restart()
      }
    }
  }
  Process {
    id: modeProc
    stdout: StdioCollector {
      onStreamFinished: {
        var next = {}
        for (var k in root.modes) next[k] = root.modes[k]
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].trim().split(" ")
          if (f.length >= 2 && f[1]) next[parseInt(f[0], 10)] = f[1]
        }
        root.modes = next
      }
    }
    onExited: {
      if (!root.modesStale) return
      root.modesStale = false
      Qt.callLater(function() { root.readModes(false) })
    }
  }
  // Super + L and the default layout ask omarchy.workspaces to read the mode
  // again; this widget takes its place in the bar, so it answers.
  ShellIpc {
    target: "omarchy.workspaces"
    function refresh(): void { root.refresh() }
  }

  // ---- drawing
  implicitWidth: row.implicitWidth + Style.space(8)
  implicitHeight: root.barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(3)

    Repeater {
      model: root.screens

      Item {
        id: cell
        required property var modelData
        readonly property bool focused: String(modelData.name) === root.monitorName
        readonly property int wsId: modelData.activeWorkspace ? modelData.activeWorkspace.id : -1
        readonly property string mode: root.modeOf(wsId)
        readonly property real h: Math.max(10, root.maxHeight * root.logicalHeight(modelData) / root.tallest)
        readonly property color line: focused ? root.accent : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.32)
        readonly property color figure: focused ? root.ink : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
        width: Math.round(h * root.logicalWidth(modelData) / root.logicalHeight(modelData))
        height: root.barSize

        // The screen.
        Rectangle {
          id: frame
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Math.round((root.barSize - root.maxHeight) / 2)
          width: parent.width
          height: Math.round(cell.h)
          radius: Style.space(3)
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(cell.line.r, cell.line.g, cell.line.b, cell.focused ? 0.55 : 0.6)

          // Its workspace: the number inside the layout's shape.
          Canvas {
            id: shape
            anchors.centerIn: parent
            width: Math.round(frame.height * 0.86)
            height: width
            readonly property string mode: cell.mode
            readonly property color stroke: cell.line
            onModeChanged: requestPaint()
            onStrokeChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
              var c = getContext("2d"), w = width, k = 1.4
              c.reset()
              c.lineWidth = k
              c.strokeStyle = stroke
              c.lineJoin = "round"
              c.beginPath()
              if (mode === "scrolling") {
                c.arc(w / 2, w / 2, w / 2 - k, 0, Math.PI * 2)
              } else if (mode === "floating") {
                c.moveTo(w / 2, k)
                c.lineTo(w - k, w - k)
                c.lineTo(k, w - k)
                c.closePath()
              } else {
                var r = w * 0.18, x = k, y = k, s = w - 2 * k
                c.moveTo(x + r, y); c.lineTo(x + s - r, y); c.arcTo(x + s, y, x + s, y + r, r)
                c.lineTo(x + s, y + s - r); c.arcTo(x + s, y + s, x + s - r, y + s, r)
                c.lineTo(x + r, y + s); c.arcTo(x, y + s, x, y + s - r, r)
                c.lineTo(x, y + r); c.arcTo(x, y, x + r, y, r)
                c.closePath()
              }
              c.stroke()
            }
          }
          Text {
            anchors.horizontalCenter: shape.horizontalCenter
            anchors.verticalCenter: shape.verticalCenter
            // A triangle's middle sits low.
            anchors.verticalCenterOffset: cell.mode === "floating" ? Math.round(shape.height * 0.14) : 0
            textFormat: Text.PlainText
            text: root.slotLabel(cell.wsId)
            color: cell.figure
            font.family: Style.font.family
            font.pixelSize: Math.max(7, Math.round(shape.height * (cell.mode === "floating" ? 0.46 : 0.58)))
            font.weight: cell.focused ? Font.Bold : Font.Normal
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (cell.focused) root.cycleLayout()
              else root.focusMonitor(String(cell.modelData.name))
            }
            onWheel: function(wheel) {
              if (!cell.focused) return
              root.scrollWorkspaces(wheel.angleDelta.y)
            }
          }
        }
      }
    }
  }
}
