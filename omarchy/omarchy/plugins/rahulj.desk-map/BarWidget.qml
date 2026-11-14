import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A map of the desk in the bar, which is also the workspace switcher: one
// small screen per monitor, left to right and sized like the real ones. The
// focused screen opens up to hold its workspaces, exactly as Omarchy's
// workspaces widget shows them (1-10 per monitor, the one shown carrying its
// layout: square tiles, circle scrolls, triangle floats; click it to cycle the
// layout, click another to switch, scroll to step). The other screens stay
// small and show just the workspace they are on; clicking one focuses it. So
// the numbers always belong to the screen they sit in, whichever has focus.
// It replaces omarchy.workspaces in the bar, and answers its refresh IPC.
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

  // ---- the layout of the workspace shown: square tiles, circle scrolls, triangle floats
  property string activeMode: "dwindle"
  property bool modeStale: false
  function modeGlyph(mode) {
    if (mode === "scrolling") return "󰝥"
    if (mode === "floating") return "󰔶"
    return "󱓻"
  }
  property var modeCache: ({})
  property int modeGeneration: 0
  property int modeProcWorkspace: -1
  property int modeProcGeneration: 0
  function showActiveMode() {
    var mode = root.modeCache[root.activeWorkspaceId()]
    if (mode !== undefined) root.activeMode = mode
    else root.readMode()
  }
  function readMode() {
    if (modeProc.running) { root.modeStale = true; return }
    var id = root.activeWorkspaceId()
    if (id === -1) return
    root.modeProcWorkspace = id
    root.modeProcGeneration = root.modeGeneration
    modeProc.command = ["omarchy-hyprland-workspace-layout-current", String(id)]
    modeProc.running = true
  }
  function refresh() {
    root.modeCache = ({})
    root.modeGeneration++
    root.readMode()
  }
  // The layout commands act on the focused workspace, which is the one shown here.
  function cycleLayout() { root.run("omarchy-hyprland-workspace-layout-toggle") }

  Component.onCompleted: refresh()
  onMonitorNameChanged: root.showActiveMode()
  Connections {
    target: root.monitor
    function onActiveWorkspaceChanged() { root.showActiveMode() }
  }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "configreloaded") root.refresh()
      if (name === "workspacev2" || name === "moveworkspacev2" || name === "changeworkspaceid" || name === "focusedmonv2") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
  }
  Process {
    id: modeProc
    stdout: StdioCollector {
      onStreamFinished: {
        var mode = text.trim()
        if (!mode || root.modeProcGeneration !== root.modeGeneration) return
        root.modeCache[root.modeProcWorkspace] = mode
        if (root.modeProcWorkspace === root.activeWorkspaceId()) root.activeMode = mode
      }
    }
    onExited: {
      if (!root.modeStale) return
      root.modeStale = false
      Qt.callLater(root.showActiveMode)
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
        readonly property real h: Math.max(10, root.maxHeight * root.logicalHeight(modelData) / root.tallest)
        readonly property real smallWidth: Math.round(h * root.logicalWidth(modelData) / root.logicalHeight(modelData))
        width: focused ? Math.max(smallWidth, list.implicitWidth + Style.space(6)) : smallWidth
        height: root.barSize

        Rectangle {
          id: frame
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Math.round((root.barSize - root.maxHeight) / 2)
          width: parent.width
          height: Math.round(cell.h)
          radius: Style.space(3)
          color: "transparent"
          border.width: 1.5
          border.color: cell.focused ? root.accent : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)

          // Another screen: just the workspace it is on.
          Text {
            visible: !cell.focused
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.slotLabel(cell.modelData.activeWorkspace ? cell.modelData.activeWorkspace.id : -1)
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
            font.family: Style.font.family
            font.pixelSize: Math.max(8, Math.round(cell.h * 0.62))
          }
          MouseArea {
            visible: !cell.focused
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.focusMonitor(String(cell.modelData.name))
          }

          // The focused screen: its workspaces, the shown one as its layout.
          Row {
            id: list
            visible: cell.focused
            anchors.centerIn: parent
            spacing: 0

            Repeater {
              model: cell.focused ? root.workspaceIds() : []

              WidgetButton {
                required property int modelData
                required property int index
                readonly property var workspace: root.workspaceById(modelData)
                readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
                readonly property bool shown: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === modelData

                bar: root.bar
                text: shown ? root.modeGlyph(root.activeMode) : root.slotLabel(modelData)
                fontSize: Math.max(9, Math.round(cell.h * 0.62))
                opacity: occupied || shown ? 1 : 0.5
                horizontalMargin: 4
                verticalPadding: 0
                fixedWidth: Style.space(16)
                fixedHeight: Math.round(cell.h) - 2
                onPressed: function() {
                  if (shown) root.cycleLayout()
                  else root.focusWorkspace(modelData)
                }
                onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }
              }
            }
          }
        }
      }
    }
  }
}
