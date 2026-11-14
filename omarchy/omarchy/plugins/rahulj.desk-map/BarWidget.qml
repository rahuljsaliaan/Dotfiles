import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A map of the desk in the bar: one small screen per monitor, in their order
// left to right, sized like the real ones, each showing the workspace it is on
// (numbered 1-10 per monitor, as the workspaces widget numbers them). The
// focused monitor is outlined in the accent. Clicking a screen focuses it.
BarWidget {
  id: root
  moduleName: "rahulj.desk-map"

  readonly property color ink: root.bar ? root.bar.barForeground : Commons.Color.bar.text
  readonly property color accent: Commons.Color.accent

  // Monitors left to right, as they sit on the desk.
  readonly property var screens: {
    var list = Hyprland.monitors ? Hyprland.monitors.values.slice() : []
    list.sort(function(a, b) { return a.x - b.x })
    return list
  }
  // Logical size, so the laptop's scaled panel reads smaller, as it is.
  function logicalWidth(m) { return m.width / (m.scale || 1) }
  function logicalHeight(m) { return m.height / (m.scale || 1) }
  readonly property real tallest: {
    var h = 1
    for (var i = 0; i < screens.length; i++) h = Math.max(h, logicalHeight(screens[i]))
    return h
  }
  readonly property real maxHeight: Math.round(root.barSize * 0.62)

  function slotOf(id) { return id > 0 ? (id - 1) % 10 + 1 : "·" }

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
        readonly property bool focused: Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === modelData.name
        readonly property real h: Math.max(8, root.maxHeight * root.logicalHeight(modelData) / root.tallest)
        width: Math.round(h * root.logicalWidth(modelData) / root.logicalHeight(modelData))
        height: root.barSize

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Math.round((root.barSize - root.maxHeight) / 2)
          width: parent.width
          height: Math.round(cell.h)
          radius: Style.space(3)
          color: "transparent"
          border.width: 1.5
          border.color: cell.focused ? root.accent : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: String(root.slotOf(cell.modelData.activeWorkspace ? cell.modelData.activeWorkspace.id : -1))
            color: cell.focused ? root.ink : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
            font.family: Style.font.family
            font.pixelSize: Math.max(8, Math.round(cell.h * 0.62))
            font.weight: cell.focused ? Font.Bold : Font.Normal
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ monitor = \"" + cell.modelData.name + "\" })"))
        }
      }
    }
  }
}
