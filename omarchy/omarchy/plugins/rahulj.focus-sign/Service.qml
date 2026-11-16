// Focus sign: the pixel LED-panel wallpapers tell you which screen has focus.
// Its </> stays lit on the focused screen; on every other screen a copy of the
// wallpaper with the sign switched off is drawn over it, in the layer just
// above the wallpaper and below every window. Nothing moves: the switched-off
// copy jumps screens the moment focus does. Under windows it is hidden anyway,
// so it only speaks on empty screens.
//
// That layer is also above OWE's intro video, so the copy steps aside while a
// wallpaper changes: it goes the instant the background link moves, stays away
// while an intro plays (`owe status`) or the shell still holds a theme switch
// (`themeIntroStatus`), and fades back in once the new still has settled.
// Without this, the unfocused screens showed a still over the intro, and after
// a theme switch they kept the old theme's copy for a few seconds.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  // The pixel wallpapers this works with, each mapped to its switched-off copy:
  // Tokyo Night's pixel-led, and Shinkai's three scenes. Shinkai's are
  // rendered by backgrounds/src/shinkai-pixel.py (its `off` mode).
  readonly property string branding: home + "/.config/omarchy/branding/focus-sign/"
  readonly property var offCopies: ({
    [home + "/.config/omarchy/backgrounds/tokyo-night/pixel-led.png"]: branding + "pixel-led-off.png",
    [home + "/.config/omarchy/backgrounds/shinkai/1-abyss.png"]: branding + "shinkai-abyss-off.png",
    [home + "/.config/omarchy/backgrounds/shinkai/2-tide.png"]: branding + "shinkai-tide-off.png",
    [home + "/.config/omarchy/backgrounds/shinkai/3-recolour.png"]: branding + "shinkai-recolour-off.png"
  })
  readonly property string stateDir: home + "/.local/state/omarchy/current"
  readonly property string backgroundLink: stateDir + "/background"

  // Only while one of those wallpapers is the one in use.
  property string currentBackground: ""
  readonly property string offWallpaper: offCopies[currentBackground] || ""
  readonly property bool active: offWallpaper !== ""

  // Held while the wallpaper is changing. It starts held for the login intro,
  // which plays on every screen behind this layer, and waits longer then: the
  // intro starts only once OWE is up.
  property bool held: true
  property double lastChange: Date.now()
  property int settleMs: 9000
  property int quietPolls: 0
  property real reveal: 0

  readonly property string focusedName: Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name) : ""

  function hold() {
    lastChange = Date.now()
    quietPolls = 0
    fadeIn.stop()
    reveal = 0
    held = true
  }

  NumberAnimation {
    id: fadeIn
    target: root
    property: "reveal"
    to: 1
    duration: 450
    easing.type: Easing.OutCubic
  }

  Process {
    id: readLink
    command: ["readlink", "-f", root.backgroundLink]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var path = String(text).trim()
        if (path !== root.currentBackground) {
          if (root.currentBackground !== "") root.hold()
          root.currentBackground = path
        }
      }
    }
  }

  function readBackground() {
    if (!readLink.running) readLink.running = true
    else readAgain.restart()
  }
  Timer { id: readAgain; interval: 60; onTriggered: root.readBackground() }

  // The background symlink is swapped by rename, so the directory is watched.
  // A slow poll stays as a fallback should the watcher die.
  Process {
    id: watcher
    running: true
    command: ["inotifywait", "-m", "-q", "-e", "create,moved_to,delete", "--format", "%f", root.stateDir]
    stdout: SplitParser {
      onRead: function(name) {
        name = String(name).trim()
        if (name === "background") {
          root.hold()
          root.readBackground()
        }
      }
    }
    onExited: restartWatcher.restart()
  }
  Timer { id: restartWatcher; interval: 5000; onTriggered: watcher.running = true }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.readBackground()
  }

  // While held: busy as long as OWE plays an intro or the shell has a theme
  // switch pending; two quiet polls in a row after the settle time release it.
  Process {
    id: gate
    command: ["sh", "-c",
      "owe status 2>/dev/null | jq -r '.intro // false' 2>/dev/null || echo false; " +
      "omarchy-shell shell themeIntroStatus \"$(stat -Lc %d:%i \"$HOME/.local/state/omarchy/current/theme\" 2>/dev/null)\" 2>/dev/null || echo ready"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = String(text)
        var busy = out.indexOf("true") !== -1 || out.indexOf("pending") !== -1
        if (busy) {
          root.lastChange = Date.now()
          root.quietPolls = 0
        } else if (Date.now() - root.lastChange >= root.settleMs && ++root.quietPolls >= 2) {
          root.held = false
          root.settleMs = 1200
          fadeIn.restart()
        }
      }
    }
  }
  Timer {
    interval: 200
    running: root.held
    repeat: true
    onTriggered: if (!gate.running) gate.running = true
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.active && !root.held && root.focusedName !== "" && String(modelData.name) !== root.focusedName
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "rahulj-focus-sign"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      // Takes no input: clicks reach the desktop as before.
      mask: Region {}

      // Drawn exactly as the shell draws the wallpaper (cover crop, decoded at
      // this screen's size), so the copy lines up with it pixel for pixel.
      // It fades in only after a wallpaper change; focus moves stay instant.
      Image {
        anchors.fill: parent
        opacity: root.reveal
        source: root.active ? "file://" + root.offWallpaper : ""
        sourceSize.width: Math.ceil(panel.width * panel.screen.devicePixelRatio)
        sourceSize.height: Math.ceil(panel.height * panel.screen.devicePixelRatio)
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        smooth: true
        mipmap: true
      }
    }
  }
}
