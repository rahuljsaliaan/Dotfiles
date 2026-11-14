// Focus sign: the pixel LED-panel wallpaper tells you which screen has focus.
// Its </> stays lit on the focused screen; on every other screen a copy of the
// wallpaper with the sign switched off is drawn over it, in the layer just
// above the wallpaper and below every window. Nothing moves: the switched-off
// copy jumps screens the moment focus does. Under windows it is hidden anyway,
// so it only speaks on empty screens.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  // The wallpaper this works with, and its switched-off copy.
  readonly property string litWallpaper: home + "/.config/omarchy/backgrounds/tokyo-night/pixel-led.png"
  readonly property string offWallpaper: home + "/.config/omarchy/branding/focus-sign/pixel-led-off.png"
  readonly property string backgroundLink: home + "/.local/state/omarchy/current/background"

  // Only while that wallpaper is the one in use.
  property string currentBackground: ""
  readonly property bool active: currentBackground === litWallpaper

  // Wait out the login intro, which plays on every screen behind this layer.
  property bool started: false
  Timer { interval: 9000; running: true; onTriggered: root.started = true }

  readonly property string focusedName: Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name) : ""

  Process {
    id: readLink
    command: ["readlink", "-f", root.backgroundLink]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.currentBackground = String(text).trim()
    }
  }
  // The background symlink is swapped rather than written, so it is re-read
  // on a slow timer instead of watched.
  Timer {
    interval: 4000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!readLink.running) readLink.running = true
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.active && root.started && root.focusedName !== "" && String(modelData.name) !== root.focusedName
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
      Image {
        anchors.fill: parent
        source: "file://" + root.offWallpaper
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
