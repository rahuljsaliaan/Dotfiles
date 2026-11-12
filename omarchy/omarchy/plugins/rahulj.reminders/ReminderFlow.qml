import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ReminderFlowModel.js" as ReminderFlowModel

// Personal reminder panel (rahulj.reminders, cloned from omarchy.reminders).
// Omarchy's asks twice, first for minutes and then for the text; this asks
// once. Type the time and the note on one line, the way you'd say it:
//
//   30m Check the oven · 1h30 Stand-up · at 15:30 Call mom · Tea in 10 min
//
// A live line underneath reads it back ("in 30 min · 17:58 · Check the oven")
// or says what is missing, and quick-time chips (clicked, or Tab to cycle)
// set the time while keeping the note. Enter sets it, Esc clears or closes.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string filterText: ""
  property string fontFamily: Style.font.menuFamily
  property bool tried: false
  property int chipIndex: -1
  property date now: new Date()

  readonly property var chips: ["5m", "10m", "15m", "30m", "1h", "2h"]
  readonly property var parsed: ReminderFlowModel.parse(root.filterText, root.now)
  readonly property bool valid: parsed.minutes > 0

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  property color chipFill: Commons.Color.menu.selectedBackground
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int cardWidth: Math.min(Style.space(420), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(contentMargin * 2 + content.implicitHeight, panel.height - Style.gapsOut * 2)

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    if (payload.fontFamily) root.fontFamily = payload.fontFamily

    root.opened = true
    root.filterText = ""
    root.tried = false
    root.chipIndex = -1
    root.now = new Date()

    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "omarchy.reminders")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.tried = false
    root.now = new Date()
  }

  function useChip(index) {
    root.chipIndex = index
    root.setFilter(ReminderFlowModel.withLeadTime(root.filterText, root.chips[index]))
    keyCatcher.forceActiveFocus()
  }

  function submit() {
    if (!root.filterText.trim()) {
      root.dismiss()
      return
    }
    root.now = new Date()
    var result = ReminderFlowModel.parse(root.filterText, root.now)
    if (result.minutes <= 0) {
      root.tried = true
      return
    }
    var args = [root.omarchyPath + "/bin/omarchy-reminder"].concat(ReminderFlowModel.reminderArgs(String(result.minutes), result.message))
    root.dismiss()
    Quickshell.execDetached(args)
  }

  // Keeps "17:58" and "at 15:30" honest while the panel stays open.
  Timer {
    interval: 15000
    running: root.opened
    repeat: true
    onTriggered: root.now = new Date()
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omarchy-reminders"

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: keyCatcher.forceActiveFocus() }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            var step = event.key === Qt.Key_Backtab ? -1 : 1
            var next = root.chipIndex < 0 ? (step > 0 ? 0 : root.chips.length - 1)
                                          : (root.chipIndex + step + root.chips.length) % root.chips.length
            root.useChip(next)
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.submit()
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: card.contentTopInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        spacing: Style.space(10)

        // The one input line: bell, what you typed (or an example), caret.
        Row {
          width: parent.width
          spacing: Style.space(10)

          Text {
            id: bell
            text: "\u{f0020}"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            anchors.verticalCenter: parent.verticalCenter
          }

          Item {
            width: parent.width - bell.width - parent.spacing
            height: typed.implicitHeight
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Text {
              id: typed
              textFormat: Text.PlainText
              width: Math.min(implicitWidth, parent.width - caret.width - Style.space(2))
              text: root.filterText || "30m Check the oven"
              color: root.foreground
              opacity: root.filterText ? 1 : 0.4
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              elide: Text.ElideLeft
            }

            Rectangle {
              id: caret
              x: root.filterText ? typed.width + Style.space(1) : 0
              width: Math.max(1, Style.space(2))
              height: typed.implicitHeight
              radius: width / 2
              color: root.accent
              SequentialAnimation on opacity {
                running: root.opened
                loops: Animation.Infinite
                NumberAnimation { to: 0; duration: 530; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1; duration: 530; easing.type: Easing.InOutQuad }
              }
            }
          }
        }

        // Read-back: when it fires and what it says, or what is missing.
        Text {
          readonly property string note: root.parsed.message.replace(/&/g, "&amp;").replace(/</g, "&lt;")
          width: parent.width
          textFormat: Text.StyledText
          wrapMode: Text.Wrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          color: root.foreground
          text: {
            if (root.valid) {
              var when = "<font color='" + root.accent + "'>in " + ReminderFlowModel.describeMinutes(root.parsed.minutes)
                + " · " + ReminderFlowModel.describeAt(root.parsed.minutes, root.now) + "</font>"
              return when + (note ? "  ·  " + note : "  ·  <i>no note</i>")
            }
            if (root.filterText.trim())
              return "<font color='" + (root.tried ? root.urgent : root.foreground) + "'>Add a time: 10m, 1h30, at 15:30, or “… in 20 min”</font>"
            return "Time and note on one line: <b>1h30</b> Stand-up · <b>at 6pm</b> Gym · Tea <b>in 10 min</b>"
          }
          opacity: root.valid || root.tried ? 1 : 0.62
        }

        // Quick times: click one, or Tab / Shift+Tab to cycle. Keeps the note.
        Flow {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.chips

            Rectangle {
              required property string modelData
              required property int index
              readonly property bool current: root.filterText.trim() === modelData || root.filterText.trim().indexOf(modelData + " ") === 0
              width: chipText.implicitWidth + Style.space(18)
              height: chipText.implicitHeight + Style.space(8)
              radius: height / 2
              color: current ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : root.chipFill
              border.width: 1
              border.color: current ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
                                    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

              Text {
                id: chipText
                anchors.centerIn: parent
                text: modelData
                color: parent.current ? root.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.useChip(index)
              }
            }
          }
        }

        Text {
          width: parent.width
          text: "Enter set  ·  Tab quick time  ·  Esc clear / close"
          color: root.foreground
          opacity: 0.4
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
