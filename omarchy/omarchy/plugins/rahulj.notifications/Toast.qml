// One notification card. Layout.js decides where it goes and the scene animates
// it there; the card owns only what happens inside its own edges.

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

import "Security.js" as Security
import "Delivery.js" as Delivery
import "Store.js" as Store
import "Icons.js" as Icons

Item {
  id: card

  property var row: ({})
  property var place: ({ y: 0, scale: 1, opacity: 1, z: 1, front: true, hidden: false })
  property var scene: null                   // owns the clock; without it the card stands still
  property bool expanded: false
  property bool sole: false                  // the only card on screen
  property bool paused: false
  property bool hovered: false
  property bool selected: false              // the keyboard's card
  property double now: Date.now()
  property real cardWidth: Style.space(380)
  property var actions: []                   // what the sender put on the wire
  // Personal: the top card points up at the bar's bell with a notch drawn as
  // part of its own outline, so it moves, fades and colours with the card.
  property bool pointerShown: false
  property real pointerX: width / 2          // the notch's centre, card-local

  // The pointer in the deck's coordinates: the deck owns hover, so cards and
  // their buttons work out what is under it themselves.
  property real hoverX: -1
  property real hoverY: -1
  readonly property real localHoverX: hoverX - x
  readonly property real localHoverY: hoverY - y

  function pointerOver(item) {
    if (!hovered) return false
    var origin = item.mapToItem(card, 0, 0)
    return localHoverX >= origin.x && localHoverX <= origin.x + item.width
        && localHoverY >= origin.y && localHoverY <= origin.y + item.height
  }

  // Nothing while it is fresh, then minutes, then the clock time, then
  // "yesterday", then the day.
  function ago() {
    var t = Number(row.ts || 0) * 1000
    if (!t) return ""
    var s = Math.max(0, (now - t) / 1000)
    if (s < 300) return ""
    if (s < 3600) return I18n.t("notifications.minutesAgo").arg(I18n.formatNumber(Math.round(s / 60)))
    var then = new Date(t)
    var locale = Qt.locale(I18n.formatLocale)
    var sameDay = new Date(now).toDateString() === then.toDateString()
    if (sameDay) return locale.toString(then, "HH:mm")
    var yest = new Date(now - 86400000).toDateString() === then.toDateString()
    if (yest) return I18n.t("notifications.yesterday")
    return locale.toString(then, "ddd")
  }

  // The card's only duration: crossfades inside its own edges.
  readonly property int fade: Style.duration(150)

  signal expired()
  signal activated()
  signal dismissed()
  signal codeCopied(string code)
  signal actionInvoked(string identifier)
  signal execInvoked(int index)
  signal linkOpened()

  readonly property bool critical: row.urgency === 2
  readonly property color dimColor: Qt.darker(Commons.Color.notifications.text, 1.4)
  readonly property color bodyColor: Qt.darker(Commons.Color.notifications.text, 1.15)
  // Personal (Night Glass): the urgency colour, used by the app pill and the
  // draining line. Low is the theme's comment grey, normal the theme blue,
  // critical red.
  readonly property color lowColor: "#565f89"
  readonly property color accentColor: critical ? Commons.Color.urgent
                                               : (row.urgency === 0 ? lowColor : Commons.Color.notifications.countdown)
  readonly property bool hasBody: String(row.body || "").length > 0
  readonly property bool redacted: Store.redacted(row)
  // Omarchy's own toasts and bare notify-send calls name no source worth a
  // letter, and a summary that opens with its own glyph already has its mark.
  readonly property bool anonymous: row.app === "omarchy-action" || row.app === "notify-send"
  readonly property bool glyphLed: Delivery.summaryStartsWithGlyph(row.summary)
  readonly property real contentPaddingY: hasBody ? Style.space(10) : Style.space(7)
  // A card behind the front of a collapsed deck is a shape: the cards are
  // translucent, so its text would read through the one in front. The text
  // fades as the deck moves (opening, closing, a card arriving over it or
  // leaving it the front) and jumps with it when a keypress skips the move.
  // It goes out in half the time it comes in, so a card arriving over this one
  // doesn't show both texts at once.
  property real contentOpacity: expanded || place.front ? 1 : 0
  Behavior on contentOpacity {
    id: contentFade
    enabled: !(card.scene && card.scene.jumping)
    NumberAnimation {
      duration: contentFade.targetValue > 0 ? card.fade : card.fade / 2
      easing.type: Easing.OutCubic
    }
  }

  // The body opens in an open deck, or on hover when nothing else is on
  // screen. Never in a collapsed stack: every card there is drawn at the front
  // one's height, so a tall one would hang out of it.
  readonly property bool bodyOpen: expanded || (hovered && sole)
  readonly property int bodyLines: bodyOpen ? 8 : 2

  // Every code the body carried; two or more have to say which they copy.
  readonly property var foundCodes: {
    var all = String(row.codes || row.code || "").split(" ")
    var out = []
    for (var i = 0; i < all.length; i++) if (all[i]) out.push(all[i])
    return out
  }

  // Buttons an Omarchy sender asked for (--action), as commands the shell runs.
  readonly property var execActions: Security.parseExecActions(row.execActions) || []

  // Every button, in Delivery.deeds' order, with the code labels translated.
  readonly property var allDeeds: {
    var out = Delivery.deeds(row, actions)
    for (var i = 0; i < out.length; i++)
      if (out[i].kind === "code")
        out[i].label = foundCodes.length > 1 ? I18n.t("notifications.copyThisCode").arg(out[i].value)
                                             : I18n.t("notifications.copyCode")
    return out
  }

  // Marks on the headline. Buttons say for themselves that a card can be
  // acted on; a verification code is marked even where they are hidden.
  readonly property var marks: {
    var out = []
    if (String(row.code || "")) out.push("\u{f0306}")
    return out
  }

  function doDeed(deed) {
    var kind = String(deed.kind || "")
    if (kind === "action") { actionInvoked(String(deed.value)); return }
    if (kind === "exec") { execInvoked(Number(deed.value)); return }
    codeCopied(String(deed.value))
    copiedCode = String(deed.value)
    tick.restart()
  }

  // The code last copied, ticked for a moment: copying is silent.
  property string copiedCode: ""
  Timer { id: tick; interval: 1400; onTriggered: card.copiedCode = "" }

  // Pausing holds the remaining time rather than restarting it.
  // An update (replaces_id) rewrites the row in place with a new arrival
  // time, and gets a fresh display period of its own duration. Its picture
  // may be new at the same path, so the image is read again too.
  property real remaining: Number(row.duration || 0)
  readonly property bool ticking: Number(row.duration || 0) > 0 && !paused
  readonly property string arrival: String(row.ts) + ":" + String(row.duration)
  property bool reloading: false
  onArrivalChanged: {
    remaining = Number(row.duration || 0)
    thumb.failed = 0
    reloading = true
    Qt.callLater(function() { card.reloading = false })
  }

  // Coarse: nothing draws the time left, only the expiry needs it.
  Timer {
    interval: 500
    repeat: true
    running: card.ticking && card.remaining > 0
    onTriggered: {
      card.remaining -= interval
      if (card.remaining <= 0) card.expired()
    }
  }

  width: cardWidth
  height: body.height

  LayoutMirroring.enabled: Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit: true

  // ---------------------------------------------------- what the scene reads
  //
  // Summed explicitly rather than taken from the laid-out height minus the
  // action area: that area's height derives from the card's, so subtracting it
  // back out is a binding loop. hasBody, not bodyBox.visible: Item.visible
  // includes ancestors, and an inactive output must not shrink the measurement.
  readonly property real textBlock:
      headline.height + (hasBody ? column.spacing + bodyBox.height : 0)

  // The same block at its two-line height: the icon is centred on this so a
  // body opening on hover does not walk it down the card.
  readonly property real restingBlock:
      headline.height + (hasBody ? column.spacing + bodyBox.restHeight : 0)

  // A block shorter than the mark is centred against it, measured at rest.
  readonly property real textOffset: Math.max(0, (thumb.height - restingBlock) / 2)

  readonly property real fixedHeight: plate.borderTop + plate.borderBottom
      + contentPaddingY * 2 + Math.max(thumb.height, textOffset + textBlock)

  // The height this card's *state* implies, a step function the deck lays out
  // from. Feeding a mid-animation height back into the layout stalls the stack.
  readonly property real targetHeight: fixedHeight + deedArea.wanted

  // The height the scene says it is right now, on the way there.
  property real drawnHeight: targetHeight


  y: scene ? scene.at(row.key, "y") : 0
  z: place.z
  scale: scene ? scene.at(row.key, "scale") : 1
  opacity: place.hidden ? 0 : (scene ? scene.at(row.key, "opacity") : 1)
  transformOrigin: Item.Top

  // `visible` is deliberately unbound: anything derived from layout output
  // (opacity, place.hidden) closes a binding loop through `heights`. A hidden
  // card is at opacity 0 and costs no drawing; `enabled` refuses the pointer.
  enabled: !place.hidden && !place.leaving

  // BorderSurface keeps gradients and per-side border widths; content below is
  // inset by those exact widths. Personal: it is kept only for those insets;
  // the card itself is drawn by cardShape below.
  BorderSurface {
    id: plate
    visible: false
    width: body.width
    height: body.height
    radius: Style.space(14)
    color: Commons.Color.notifications.background
    borderSpec: card.critical
                ? Border.surfaceSpec("notifications", "border-critical", Commons.Color.urgent,
                                     Math.max(1, Style.space(2)))
                : Border.surfaceSpec("notifications", "border", Commons.Color.notifications.border,
                                     Math.max(1, Style.space(2)))
  }

  // Personal "Night Glass" card: a lifted Tokyo Night surface (a shade lighter
  // than any window, a little see-through so Hyprland's blur still frosts it),
  // with the focused-window gradient as its rim (theme overlay
  // [notifications]; red for critical). To stand apart from windows it also
  // has a slab edge underneath that gives it thickness, and a long shadow falling down-left, as if lit from the bar.
  // Drawn as one outline, so the top card's notch towards the bell is the
  // same surface and rim as the card.
  readonly property real notchRoom: Style.space(8)
  // The notch grows out of the top edge only once the card has settled, and
  // goes back in before it leaves, so it never swings or zooms with the card.
  property bool settled: true
  property real notchGrow: pointerShown && settled && !leavingNow ? 1 : 0
  Behavior on notchGrow { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
  readonly property real notchSize: notchRoom * notchGrow
  readonly property real tipX: Math.max(plate.radius + notchRoom, Math.min(width - plate.radius - notchRoom, pointerX))
  readonly property var rimSpec: plate.borderSpec
  readonly property var rimColors: rimSpec && rimSpec.gradient && rimSpec.gradient.enabled
                                   ? rimSpec.gradient.colors : [Border.color(rimSpec), Border.color(rimSpec)]
  readonly property real rimAngle: rimSpec && rimSpec.gradient && rimSpec.gradient.enabled ? (rimSpec.gradient.angle || 0) : 0
  function rimStop(i) { return i < rimColors.length ? rimColors[i] : rimColors[rimColors.length - 1] }
  function rimAt(i) { return rimColors.length <= 1 ? (i === 0 ? 0 : 1) : (i >= rimColors.length ? 1 : i / (rimColors.length - 1)) }

  // The card's outline inset by k and moved down by dy: a rounded rectangle
  // whose top edge rises into a 45° notch. Inset, the notch's sides move in
  // parallel, so the rim keeps one width all the way round.
  function outline(k, dy, w, h) {
    var room = notchRoom, r = plate.radius, notch = notchSize
    var tip = tipX
    var top = room + k + dy, left = k, right = w - k, bottom = room + h - k + dy
    var rr = Math.max(0, r - k)
    var p = "M " + (left + rr) + " " + top
    if (notch > 0) {
      var d = k * (Math.SQRT2 - 1)
      p += " L " + (tip - notch + d) + " " + top
         + " L " + tip + " " + (room - notch + k * Math.SQRT2 + dy)
         + " L " + (tip + notch - d) + " " + top
    }
    p += " L " + (right - rr) + " " + top + " A " + rr + " " + rr + " 0 0 1 " + right + " " + (top + rr)
       + " L " + right + " " + (bottom - rr) + " A " + rr + " " + rr + " 0 0 1 " + (right - rr) + " " + bottom
       + " L " + (left + rr) + " " + bottom + " A " + rr + " " + rr + " 0 0 1 " + left + " " + (bottom - rr)
       + " L " + left + " " + (top + rr) + " A " + rr + " " + rr + " 0 0 1 " + (left + rr) + " " + top + " Z"
    return p
  }

  // The contact shadow: tight and a little darker right under the card, the
  // way a real object darkens the surface it nearly touches.
  Item {
    id: contactShadow
    readonly property real spill: Style.space(14)
    x: -spill
    y: -card.notchRoom - spill + Style.space(3)
    width: body.width + spill * 2
    height: body.height + card.notchRoom + spill * 2
    opacity: card.place.front || card.expanded ? 0.45 * card.contentOpacity : 0
    visible: opacity > 0.01
    layer.enabled: true
    layer.effect: MultiEffect {
      autoPaddingEnabled: true
      blurEnabled: true
      blur: 1.0
      blurMax: 10
    }
    Shape {
      x: contactShadow.spill
      y: contactShadow.spill
      width: body.width
      height: body.height + card.notchRoom
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: -1
        strokeColor: "transparent"
        fillColor: "#05060e"
        PathSvg { path: card.outline(Style.space(2), 0, body.width, body.height) }
      }
    }
  }

  Item {
    id: cardShape
    readonly property real room: card.notchRoom
    readonly property real rim: plate.borderTop
    readonly property real gdx: Math.cos(card.rimAngle * Math.PI / 180)
    readonly property real gdy: Math.sin(card.rimAngle * Math.PI / 180)
    readonly property real glen: (Math.abs(width * gdx) + Math.abs(height * gdy)) / 2
    readonly property string outer: card.outline(0, 0, width, body.height)
    readonly property string inner: card.outline(rim, 0, width, body.height)
    // S1 · Lifted surface: a shade lighter at the top, like a lit sheet.
    readonly property color base: Commons.Color.notifications.background
    readonly property color lit: Qt.rgba(Math.min(1, base.r * 1.13), Math.min(1, base.g * 1.13), Math.min(1, base.b * 1.12), base.a)

    y: -room
    width: body.width
    height: body.height + room
    layer.enabled: true
    // The ambient shadow: wide, soft and faint, in a deep navy rather than
    // black (shadows on a blue-dark desktop read blue), a little smaller than
    // the card so no hard edge shows, and falling slightly down-left, away
    // from the bar. The contact shadow below does the close-in darkening.
    layer.effect: MultiEffect {
      autoPaddingEnabled: true
      shadowEnabled: true
      shadowColor: "#05060e"
      shadowOpacity: 0.42
      shadowBlur: 1.0
      blurMax: 64
      shadowScale: 0.97
      shadowVerticalOffset: Style.space(14)
      shadowHorizontalOffset: -Style.space(4)
    }

    // S6 · Floating slab: two edges under the bottom of the card give it
    // thickness. Only the part below the card is drawn, so the see-through
    // surface does not show them through it.
    Item {
      anchors.left: parent.left
      anchors.right: parent.right
      y: cardShape.room + body.height - plate.radius
      height: plate.radius + Style.space(6)
      clip: true
      Shape {
        y: -parent.y
        width: cardShape.width
        height: cardShape.height + Style.space(6)
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: -1
          strokeColor: "transparent"
          fillColor: "#262b40"
          PathSvg { path: card.outline(0, Style.space(4), cardShape.width, body.height) }
        }
        ShapePath {
          strokeWidth: -1
          strokeColor: "transparent"
          fillColor: "#3b4261"
          PathSvg { path: card.outline(0, Style.space(2), cardShape.width, body.height) }
        }
      }
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: -1
        strokeColor: "transparent"
        fillGradient: LinearGradient {
          x1: 0; y1: cardShape.room; x2: 0; y2: cardShape.height
          GradientStop { position: 0; color: cardShape.lit }
          GradientStop { position: 1; color: cardShape.base }
        }
        PathSvg { path: cardShape.outer }
      }

      ShapePath {
        strokeWidth: -1
        strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill
        fillGradient: LinearGradient {
          x1: cardShape.width / 2 - cardShape.gdx * cardShape.glen
          y1: cardShape.height / 2 - cardShape.gdy * cardShape.glen
          x2: cardShape.width / 2 + cardShape.gdx * cardShape.glen
          y2: cardShape.height / 2 + cardShape.gdy * cardShape.glen
          GradientStop { position: card.rimAt(0); color: card.rimStop(0) }
          GradientStop { position: card.rimAt(1); color: card.rimStop(1) }
          GradientStop { position: card.rimAt(2); color: card.rimStop(2) }
          GradientStop { position: card.rimAt(3); color: card.rimStop(3) }
        }
        PathSvg { path: cardShape.outer + " " + cardShape.inner }
      }
    }

    // S1: a faint light line just inside the top edge, like light on glass.
    // It stops either side of the notch, so the notch has no line across it.
    readonly property real gapLeft: card.notchSize > 0 ? card.tipX - card.notchRoom - Style.space(3) : cardShape.width / 2
    readonly property real gapRight: card.notchSize > 0 ? card.tipX + card.notchRoom + Style.space(3) : cardShape.width / 2
    Rectangle {
      x: plate.radius
      y: cardShape.room + cardShape.rim + 1
      width: Math.max(0, cardShape.gapLeft - plate.radius)
      height: 1
      color: Qt.rgba(0.75, 0.79, 0.96, 0.16)
    }
    Rectangle {
      x: cardShape.gapRight
      y: cardShape.room + cardShape.rim + 1
      width: Math.max(0, cardShape.width - plate.radius - cardShape.gapRight)
      height: 1
      color: Qt.rgba(0.75, 0.79, 0.96, 0.16)
    }
  }

  // The keyboard's card is tinted with the theme's hover fill, buttons and all.
  Rectangle {
    anchors.fill: plate
    anchors { leftMargin: plate.borderLeft; rightMargin: plate.borderRight
              topMargin: plate.borderTop; bottomMargin: plate.borderBottom }
    visible: card.selected
    color: Style.hoverFillFor(Commons.Color.notifications.text, Commons.Color.accent)
  }

  // Personal: the time left, as a thin line along the bottom edge that drains
  // to the left (blue -> purple like the rim; grey for low urgency). Critical
  // cards wait to be dismissed and have none. Smoothed between the coarse
  // half-second ticks.
  Rectangle {
    id: countdownLine
    readonly property real total: Number(card.row.duration || 0)
    readonly property real fraction: total > 0 ? Math.max(0, Math.min(1, card.remaining / total)) : 0
    visible: total > 0 && !card.critical && (card.place.front || card.expanded) && !card.paused
    anchors { left: plate.left; bottom: plate.bottom
              leftMargin: plate.radius; bottomMargin: plate.borderBottom }
    height: Math.max(1, Style.space(2))
    radius: height / 2
    width: Math.max(0, (plate.width - plate.radius * 2) * fraction)
    opacity: card.contentOpacity
    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.Linear } }
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: card.row.urgency === 0 ? card.lowColor : Commons.Color.notifications.countdown }
      GradientStop { position: 1; color: card.row.urgency === 0 ? card.lowColor : "#bb9af7" }
    }
  }

  // Personal (S7 · Pop-out): a new card swings out of the screen edge towards
  // you in 3D (a turn about its upright axis, starting close and large), over-
  // shoots a little, then settles flat; it slides back out as it leaves, and
  // a hovered card lifts slightly towards you. Only fresh arrivals pop: a
  // reload or an opening deck keeps its cards where they are.
  transform: [
    Translate { id: slide; x: 0 },
    Rotation { id: swing; axis { x: 0; y: 1; z: 0 } angle: 0
               origin.x: card.width / 2; origin.y: card.height / 2 },
    Scale { id: pop; xScale: 1; yScale: xScale
            origin.x: card.width / 2; origin.y: card.height / 2 },
    // Pinned at the notch's tip on the top card, so the tip stays on the bell.
    Scale { id: lift; xScale: card.hovered ? 1.02 : 1; yScale: xScale
            origin.x: card.pointerShown ? card.tipX : card.width / 2
            origin.y: card.pointerShown ? 0 : card.height / 2
            Behavior on xScale { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutBack } } }
  ]
  readonly property bool leavingNow: !!place.leaving
  onLeavingNowChanged: {
    popIn.stop()
    slideOut.stop()
    // A card brought back by an update returns to its place at once.
    if (!leavingNow) { slide.x = 0; swing.angle = 0; pop.xScale = 1 }
    else if (!(scene && scene.jumping)) slideOut.start()
  }
  ParallelAnimation {
    id: popIn
    onStarted: card.settled = false
    onFinished: card.settled = true
    onStopped: card.settled = true
    NumberAnimation {
      target: slide; property: "x"; from: card.cardWidth * 0.7; to: 0
      duration: Style.duration(620); easing.type: Easing.OutBack; easing.overshoot: 1.2
    }
    NumberAnimation {
      target: swing; property: "angle"; from: -50; to: 0
      duration: Style.duration(820); easing.type: Easing.OutBack; easing.overshoot: 1.6
    }
    SequentialAnimation {
      NumberAnimation { target: pop; property: "xScale"; from: 1.15; to: 1.05
                        duration: Style.duration(450); easing.type: Easing.OutCubic }
      NumberAnimation { target: pop; property: "xScale"; to: 1
                        duration: Style.duration(350); easing.type: Easing.InOutQuad }
    }
  }
  NumberAnimation {
    id: slideOut
    target: slide; property: "x"; to: card.cardWidth * 0.5
    duration: Style.duration(200)
    easing.type: Easing.InCubic
  }
  Component.onCompleted: if (scene && scene.fresh && scene.fresh[row.key]) popIn.start()

  Item {
    id: body
    width: parent.width
    height: card.drawnHeight

    Row {
      id: layout
      // Top-anchored: centred content would slide up as the card grows.
      anchors { left: parent.left; right: parent.right; top: parent.top
                leftMargin: plate.contentLeftInset + Style.space(12)
                rightMargin: plate.contentRightInset + Style.space(12)
                topMargin: plate.contentTopInset + card.contentPaddingY }
      spacing: thumb.compact ? Style.space(8) : Style.space(12)

      // The sender's image, else the icon resolved for its source, else the
      // glyph an Omarchy sender asked for, else the first letter of the source.
      Item {
        id: thumb
        readonly property bool pictured: picture.status === Image.Ready && best !== ""
        readonly property bool glyphed: !pictured && String(card.row.glyph || "").length > 0
        readonly property bool lettered: !pictured && !glyphed && !card.anonymous && !card.glyphLed
        // A one-line toast keeps its glyph at text size beside the line.
        readonly property bool compact: glyphed && !card.hasBody
        readonly property real slot: Style.space(40)
        width: pictured || lettered ? slot : glyphed ? (compact ? glyphText.implicitWidth : slot) : 0
        height: width > 0 ? (compact ? glyphText.implicitHeight : slot) : 0
        visible: width > 0
        y: Math.max(0, (card.restingBlock - height) / 2)
        opacity: card.contentOpacity

        function entryIcon(icon) {
          var value = String(icon || "")
          return value.charAt(0) === "/" ? Util.fileUrl(value) : value ? Quickshell.iconPath(value, true) : ""
        }

        // Only what the sender handed over and what is installed for its source:
        // Quickshell.iconPath answers "" for a missing icon when asked to check,
        // where a bare image://icon/ URL would draw a checkerboard.
        readonly property string sent: /^image:\/\/qsimage\/[0-9]+\/[0-9]+$/.test(String(card.row.image || ""))
                                       ? String(card.row.image) : Security.localImageUrl(card.row.image)

        // Best first: the sender's picture, then the icon theme, then a
        // desktop entry's icon (Icons.candidates has the names). A file that will not load gives way to the next.
        function firstOf(names, look) {
          for (var i = 0; i < names.length; i++) {
            var found = look(names[i])
            if (found) return found
          }
          return ""
        }
        readonly property var sources: {
          var appsRevision = DesktopEntries.applications.values.length
          var want = Icons.candidates(card.row)
          var found = [sent,
            firstOf(want.themed, function(name) { return Quickshell.iconPath(name, true) }),
            firstOf(want.entries, function(name) {
              var entry = DesktopEntries.heuristicLookup(name)
              return entry ? thumb.entryIcon(entry.icon) : ""
            })]
          return found.filter(function(url, i) { return url && found.indexOf(url) === i })
        }
        readonly property string sourcesKey: sources.join("\n")
        property int failed: 0
        onSourcesKeyChanged: failed = 0
        readonly property string best: sources[failed] || ""
        readonly property bool photo: best !== "" && best === sent
        readonly property bool mono: !photo && Icons.isSymbolic(best)

        Rectangle {
          anchors.fill: parent
          visible: thumb.lettered
          radius: Style.cornerRadius
          color: Style.normalFillFor(Commons.Color.notifications.text, card.accentColor, Commons.Color.urgent)

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: String(card.row.source || card.row.app || "?").substring(0, 1).toUpperCase()
            color: card.dimColor
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.weight: Font.DemiBold
          }
        }

        Text {
          id: glyphText
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: thumb.glyphed
          text: String(card.row.glyph || "")
          color: Commons.Color.notifications.text
          font.family: Delivery.omarchyGlyph(card.row.glyph) ? "omarchy" : Style.font.family
          font.pixelSize: (thumb.compact ? Style.font.icon : Style.font.displayLarge)
        }

        Image {
          id: picture
          anchors.fill: parent
          visible: thumb.pictured
          source: card.reloading ? "" : thumb.best
          onStatusChanged: if (status === Image.Error && thumb.failed < thumb.sources.length) thumb.failed += 1
          // A photo fills its square; an app icon keeps its own shape.
          fillMode: thumb.photo ? Image.PreserveAspectCrop : Image.PreserveAspectFit
          // Constant, so the slot resizing never reloads the image.
          sourceSize.width: thumb.slot * Screen.devicePixelRatio
          sourceSize.height: thumb.slot * Screen.devicePixelRatio
          asynchronous: true
          // A sender may write each picture to the same path (cover art, say).
          cache: !(thumb.photo && thumb.best.indexOf("file:") === 0)
          // A one-colour icon is brightened to a silhouette and tinted with the
          // theme's text colour, keeping its anti-aliased edge. A photo is
          // rounded like the card, only when the theme rounds at all.
          readonly property bool rounded: thumb.photo && Style.cornerRadius > 0
          opacity: thumb.mono ? 0.85 : 1
          layer.enabled: visible && (thumb.mono || rounded)
          layer.effect: MultiEffect {
            maskEnabled: picture.rounded
            maskSource: mask
            brightness: thumb.mono ? 1.0 : 0.0
            colorization: thumb.mono ? 1.0 : 0.0
            colorizationColor: Commons.Color.notifications.text
          }
        }

        Rectangle {
          id: mask
          anchors.fill: parent
          visible: false
          layer.enabled: true
          radius: Style.cornerRadius
          color: "black"
        }
      }

      Column {
        id: column
        y: card.textOffset
        width: layout.width - (thumb.visible ? thumb.width + layout.spacing : 0)
        spacing: Style.space(3)

        // Title, marks, and when it arrived.
        Item {
          id: headline
          width: parent.width
          height: Math.max(title.implicitHeight, rightSide.height)
          opacity: card.contentOpacity

          Text {
            textFormat: Text.PlainText
            id: title
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, parent.width - rightSide.width
                   - (titleMarks.visible ? titleMarks.width + Style.space(7) : 0)
                   - Style.space(8))
            text: card.redacted ? I18n.t("notifications.redactedSummary") : String(card.row.summary || "")
            color: Commons.Color.notifications.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: card.bodyOpen ? 8 : 3
            elide: Text.ElideRight
          }

          Row {
            id: titleMarks
            visible: card.marks.length > 0
            anchors.verticalCenter: title.verticalCenter
            // Placed by arithmetic, so it follows a right-to-left card itself.
            readonly property real titleInk: Math.min(title.implicitWidth, title.width)
            x: card.LayoutMirroring.enabled
               ? title.x + title.width - titleInk - Style.space(7) - width
               : title.x + titleInk + Style.space(7)
            spacing: Style.space(5)

            Repeater {
              model: card.marks
              Text {
                textFormat: Text.PlainText
                required property var modelData
                text: modelData
                color: Commons.Color.notifications.text
                opacity: 0.9
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
          }

          Row {
            id: rightSide
            anchors.right: parent.right
            anchors.verticalCenter: title.verticalCenter
            spacing: Style.space(5)

            // The time and the hover close mark share one square and
            // crossfade, so nothing in the headline moves.
            Item {
              width: Math.max(stamp.implicitWidth, shut.implicitWidth)
              height: Math.max(stamp.implicitHeight, shut.implicitHeight)
              anchors.verticalCenter: parent.verticalCenter

              // Personal: the sending app in a small pill in the urgency colour
              // (like the workspace number and the prompt's folder), then how
              // long ago, so the card says who it is from at a glance.
              Row {
                id: stamp
                anchors.centerIn: parent
                spacing: Style.space(5)
                readonly property string appLabel: card.anonymous ? "" : String(card.row.app || card.row.source || "").toLowerCase()
                readonly property string when: card.ago()
                opacity: card.hovered ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: card.fade; easing.type: Easing.InOutQuad } }

                Rectangle {
                  visible: stamp.appLabel !== ""
                  anchors.verticalCenter: parent.verticalCenter
                  width: pillText.implicitWidth + Style.space(12)
                  height: pillText.implicitHeight + Style.space(2)
                  radius: height / 2
                  color: card.accentColor

                  Text {
                    id: pillText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: stamp.appLabel
                    color: "#1a1b26"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.weight: Font.Bold
                  }
                }

                Text {
                  visible: stamp.when !== ""
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: stamp.when
                  color: card.dimColor
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Item {
                id: shut
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: closeMark.implicitWidth + Style.space(6)
                implicitHeight: closeMark.implicitHeight
                enabled: card.hovered
                opacity: card.hovered ? 1 : 0
                visible: opacity > 0.01
                readonly property bool hot: card.pointerOver(shut)
                Behavior on opacity { NumberAnimation { duration: card.fade; easing.type: Easing.InOutQuad } }

                Text {
                  id: closeMark
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "✕"
                  color: shut.hot ? Commons.Color.notifications.text : card.dimColor
                  font.pixelSize: Math.round(Style.font.caption * 1.44)
                }

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -Style.space(3)
                  cursorShape: Qt.PointingHandCursor
                  onClicked: card.dismissed()
                }
              }
            }
          }
        }

        FontMetrics {
          id: metrics
          font.family: Style.font.family
          font.pixelSize: Style.font.title
        }

        // StyledText, not RichText: it covers the tags Markup lets through,
        // keeps links clickable, and can still end a long body in an ellipsis.
        Text {
          id: bodyBox
          width: parent.width
          // The closed height, read only by the icon so it does not move.
          readonly property real restHeight: Math.ceil(Math.max(1, metrics.height) * Math.min(2, lineCount))
          visible: card.hasBody
          opacity: card.contentOpacity

          textFormat: Text.StyledText
          text: card.redacted ? I18n.t("notifications.redactedBody") : String(card.row.bodyRich || "")
          color: card.bodyColor
          linkColor: Commons.Color.notifications.countdown
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          wrapMode: Text.Wrap
          maximumLineCount: card.bodyLines
          elide: Text.ElideRight
          // Second gate: Markup already drops anchors it will not vouch for.
          onLinkActivated: function(url) { card.linkOpened(); Security.openExternalUrl(url) }
        }
      }
    }

    // The buttons, as a bar along the card's bottom edge: a hairline above,
    // equal segments split by hairlines, three to a line, and a short last line
    // stretched across. Drawn in the card because the surface is clipped. In
    // an open deck only the card under the pointer, or the keyboard, has them;
    // otherwise the front card of each deck does.
    Item {
      id: deedArea
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: plate.borderLeft; rightMargin: plate.borderRight
                bottomMargin: plate.borderBottom }

      readonly property bool shown: card.allDeeds.length > 0 && (card.expanded ? card.hovered : card.place.front)
      readonly property int columns: Math.max(1, Math.min(3, card.allDeeds.length))
      readonly property int rows: Math.ceil(card.allDeeds.length / columns)
      readonly property real rule: 1
      readonly property color ruleColor: Qt.rgba(card.dimColor.r, card.dimColor.g, card.dimColor.b, 0.35)
      readonly property real segmentHeight: Style.spacing.controlHeight + Style.space(6)
      readonly property real barHeight: rows * (rule + segmentHeight)
      // What the state asks for; the drawn height is whatever slack the
      // scene has given the card so far.
      readonly property real wanted: shown ? barHeight : 0
      height: Math.max(0, card.drawnHeight - card.fixedHeight)
      visible: height > 0
      clip: true

      Item {
        id: deedRow
        anchors.bottom: parent.bottom
        width: parent.width
        height: deedArea.barHeight
        opacity: deedArea.shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: card.fade; easing.type: Easing.InOutQuad } }

        Repeater {
          model: card.allDeeds
          DeedButton {
            required property var modelData
            required property int index
            readonly property int line: Math.floor(index / deedArea.columns)
            readonly property int slot: index % deedArea.columns
            readonly property int perLine: line < deedArea.rows - 1 ? deedArea.columns
                                           : card.allDeeds.length - line * deedArea.columns
            // Where the segment starts in reading order; the first action
            // sits on the right in a right-to-left language.
            readonly property real start: Math.round(slot * deedRow.width / perLine)
            deed: modelData
            toast: card
            hint: card.selected && index < 9 ? String(index + 1) : ""
            rule: deedArea.rule
            ruleColor: deedArea.ruleColor
            leftRule: slot > 0
            width: Math.round((slot + 1) * deedRow.width / perLine) - start
            x: card.LayoutMirroring.enabled ? deedRow.width - start - width : start
            y: line * (deedArea.rule + deedArea.segmentHeight)
            height: deedArea.rule + deedArea.segmentHeight
          }
        }
      }
    }

    // Under the content (z: -1) so buttons get their clicks first; anything
    // that does not accept a click falls through to here.
    MouseArea {
      anchors.fill: parent
      z: -1
      // Not hoverEnabled: a card taking hover would starve the deck's region.
      hoverEnabled: false
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor

      onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) card.activated()
        else card.dismissed()
      }
    }
  }
}
