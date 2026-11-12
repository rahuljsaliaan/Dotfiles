import QtQuick
import qs.Commons
import qs.Ui

// Nothing to see: the space between two glass islands. The bar (rahulj.bar)
// ends the island before it and starts a new one after it.
BarWidget {
  id: root
  moduleName: "rahulj.island-gap"
  readonly property bool islandGap: true
  implicitWidth: Style.space(20)
  implicitHeight: Style.space(4)
}
