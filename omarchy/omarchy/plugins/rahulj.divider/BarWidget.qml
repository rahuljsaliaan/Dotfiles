import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A thin line between two groups of widgets, in the bar's text colour turned
// down low, so the groups read apart without boxes around them. Across the bar
// on a vertical one.
BarWidget {
  id: root
  moduleName: "rahulj.divider"

  readonly property color lineColor: root.bar ? root.bar.barForeground : Commons.Color.bar.text

  implicitWidth: root.vertical ? root.barSize : Style.space(17)
  implicitHeight: root.vertical ? Style.space(17) : root.barSize

  Rectangle {
    anchors.centerIn: parent
    width: root.vertical ? Style.space(14) : 1
    height: root.vertical ? 1 : Style.space(14)
    radius: 0.5
    color: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.22)
  }
}
