import QtQuick
import QtQuick.Shapes
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
//
// A hidden workspace open on a screen (the Super + S scratchpad, the Super + `
// console, any other special workspace) gives that screen a dashed outline and
// a dot in the theme's yellow, and a label follows the map: its name, the
// screen when it is not the bar's own, and how many windows it holds. Nothing
// else in the bar showed it, and the bar sits on one screen only. Clicking the
// label hides it, as its key does on that screen.
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
      if (name === "activespecialv2") {
        var fields = String(event.data || "").split(",")
        if (fields.length >= 3) root.setSpecial(fields[fields.length - 1], String(fields[1]).replace(/^special:/, ""))
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
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
  // ---- hidden workspaces open on the screens. Hyprland reports each open and
  // close (activespecialv2: id,name,screen, with an empty name on close), and
  // each screen's state is read back from Hyprland at start and on every
  // monitor refresh, so a shell restart or a screen that drops out never
  // leaves a stale mark. Keyed by screen name, the workspace name without its
  // "special:" prefix.
  property var specials: ({})
  function specialOf(screen) {
    var ipc = screen ? screen.lastIpcObject : null
    var special = ipc ? ipc.specialWorkspace : null
    return special && special.name ? String(special.name).replace(/^special:/, "") : ""
  }
  readonly property var ipcSpecials: {
    var found = {}
    for (var i = 0; i < root.screens.length; i++) {
      var name = root.specialOf(root.screens[i])
      if (name !== "") found[String(root.screens[i].name)] = name
    }
    return found
  }
  onIpcSpecialsChanged: root.specials = root.ipcSpecials
  function setSpecial(screenName, name) {
    var next = {}
    for (var k in root.specials) if (k !== screenName) next[k] = root.specials[k]
    if (name !== "") next[screenName] = name
    root.specials = next
  }
  // Left to right, as the map draws the screens.
  readonly property var openSpecials: {
    var list = []
    for (var i = 0; i < root.screens.length; i++) {
      var screenName = String(root.screens[i].name)
      var name = root.specials[screenName]
      if (name) list.push({ screen: screenName, name: name })
    }
    return list
  }
  function specialCount(name) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (String(values[i].name) === "special:" + name) return values[i].toplevels ? values[i].toplevels.values.length : 0
    }
    return 0
  }
  function specialTitle(name) {
    if (name === "scratchpad") return "Scratchpad"
    if (name === "qconsole") return "Console"
    return name.charAt(0).toUpperCase() + name.slice(1)
  }
  // nf-fa-clone, nf-fa-terminal, nf-fa-window_restore
  function specialGlyph(name) { return name === "scratchpad" ? "\uf24d" : (name === "qconsole" ? "\uf120" : "\uf2d2") }
  function specialLetter(name) { return name === "qconsole" ? "C" : name.charAt(0).toUpperCase() }
  // The screen this bar is on; a label names any other screen, in words.
  readonly property string barScreen: QsWindow.window && QsWindow.window.screen ? String(QsWindow.window.screen.name) : ""
  function screenWord(screenName) {
    if (/^eDP/.test(screenName)) return "laptop"
    for (var i = 0; i < root.screens.length; i++) {
      if (String(root.screens[i].name) !== screenName) continue
      if (i === 0) return "left"
      if (i === root.screens.length - 1) return "right"
      return "middle"
    }
    return screenName
  }
  function specialLabel(entry) {
    var parts = [root.specialGlyph(entry.name) + "  " + root.specialTitle(entry.name)]
    if (entry.screen !== root.barScreen) parts.push(root.screenWord(entry.screen))
    // The console always holds its one agent; a count says nothing there.
    if (entry.name !== "qconsole") parts.push(String(root.specialCount(entry.name)))
    return parts.join("  \u00b7  ")
  }
  // Hide it as its key would on that screen: focus the screen, toggle the
  // workspace, and focus back where you were, with pointer warps off so the
  // pointer stays on the bar.
  function hideSpecial(screenName, name) {
    var safe = /^[A-Za-z0-9_.-]+$/
    if (!safe.test(screenName) || !safe.test(name)) return
    root.run("hyprctl eval " + Util.shellQuote(
      "local back = hl.get_active_monitor() "
      + "local warps = hl.get_config('cursor.no_warps') "
      + "hl.config({ cursor = { no_warps = true } }) "
      + "hl.dispatch(hl.dsp.focus({ monitor = '" + screenName + "' })) "
      + "hl.dispatch(hl.dsp.workspace.toggle_special('" + name + "')) "
      + "if back and back.name ~= '" + screenName + "' then hl.dispatch(hl.dsp.focus({ monitor = back.name })) end "
      + "hl.config({ cursor = { no_warps = warps == true } })"))
  }
  // The theme's yellow, read from the theme as the net-speed widget reads its
  // colours, so it follows a theme change.
  property color modeColor: "#ffcb6b"
  FileView {
    id: themeColors
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var m = String(text() || "").match(/^\s*yellow\s*=\s*"(#[0-9a-fA-F]{6})"/m)
      if (m) root.modeColor = m[1]
    }
  }

  // Super + L and the default layout ask omarchy.workspaces to read the mode
  // again; this widget takes its place in the bar, so it answers.
  ShellIpc {
    target: "omarchy.workspaces"
    function refresh(): void { root.refresh() }
  }

  // ---- drawing
  // Every screen the same small frame (30x20 on a 26px bar), so the eye reads
  // the marks rather than the frames. Inside, a soft tinted shape for the
  // layout and the number in the bar's own text colour, SemiBold: the numbers
  // read like the rest of the bar and the shapes stay clear without shouting.
  readonly property int frameHeight: Math.round(root.barSize * 20 / 26)
  readonly property int frameWidth: Math.round(root.frameHeight * 1.5)
  readonly property int shapeSize: Math.round(root.frameHeight * 0.7)
  // Triangles are drawn taller: their room for a number is low and narrow.
  readonly property int triangleSize: Math.min(root.frameHeight - 3, Math.round(root.shapeSize * 1.25))
  readonly property int numberSize: Math.round(root.frameHeight * 0.55)

  implicitWidth: row.implicitWidth + Style.space(8)
  implicitHeight: root.barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(4)

    Repeater {
      model: root.screens

      Item {
        id: cell
        required property var modelData
        readonly property bool focused: String(modelData.name) === root.monitorName
        readonly property int wsId: modelData.activeWorkspace ? modelData.activeWorkspace.id : -1
        readonly property string mode: root.modeOf(wsId)
        readonly property bool triangle: mode === "floating"
        readonly property string special: root.specials[String(modelData.name)] || ""
        readonly property color tint: focused ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.30)
                                              : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.13)
        readonly property color figure: focused ? Qt.lighter(root.ink, 1.14)
                                                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.75)
        width: root.frameWidth
        height: root.barSize

        // The screen.
        Rectangle {
          id: frame
          anchors.centerIn: parent
          width: root.frameWidth
          height: root.frameHeight
          radius: 4
          color: "transparent"
          border.width: 1
          border.color: cell.special !== "" ? "transparent"
                       : cell.focused ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.75)
                                      : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22)

          // A hidden workspace open here: a dashed outline in the mode colour
          // in place of the frame, and a dot with its letter on the corner.
          Shape {
            visible: cell.special !== ""
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeWidth: 1.5
              strokeColor: root.modeColor
              fillColor: Qt.rgba(root.modeColor.r, root.modeColor.g, root.modeColor.b, 0.10)
              strokeStyle: ShapePath.DashLine
              dashPattern: [2.4, 1.6]
              PathRectangle { x: 0.75; y: 0.75; width: frame.width - 1.5; height: frame.height - 1.5; radius: 4 }
            }
          }

          // Its workspace: the number on the layout's shape.
          Item {
            id: mark
            anchors.centerIn: parent
            width: cell.triangle ? Math.round(root.triangleSize * 1.3) : root.shapeSize
            height: cell.triangle ? root.triangleSize : root.shapeSize

            // Square (tiling) and circle (scrolling).
            Rectangle {
              visible: !cell.triangle
              anchors.fill: parent
              radius: cell.mode === "scrolling" ? width / 2 : Math.round(width * 0.24)
              color: cell.tint
              antialiasing: true
            }
            // Triangle (floating), as a vector shape so its edges stay crisp,
            // its corners softened by a stroke of the same tint.
            Shape {
              visible: cell.triangle
              anchors.fill: parent
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                strokeWidth: 1.6
                strokeColor: cell.tint
                fillColor: cell.tint
                joinStyle: ShapePath.RoundJoin
                startX: mark.width / 2; startY: 0.8
                PathLine { x: mark.width - 0.8; y: mark.height - 0.8 }
                PathLine { x: 0.8; y: mark.height - 0.8 }
                PathLine { x: mark.width / 2; y: 0.8 }
              }
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              anchors.verticalCenterOffset: cell.triangle ? Math.round(root.triangleSize * 0.2) : 0
              textFormat: Text.PlainText
              text: root.slotLabel(cell.wsId)
              color: cell.figure
              font.family: Style.font.family
              font.pixelSize: root.numberSize
              font.weight: Font.DemiBold
              renderType: Text.NativeRendering
            }
          }

          Rectangle {
            visible: cell.special !== ""
            z: 2
            width: Math.round(root.frameHeight * 0.5)
            height: width
            radius: width / 2
            color: root.modeColor
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -Math.round(height * 0.3)
            anchors.rightMargin: -Math.round(width * 0.35)
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: root.specialLetter(cell.special)
              color: Commons.Color.bar.background
              font.family: Style.font.family
              font.pixelSize: Math.max(6, Math.round(parent.height * 0.75))
              font.weight: Font.Bold
              renderType: Text.NativeRendering
            }
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

    Repeater {
      model: root.openSpecials

      Item {
        id: tag
        required property var modelData
        width: pill.width
        height: root.barSize

        Rectangle {
          id: pill
          anchors.verticalCenter: parent.verticalCenter
          height: root.frameHeight
          width: label.implicitWidth + Math.round(root.frameHeight * 0.9)
          radius: height / 2
          color: Qt.rgba(root.modeColor.r, root.modeColor.g, root.modeColor.b, 0.13)
          border.width: 1
          border.color: Qt.rgba(root.modeColor.r, root.modeColor.g, root.modeColor.b, 0.35)

          Text {
            id: label
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.specialLabel(tag.modelData)
            color: root.modeColor
            font.family: Style.font.family
            font.pixelSize: root.numberSize + 1
            renderType: Text.NativeRendering
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.hideSpecial(String(tag.modelData.screen), String(tag.modelData.name))
          }
        }
      }
    }
  }
}
