import QtQuick
import qs.Commons
import qs.Commons as Commons

// A soft pill button in the style of the notification bell's filter chips: a
// faint fill and hairline at rest, brighter on hover, accent-tinted when
// selected or primary. Takes the properties Jarvis gave Omarchy's Ui.Button
// (text, selected, bordered, focusable), so it drops in for it.
Item {
  id: pill

  property string text: ""
  property string icon: ""          // optional Nerd Font glyph before the text
  property bool selected: false
  property bool primary: false      // the main action (Send): always tinted
  property bool bordered: true      // accepted for Ui.Button compatibility
  property bool focusable: false
  signal clicked()

  readonly property color fg: Commons.Color.popups.text
  readonly property color accent: Commons.Color.accent
  readonly property bool tinted: selected || primary

  implicitHeight: Style.space(30)
  implicitWidth: label.implicitWidth + Style.space(28)
  activeFocusOnTab: focusable
  opacity: enabled ? 1 : 0.4

  Keys.onReturnPressed: if (enabled) pill.clicked()
  Keys.onEnterPressed: if (enabled) pill.clicked()
  Keys.onSpacePressed: if (enabled) pill.clicked()

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: pill.tinted ? Qt.rgba(pill.accent.r, pill.accent.g, pill.accent.b, hover.hovered && pill.enabled ? 0.30 : 0.22)
                       : Qt.rgba(pill.fg.r, pill.fg.g, pill.fg.b, hover.hovered && pill.enabled ? 0.10 : 0.05)
    border.width: 1
    border.color: pill.activeFocus ? Qt.rgba(pill.accent.r, pill.accent.g, pill.accent.b, 0.85)
                : pill.tinted ? Qt.rgba(pill.accent.r, pill.accent.g, pill.accent.b, 0.60)
                : Qt.rgba(pill.fg.r, pill.fg.g, pill.fg.b, 0.08)
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Text {
    id: label
    anchors.centerIn: parent
    width: Math.min(implicitWidth, pill.width - Style.space(16))
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: pill.icon ? pill.icon + "  " + pill.text : pill.text
    color: pill.fg
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.weight: pill.tinted ? Font.DemiBold : Font.Normal
  }

  HoverHandler { id: hover; cursorShape: pill.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
  TapHandler { enabled: pill.enabled; onTapped: pill.clicked() }
}
