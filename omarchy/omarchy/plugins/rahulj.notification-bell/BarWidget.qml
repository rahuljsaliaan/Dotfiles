import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Notification Center: a bell in the bar that opens a dropdown, like the
// Wi-Fi and Bluetooth panels, listing your notifications (on screen now and
// the saved history). Built on Omarchy's own panel frame (Panel +
// KeyboardPanel), so it matches the other panels exactly.
//
//   Search    type anywhere: filters by app, title or message
//   Filters   All · Unread (new since you last opened it) · Urgent · top apps
//   Groups    Today · Yesterday · Earlier
//   Clear     clears what is shown (all, or just the search/filter result)
//   Keys      ↑/↓ select · Enter open app · Delete remove · Ctrl+C copy ·
//             Esc clears the search, then closes
//
// Data comes from the notifications plugin (rahulj.notifications): it writes
// ~/.local/state/omarchy/notifications/{live,history}.json, keeps an unread
// count in .../unseen (the purple dot), and takes the commands markSeen,
// removeHistory <key>, removeHistoryKeys <k1,k2>, clearHistory, dismissOne,
// setDnd on|off and isDnd. The bell also records its position
// (.../bell-offset) so the notification cards' pointer can aim at it.
Panel {
  id: root
  moduleName: "rahulj.notification-bell"
  ipcTarget: "rahulj.notification-bell"

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications"
  readonly property int unseen: parseInt(String(unseenFile.text() || "0").trim()) || 0
  property bool dnd: false
  property var now: Date.now()

  // Panel state.
  property string query: ""
  property string filter: "all"        // all | unread | urgent | app:<name>
  property int selectedIndex: -1
  property real seenBefore: 0          // when the panel was last opened (unread = newer)
  property string status: ""           // brief feedback ("Copied")

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
        app: root.displayApp(String(r.app || r.source || "")), appIcon: String(r.appIcon || ""),
        summary: String(r.summary || ""), body: String(r.body || ""),
        ts: Number(r.ts || 0), urgent: Number(r.urgency || 0) >= 2
      })
    }
    for (var i = live.length - 1; i >= 0; i--) add(live[i], true)   // live.json is oldest first
    for (var j = 0; j < history.length; j++) add(history[j], false) // history is newest first
    out.sort(function(a, b) { return b.ts - a.ts })
    return out
  }

  function isUnread(r) { return r.ts > root.seenBefore }

  // Senders' internal names, shown as people would say them.
  function displayApp(name) {
    var n = String(name || "")
    if (n === "omarchy-action" || n.toLowerCase() === "omarchy") return "Omarchy"
    if (n === "" || n === "notify-send") return "Notification"
    return n
  }

  // The few apps with the most notifications, for filter chips.
  readonly property var topApps: {
    var counts = ({}), order = []
    for (var i = 0; i < rows.length; i++) {
      var a = rows[i].app
      if (!counts[a]) { counts[a] = 0; order.push(a) }
      counts[a] += 1
    }
    order.sort(function(x, y) { return counts[y] - counts[x] })
    return order.slice(0, 4).map(function(a) { return { app: a, count: counts[a] } })
  }

  readonly property var shown: {
    var q = query.trim().toLowerCase()
    return rows.filter(function(r) {
      if (filter === "unread" && !root.isUnread(r)) return false
      if (filter === "urgent" && !r.urgent) return false
      if (filter.indexOf("app:") === 0 && r.app !== filter.slice(4)) return false
      if (!q) return true
      return (r.app + "\n" + r.summary + "\n" + r.body).toLowerCase().indexOf(q) >= 0
    })
  }

  function countWhere(test) { var n = 0; for (var i = 0; i < rows.length; i++) if (test(rows[i])) n++; return n }

  function dayLabel(ts) {
    if (!ts) return "Earlier"
    var d = new Date(ts * 1000).toDateString()
    if (d === new Date(root.now).toDateString()) return "Today"
    if (d === new Date(root.now - 86400000).toDateString()) return "Yesterday"
    return "Earlier"
  }

  function ago(ts) {
    if (!ts) return ""
    var s = Math.max(0, (root.now - ts * 1000) / 1000)
    if (s < 60) return "now"
    if (s < 3600) return Math.round(s / 60) + "m"
    var then = new Date(ts * 1000)
    if (then.toDateString() === new Date(root.now).toDateString()) return Qt.formatTime(then, "HH:mm")
    return Qt.formatDate(then, "ddd d MMM") + ", " + Qt.formatTime(then, "HH:mm")
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

  // Section headers need a ListModel (a plain array has no roles to group by).
  ListModel { id: rowModel }
  function syncModel() {
    rowModel.clear()
    for (var i = 0; i < shown.length; i++) {
      var r = shown[i]
      rowModel.append({ key: r.key, live: r.live, app: r.app, appIcon: r.appIcon, summary: r.summary,
                        body: r.body, ts: r.ts, urgent: r.urgent, unread: root.isUnread(r),
                        day: root.dayLabel(r.ts) })
    }
    if (selectedIndex >= rowModel.count) selectedIndex = rowModel.count - 1
  }
  onShownChanged: syncModel()

  // ------------------------------------------------------------ actions
  function notify(args) { Quickshell.execDetached(["omarchy-shell", "notifications"].concat(args)) }

  function removeRow(row) {
    if (row.live) notify(["dismissOne"])
    notify(["removeHistory", row.key])
  }

  // Clears what is shown: everything when nothing narrows the list, else just
  // the search/filter result.
  function clearShown() {
    if (!query.trim() && filter === "all") { notify(["clearHistory"]); return }
    var keys = shown.map(function(r) { return r.key })
    if (keys.length) notify(["removeHistoryKeys", keys.join(",")])
  }

  function copyRow(row) {
    var text = row.summary + (row.body ? "\n" + row.body : "")
    Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy', "sh", text])
    root.status = "Copied"
    statusTimer.restart()
  }

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

  function selectedRow() {
    if (selectedIndex < 0 || selectedIndex >= rowModel.count) return null
    return rowModel.get(selectedIndex)
  }

  function moveSelection(dy) {
    if (rowModel.count === 0) { selectedIndex = -1; return }
    selectedIndex = Math.max(0, Math.min(rowModel.count - 1, (selectedIndex < 0 ? -1 : selectedIndex) + dy))
  }

  onOpenedChanged: {
    if (!opened) return
    root.now = Date.now()
    // Unread = arrived since the panel was last opened.
    root.seenBefore = parseFloat(String(lastSeenFile.text() || "0").trim()) || 0
    lastSeenFile.setText(String(Date.now() / 1000) + "\n")
    root.query = ""
    root.filter = "all"
    root.selectedIndex = -1
    liveFile.reload(); historyFile.reload()
    syncModel()
    dndProc.running = true
    notify(["markSeen"])
  }

  FileView { id: liveFile; path: root.stateDir + "/live.json"; watchChanges: true; printErrors: false; onFileChanged: reload() }
  FileView { id: historyFile; path: root.stateDir + "/history.json"; watchChanges: true; printErrors: false; onFileChanged: reload() }
  FileView { id: unseenFile; path: root.stateDir + "/unseen"; watchChanges: true; printErrors: false; onFileChanged: reload() }
  FileView { id: lastSeenFile; path: root.stateDir + "/last-seen"; atomicWrites: true; printErrors: false }

  Process {
    id: dndProc
    command: ["omarchy-shell", "notifications", "isDnd"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.dnd = String(text).trim() === "on" }
  }

  Timer { interval: 30000; running: root.opened; repeat: true; onTriggered: root.now = Date.now() }
  Timer { id: statusTimer; interval: 1500; onTriggered: root.status = "" }

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
    focusTarget: panel.loadedContent ? panel.loadedContent.searchField : null
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: Item {
      id: keys
      property alias searchField: search
      implicitHeight: column.implicitHeight
      anchors.fill: parent

      readonly property color fg: Commons.Color.popups.text
      readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
      readonly property color accent: Commons.Color.accent

      // The search line has focus and hands every key here first; what this
      // leaves unaccepted is typed into the search.
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.query) root.query = ""
          else root.close()
          event.accepted = true
        } else if (event.key === Qt.Key_Down) {
          root.moveSelection(1); event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          root.moveSelection(-1); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          var r = root.selectedRow() || (rowModel.count ? rowModel.get(0) : null)
          if (r) root.focusApp(r)
          event.accepted = true
        } else if (event.key === Qt.Key_Delete) {
          var d = root.selectedRow()
          if (d) root.removeRow(d)
          event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
          var c = root.selectedRow()
          if (c) root.copyRow(c)
          event.accepted = true
        }
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          title: "Notifications"
          meta: root.status !== "" ? root.status
            : (root.rows.length === 0 ? "All caught up"
               : (root.shown.length === root.rows.length
                  ? (root.rows.length === 1 ? "1 notification" : root.rows.length + " notifications")
                  : root.shown.length + " of " + root.rows.length))
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
                visible: root.shown.length > 0
                iconText: "󰎟"
                tooltipText: (root.query.trim() || root.filter !== "all") ? "Clear these" : "Clear all"
                foreground: keys.fg
                onClicked: root.clearShown()
              }
            }
          }
        }

        // Search line.
        Rectangle {
          width: parent.width
          height: Style.space(34)
          radius: Style.space(9)
          color: Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.06)
          border.width: 1
          border.color: search.activeFocus ? Qt.rgba(keys.accent.r, keys.accent.g, keys.accent.b, 0.55)
                                           : Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.10)
          Text {
            id: searchIcon
            x: Style.space(11)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "󰍉"
            color: keys.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
          }
          FilterInput {
            id: search
            anchors { left: searchIcon.right; leftMargin: Style.space(8); right: parent.right; rightMargin: Style.space(11)
                      verticalCenter: parent.verticalCenter }
            keyHandler: keys
            color: keys.fg
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            text: root.query
            onTextChanged: if (text !== root.query) { root.query = text; root.selectedIndex = -1 }
          }
          Text {
            anchors.fill: search
            verticalAlignment: Text.AlignVCenter
            visible: search.text.length === 0
            textFormat: Text.PlainText
            text: "Search notifications"
            color: keys.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        // Filter chips.
        Flickable {
          width: parent.width
          height: chips.height
          contentWidth: chips.width
          clip: true
          interactive: contentWidth > width
          boundsBehavior: Flickable.StopAtBounds

          Row {
            id: chips
            spacing: Style.space(6)

            Repeater {
              model: {
                var list = [
                  { id: "all", label: "All", count: root.rows.length },
                  { id: "unread", label: "Unread", count: root.countWhere(root.isUnread) }
                ]
                var urgent = root.countWhere(function(r) { return r.urgent })
                if (urgent > 0) list.push({ id: "urgent", label: "Urgent", count: urgent })
                for (var i = 0; i < root.topApps.length; i++)
                  list.push({ id: "app:" + root.topApps[i].app, label: root.topApps[i].app, count: root.topApps[i].count })
                return list
              }
              delegate: Rectangle {
                required property var modelData
                readonly property bool active: root.filter === modelData.id
                height: Style.space(26)
                width: chipText.implicitWidth + Style.space(22)
                radius: height / 2
                color: active ? Qt.rgba(keys.accent.r, keys.accent.g, keys.accent.b, 0.22)
                              : (chipHover.hovered ? Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.09)
                                                   : Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.05))
                border.width: 1
                border.color: active ? Qt.rgba(keys.accent.r, keys.accent.g, keys.accent.b, 0.6)
                                     : Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.08)
                HoverHandler { id: chipHover }
                Text {
                  id: chipText
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: modelData.label + "  " + modelData.count
                  color: active ? keys.fg : keys.dim
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: active
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.filter = (root.filter === modelData.id && modelData.id !== "all") ? "all" : modelData.id
                    root.selectedIndex = -1
                    search.forceActiveFocus()
                  }
                }
              }
            }
          }
        }

        // Empty states.
        Column {
          visible: rowModel.count === 0
          width: parent.width
          topPadding: Style.space(18)
          bottomPadding: Style.space(22)
          spacing: Style.space(6)
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: root.rows.length === 0 ? "󰂚" : "󰍉"
            color: keys.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.displayLarge
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: root.rows.length === 0 ? "No notifications" : "Nothing matches"
            color: keys.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        ListView {
          id: list
          visible: rowModel.count > 0
          width: parent.width
          height: Math.min(contentHeight, Style.space(440))
          clip: true
          interactive: contentHeight > height
          boundsBehavior: Flickable.StopAtBounds
          spacing: Style.space(6)
          model: rowModel
          currentIndex: root.selectedIndex
          onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

          section.property: "day"
          section.delegate: PanelSectionHeader {
            required property string section
            width: ListView.view.width
            text: section
            foreground: keys.fg
          }

          delegate: Item {
            id: entry
            required property int index
            required property string key
            required property bool live
            required property string app
            required property string appIcon
            required property string summary
            required property string body
            required property real ts
            required property bool urgent
            required property bool unread
            readonly property var row: ({ key: key, live: live, app: app, appIcon: appIcon,
                                          summary: summary, body: body, ts: ts, urgent: urgent })
            readonly property bool selected: root.selectedIndex === index
            width: ListView.view.width
            height: card.height

            HoverHandler { id: hover }

            Rectangle {
              id: card
              width: parent.width
              height: content.height + Style.space(20)
              radius: Style.space(10)
              color: entry.selected ? Qt.rgba(keys.accent.r, keys.accent.g, keys.accent.b, 0.14)
                   : hover.hovered ? Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.08)
                                   : Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.04)
              border.width: entry.urgent || entry.selected ? 1 : 0
              border.color: entry.urgent ? "#f7768e" : Qt.rgba(keys.accent.r, keys.accent.g, keys.accent.b, 0.55)

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

                // App icon, or its initial on an accent disc; a dot when unread.
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
                    color: Qt.rgba(keys.accent.r, keys.accent.g, keys.accent.b, 0.22)
                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: (entry.app || "?").charAt(0).toUpperCase()
                      color: keys.fg
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                  }
                  Rectangle {
                    visible: entry.unread
                    width: Style.space(8); height: width; radius: width / 2
                    color: "#bb9af7"
                    anchors.right: parent.right; anchors.top: parent.top
                    anchors.rightMargin: -Style.space(2); anchors.topMargin: -Style.space(2)
                  }
                }

                Column {
                  width: parent.width - Style.space(40)
                  spacing: Style.space(2)

                  Item {
                    width: parent.width
                    height: Math.max(meta.implicitHeight, actions.height)
                    Text {
                      id: meta
                      anchors.left: parent.left
                      anchors.right: actions.left
                      anchors.rightMargin: Style.space(6)
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      elide: Text.ElideRight
                      text: entry.app + "  ·  " + root.ago(entry.ts)
                      color: keys.dim
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                    Row {
                      id: actions
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)
                      opacity: hover.hovered || entry.selected ? 1 : 0
                      PanelActionButton {
                        iconText: "󰆏"
                        tooltipText: "Copy"
                        foreground: keys.fg
                        onClicked: root.copyRow(entry.row)
                      }
                      PanelActionButton {
                        iconText: "󰅖"
                        tooltipText: "Remove"
                        foreground: keys.fg
                        onClicked: root.removeRow(entry.row)
                      }
                    }
                  }

                  Text {
                    width: parent.width
                    visible: text.length > 0
                    textFormat: Text.PlainText
                    text: entry.summary
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
                    text: entry.body
                    color: Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.82)
                    wrapMode: Text.Wrap
                    maximumLineCount: entry.selected ? 6 : 2
                    elide: Text.ElideRight
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignLeft
          textFormat: Text.PlainText
          text: "↑↓ select · ↵ open · Del remove · Ctrl+C copy · Esc"
          elide: Text.ElideRight
          color: Qt.rgba(keys.fg.r, keys.fg.g, keys.fg.b, 0.35)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
