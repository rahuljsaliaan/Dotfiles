import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Notification Center: a bell in the bar that opens a dropdown, like the
// Wi-Fi and Bluetooth panels, listing your notifications (on screen now, then
// the saved history, grouped Today / Earlier). Built on Omarchy's own panel
// frame (Panel + KeyboardPanel), so it matches the other panels exactly.
//
// Data comes from the notifications plugin (rahulj.notifications): it writes
// ~/.local/state/omarchy/notifications/{live,history}.json, keeps an unread
// count in .../unseen (the purple dot), and takes the commands markSeen,
// removeHistory <key>, clearHistory, setDnd on|off and isDnd. The bell also
// records its position (.../bell-offset) so the notification cards' pointer
// can aim at it.
Panel {
  id: root
  moduleName: "rahulj.notification-bell"
  ipcTarget: "rahulj.notification-bell"

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications"
  readonly property int unseen: parseInt(String(unseenFile.text() || "0").trim()) || 0
  property bool dnd: false
  property var now: Date.now()

  // ------------------------------------------------------------ data
  function parseRows(text) {
    try {
      var v = JSON.parse(String(text || "[]"))
      return Array.isArray(v) ? v : []
    } catch (e) { return [] }
  }

  readonly property var rows: {
    var live = parseRows(liveFile.text())
    var history = parseRows(historyFile.text())
    var seen = ({}), out = []
    function add(r, isLive) {
      if (!r || !r.key || seen[r.key]) return
      if (!String(r.summary || "").length && !String(r.body || "").length) return
      seen[r.key] = true
      out.push({
        key: String(r.key), live: isLive,
        app: String(r.app || r.source || ""), appIcon: String(r.appIcon || ""),
        summary: String(r.summary || ""), body: String(r.body || ""),
        ts: Number(r.ts || 0), urgent: Number(r.urgency || 0) >= 2,
        day: root.dayLabel(Number(r.ts || 0))
      })
    }
    for (var i = live.length - 1; i >= 0; i--) add(live[i], true)   // live.json is oldest first
    for (var j = 0; j < history.length; j++) add(history[j], false) // history is newest first
    out.sort(function(a, b) { return b.ts - a.ts })
    return out
  }

  // Section headers need a ListModel (a plain array has no roles to group by).
  ListModel { id: rowModel }
  function syncModel() {
    rowModel.clear()
    for (var i = 0; i < rows.length; i++) rowModel.append(rows[i])
  }
  onRowsChanged: syncModel()

  function dayLabel(ts) {
    if (!ts) return "Earlier"
    return new Date(ts * 1000).toDateString() === new Date(root.now).toDateString() ? "Today" : "Earlier"
  }

  function ago(ts) {
    if (!ts) return ""
    var s = Math.max(0, (root.now - ts * 1000) / 1000)
    if (s < 60) return "now"
    if (s < 3600) return Math.round(s / 60) + "m"
    var then = new Date(ts * 1000)
    if (then.toDateString() === new Date(root.now).toDateString())
      return Qt.formatTime(then, "HH:mm")
    return Qt.formatDate(then, "ddd d MMM")
  }

  function iconFor(row) {
    var names = [row.appIcon, row.app.toLowerCase(), row.app.toLowerCase().replace(/ /g, "-")]
    for (var i = 0; i < names.length; i++) {
      if (!names[i]) continue
      if (names[i].charAt(0) === "/") return "file://" + names[i]
      var p = Quickshell.iconPath(names[i], true)
      if (p) return p
    }
    return ""
  }

  // ------------------------------------------------------------ actions
  function notify(args) { Quickshell.execDetached(["omarchy-shell", "notifications"].concat(args)) }

  function removeRow(row) {
    if (row.live) notify(["dismissOne"])
    notify(["removeHistory", row.key])
  }

  function clearAll() { notify(["clearHistory"]) }

  function setDnd(on) {
    root.dnd = on
    notify(["setDnd", on ? "on" : "off"])
  }

  // Bring the app's window forward: the first window whose class or title
  // contains the app's first word ("Teams for Linux" -> "teams").
  function focusApp(row) {
    var word = row.app.toLowerCase().split(/[^a-z0-9]+/).filter(function(w) { return w.length > 1 })[0] || ""
    if (!word) return
    Quickshell.execDetached(["bash", "-c",
      'a=$(hyprctl clients -j | jq -r --arg w "$1" \'[.[] | select((.class|ascii_downcase|contains($w)) or (.title|ascii_downcase|contains($w)))][0].address // empty\'); ' +
      '[ -n "$a" ] && hyprctl dispatch "hl.dsp.focus({ window = \\"address:$a\\" })" >/dev/null',
      "bash", word])
    root.close()
  }

  onOpenedChanged: {
    if (!opened) return
    root.now = Date.now()
    liveFile.reload(); historyFile.reload()
    dndProc.running = true
    notify(["markSeen"])
  }

  FileView { id: liveFile; path: root.stateDir + "/live.json"; watchChanges: true; printErrors: false; onFileChanged: reload() }
  FileView { id: historyFile; path: root.stateDir + "/history.json"; watchChanges: true; printErrors: false; onFileChanged: reload() }
  FileView { id: unseenFile; path: root.stateDir + "/unseen"; watchChanges: true; printErrors: false; onFileChanged: reload() }

  Process {
    id: dndProc
    command: ["omarchy-shell", "notifications", "isDnd"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.dnd = String(text).trim() === "on" }
  }

  Timer { interval: 30000; running: root.opened; repeat: true; onTriggered: root.now = Date.now() }

  // ------------------------------------------------------------ bell position
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
  FileView { id: offsetFile; path: root.stateDir + "/bell-offset"; atomicWrites: true; printErrors: false }

  // ------------------------------------------------------------ bar button
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.dnd ? "󰂛" : "󰂚"
    tooltipText: root.opened ? "" : (root.unseen > 0
      ? (root.unseen === 1 ? "1 new notification" : root.unseen + " new notifications")
      : "Notifications")
    onPressed: function(b) {
      if (b !== Qt.LeftButton) return
      if (root.opened) root.close()
      else root.open()
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

  // ------------------------------------------------------------ dropdown
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onCloseRequested: root.close()

      readonly property color fg: Commons.Color.popups.text
      readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          title: "Notifications"
          meta: root.rows.length === 0 ? "All caught up"
            : (root.rows.length === 1 ? "1 notification" : root.rows.length + " notifications")
          foreground: keys.fg
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: root.dnd ? "󰂛" : "󰂚"
              color: keys.fg
              font.family: Style.font.family
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            Row {
              spacing: Style.space(10)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "Do Not Disturb"
                color: keys.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
              ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: root.dnd
                onToggled: root.setDnd(!root.dnd)
              }
              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.rows.length > 0
                iconText: "󰎟"
                tooltipText: "Clear all"
                foreground: keys.fg
                onClicked: root.clearAll()
              }
            }
          }
        }

        // Empty state.
        Column {
          visible: root.rows.length === 0
          width: parent.width
          topPadding: Style.space(18)
          bottomPadding: Style.space(22)
          spacing: Style.space(6)
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: "󰂚"
            color: keys.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.displayLarge
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: "No notifications"
            color: keys.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        ListView {
          id: list
          visible: root.rows.length > 0
          width: parent.width
          height: Math.min(contentHeight, Style.space(460))
          clip: true
          interactive: contentHeight > height
          boundsBehavior: Flickable.StopAtBounds
          spacing: Style.space(6)
          model: rowModel

          section.property: "day"
          section.delegate: PanelSectionHeader {
            required property string section
            width: ListView.view.width
            text: section
            foreground: keys.fg
          }

          delegate: Item {
            id: entry
            required property string key
            required property bool live
            required property string app
            required property string appIcon
            required property string summary
            required property string body
            required property real ts
            required property bool urgent
            readonly property var row: ({ key: key, live: live, app: app, appIcon: appIcon,
                                          summary: summary, body: body, ts: ts, urgent: urgent })
            width: ListView.view.width
            height: card.height

            HoverHandler { id: hover }

            Rectangle {
              id: card
              width: parent.width
              height: content.height + Style.space(20)
              radius: Style.space(10)
              color: hover.hovered ? Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.08)
                                   : Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.04)
              border.width: entry.row.urgent ? 1 : 0
              border.color: "#f7768e"

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusApp(entry.row)
              }

              Row {
                id: content
                x: Style.space(12)
                y: Style.space(10)
                width: parent.width - Style.space(24)
                spacing: Style.space(10)

                // App icon, or its initial on an accent disc.
                Item {
                  width: Style.space(30)
                  height: Style.space(30)
                  readonly property string src: root.iconFor(entry.row)
                  Image {
                    anchors.fill: parent
                    visible: parent.src !== ""
                    source: parent.src
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                  }
                  Rectangle {
                    anchors.fill: parent
                    visible: parent.src === ""
                    radius: Style.space(8)
                    color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22)
                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: (entry.row.app || "?").charAt(0).toUpperCase()
                      color: keys.fg
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                  }
                }

                Column {
                  width: parent.width - Style.space(40)
                  spacing: Style.space(2)

                  Item {
                    width: parent.width
                    height: meta.implicitHeight
                    Text {
                      id: meta
                      anchors.left: parent.left
                      anchors.right: shut.left
                      anchors.rightMargin: Style.space(6)
                      textFormat: Text.PlainText
                      elide: Text.ElideRight
                      text: (entry.row.app || "Notification") + "  ·  " + root.ago(entry.row.ts)
                      color: keys.dim
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                    PanelActionButton {
                      id: shut
                      anchors.right: parent.right
                      anchors.verticalCenter: meta.verticalCenter
                      opacity: hover.hovered ? 1 : 0
                      iconText: "󰅖"
                      tooltipText: "Remove"
                      foreground: keys.fg
                      onClicked: root.removeRow(entry.row)
                    }
                  }

                  Text {
                    width: parent.width
                    visible: text.length > 0
                    textFormat: Text.PlainText
                    text: entry.row.summary
                    color: keys.fg
                    elide: Text.ElideRight
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  Text {
                    width: parent.width
                    visible: text.length > 0
                    textFormat: Text.PlainText
                    text: entry.row.body
                    color: Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.82)
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
