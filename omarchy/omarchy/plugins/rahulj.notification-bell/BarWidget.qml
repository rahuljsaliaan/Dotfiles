import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A bell that notification cards point at (rahulj.notifications). It shows a
// purple dot while there are notifications you have not looked at, counted by
// the notifications plugin in ~/.local/state/omarchy/notifications/unseen and
// reset when the history is opened or everything is dismissed. Clicking the
// bell opens the history.
BarWidget {
  id: root
  moduleName: "rahulj.notification-bell"

  readonly property int unseen: parseInt(String(unseenFile.text() || "0").trim()) || 0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    id: unseenFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/unseen"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  // Where the bell's centre sits, as a distance from the screen's right edge,
  // so the notification cards' pointer can aim at it. Rechecked when the bar
  // lays out and every few seconds; written only when it changes.
  property int lastOffset: -1
  function publishOffset() {
    var win = root.Window.window
    if (!win || root.width <= 0) return
    var centre = root.mapToItem(null, root.width / 2, 0).x
    var offset = Math.round(win.width - centre)
    if (offset <= 0 || offset === root.lastOffset) return
    root.lastOffset = offset
    offsetFile.setText(String(offset) + "\n")
  }
  onXChanged: Qt.callLater(publishOffset)
  onWidthChanged: Qt.callLater(publishOffset)
  Component.onCompleted: Qt.callLater(publishOffset)
  Timer { interval: 3000; running: true; repeat: true; onTriggered: root.publishOffset() }

  FileView {
    id: offsetFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/bell-offset"
    atomicWrites: true
    printErrors: false
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰂚"
    tooltipText: root.unseen > 0
      ? (root.unseen === 1 ? "1 new notification" : root.unseen + " new notifications")
      : "Notifications"

    onPressed: function(b) {
      if (b === Qt.LeftButton) Quickshell.execDetached(["omarchy-shell", "notifications", "showHistory"])
    }
  }

  // The unread dot, at the bell's top-right.
  Rectangle {
    visible: root.unseen > 0
    width: Math.max(5, Math.round(Style.bar.iconSize * 0.42))
    height: width
    radius: width / 2
    color: "#bb9af7"
    anchors.horizontalCenter: button.horizontalCenter
    anchors.horizontalCenterOffset: Math.round(Style.bar.iconSize * 0.42)
    anchors.verticalCenter: button.verticalCenter
    anchors.verticalCenterOffset: -Math.round(Style.bar.iconSize * 0.36)
  }
}
