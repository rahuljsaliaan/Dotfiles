import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Networking
import "WeatherIcons.js" as WeatherIcons
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Glasslock: blurred wallpaper, a large clock and date (with the weather), and
// a glass card with the avatar, a greeting, the password field, a Caps Lock
// warning and a mini player.
//
// It keeps the exact interface of Omarchy's stock LockView (same properties,
// signals and functions), so the password handling in Service.qml stays the
// stock, reviewed logic. Everything this view adds is display only.
Item {
  id: root

  // ---- Stock LockView interface ----
  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool fingerprintUnavailable: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  // Personal (from rahulj.lock): only the main screen draws the clock, card and
  // status. The others keep them (hidden) so typing still reaches PAM
  // whichever screen holds keyboard focus.
  property bool showInput: true

  // ---- Glasslock settings (the plugin's entry in shell.json) ----
  property var settings: ({})
  property string accountName: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }
  function colorSetting(name, fallback) {
    var value = String(setting(name, ""))
    return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value) ? value : fallback
  }
  function expandHome(path) {
    var p = String(path || "")
    if (p.indexOf("~/") === 0) return home + p.slice(1)
    if (p.indexOf("$HOME/") === 0) return home + p.slice(5)
    return p
  }

  readonly property string home: Quickshell.env("HOME")
  readonly property string userName: Quickshell.env("USER") || ""
  readonly property string displayName: {
    var name = String(setting("name", "")).trim()
    if (name.length === 0) name = accountName
    if (name.length === 0) name = userName.charAt(0).toUpperCase() + userName.slice(1)
    return name.slice(0, 40)
  }
  readonly property string avatarPath: {
    var p = expandHome(setting("avatar", ""))
    return p.length > 0 ? p : home + "/.face"
  }

  readonly property bool showWeather: setting("weather", true) !== false
  readonly property bool showMedia: setting("media", true) !== false
  readonly property bool showStatus: setting("status", true) !== false
  readonly property bool clock24: setting("clock24h", true) === true

  // ---- Colors: the theme's, unless the settings choose others ----
  readonly property color accent: colorSetting("accent", Commons.Color.accent)
  readonly property color accentLight: Qt.lighter(accent, 1.25)
  readonly property color errorColor: colorSetting("error", Commons.Color.lock.textError)
  readonly property color textColor: colorSetting("text", Commons.Color.lock.text)
  readonly property color dimText: Util.alpha(textColor, 0.62)
  // Personal: the lock overlay's frosted navy ([lock] background in the theme
  // overlay) and its rims: the focused-window gradient, red on a wrong password.
  readonly property color glass: Commons.Color.lock.background
  readonly property var rimSpec: Border.surfaceSpec("lock", "border-active", Commons.Color.lock.text, 2, "border-alpha")
  readonly property var errorRimSpec: Border.surfaceSpec("lock", "border-error", Commons.Color.lock.textError, 2, "border-alpha")

  readonly property var locale: Qt.locale(Commons.I18n.formatLocale)

  property bool revealPassword: false
  property date now: new Date()
  // Drives the entrance animation; reset every time the view is shown.
  property bool shown: false

  readonly property bool errorState: failureMessage.length > 0
  readonly property bool video: Util.isVideoPath(root.backgroundPath)

  readonly property string greeting: {
    var h = now.getHours()
    var key = h < 5 ? "greeting.night" : (h < 12 ? "greeting.morning" : (h < 18 ? "greeting.afternoon" : "greeting.evening"))
    return strings.t(key).arg(displayName)
  }

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // ---- Media (MPRIS): the playing player first, else any with a track ----
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    if (!showMedia) return null
    var fallback = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p) continue
      var proxy = String(p.dbusName || "").toLowerCase().indexOf("playerctld") !== -1
      if (proxy || !(p.trackTitle || p.trackArtist)) continue
      if (p.isPlaying) return p
      if (!fallback) fallback = p
    }
    return fallback
  }
  // Album art: local files, plus Spotify's own image server (the same image
  // the Spotify app already downloaded). Any other remote URL is ignored, so
  // a player cannot make the lock screen fetch from an arbitrary host.
  //
  // Remote art is downloaded by curl in its own process and shown from a local
  // file. Letting QML's Image fetch an https URL makes the shell's image loader
  // thread initialize OpenSSL, which crashed the whole shell (SIGSEGV inside
  // libcrypto while loading CA certificates) -- fatal for a lock screen.
  readonly property var trustedArtHosts: ["i.scdn.co"]
  readonly property string rawArtUrl: player && player.trackArtUrl ? String(player.trackArtUrl) : ""
  readonly property string remoteArtUrl: {
    var m = /^https:\/\/([^\/:?#\s]+)\/[^\s'"]*$/.exec(rawArtUrl)
    return m && trustedArtHosts.indexOf(m[1].toLowerCase()) !== -1 ? rawArtUrl : ""
  }
  readonly property string artCachePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/glasslock-art"
  property string downloadedArtFor: ""
  property int artVersion: 0
  readonly property string artUrl: {
    if (rawArtUrl.indexOf("file://") === 0) return rawArtUrl
    if (remoteArtUrl.length > 0 && downloadedArtFor === remoteArtUrl)
      return Util.fileUrl(artCachePath) + "?v=" + artVersion
    return ""
  }

  onRemoteArtUrlChanged: fetchArt()
  function fetchArt() {
    if (remoteArtUrl.length === 0 || downloadedArtFor === remoteArtUrl) return
    if (artProc.running) { artRetry.restart(); return }
    artProc.wanted = remoteArtUrl
    artProc.command = ["curl", "-fsS", "--max-time", "6", "--max-filesize", "2097152",
      "-o", artCachePath, remoteArtUrl]
    artProc.running = true
  }

  Process {
    id: artProc
    property string wanted: ""
    onExited: function(exitCode) {
      if (exitCode === 0 && wanted === root.remoteArtUrl) {
        root.artVersion += 1
        root.downloadedArtFor = wanted
      }
      if (root.remoteArtUrl !== wanted) root.fetchArt()
    }
  }

  Timer { id: artRetry; interval: 300; onTriggered: root.fetchArt() }

  // ---- Battery (UPower) ----
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!(battery && battery.isPresent)
  readonly property int batteryLevel: hasBattery ? Math.round(Number(battery.percentage || 0) * 100) : -1
  readonly property bool charging: hasBattery && !UPower.onBattery
  readonly property string batteryIcon: {
    if (charging) return "󰂄"
    var icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    return icons[Math.max(0, Math.min(10, Math.round(batteryLevel / 10)))]
  }

  // ---- Wi-Fi (NetworkManager) ----
  readonly property var wifiNetwork: {
    var devices = Networking.devices ? Networking.devices.values : []
    for (var i = 0; i < devices.length; i++) {
      var d = devices[i]
      if (!d || d.type !== DeviceType.Wifi || !d.networks) continue
      var nets = d.networks.values
      for (var j = 0; j < nets.length; j++) if (nets[j] && nets[j].connected) return nets[j]
    }
    return null
  }
  readonly property string wifiIcon: {
    if (!Networking.wifiEnabled) return "󰤮"
    if (!wifiNetwork) return "󰤯"
    var s = Number(wifiNetwork.signalStrength || 0)
    if (s > 0.75) return "󰤨"
    if (s > 0.5) return "󰤥"
    if (s > 0.25) return "󰤢"
    return "󰤟"
  }

  // ---- Caps Lock: read from the keyboard LED, which needs no permissions ----
  property bool capsLock: false

  function checkCapsLock() {
    if (!capsProc.running) capsProc.running = true
  }

  Process {
    id: capsProc
    command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.capsLock = /(^|\n)\s*[1-9]/.test(text)
    }
  }

  Timer {
    interval: 700
    running: root.visible && root.loadBackground
    repeat: true
    triggeredOnStart: true
    onTriggered: root.checkCapsLock()
  }

  // ---- Weather: Omarchy's location service + Open-Meteo, at most every 15 min ----
  property real weatherLat: NaN
  property real weatherLon: NaN
  property bool weatherImperial: false
  property string weatherIcon: ""
  property string weatherTemp: ""
  property double weatherFetchedAt: 0

  function refreshWeather() {
    if (!showWeather) return
    if (Date.now() - weatherFetchedAt < 15 * 60 * 1000) return
    if (geoProc.running || weatherProc.running) return
    if (isNaN(weatherLat) || isNaN(weatherLon)) geoProc.running = true
    else fetchWeather()
  }

  function fetchWeather() {
    var units = String(setting("units", ""))
    var imperial = units === "imperial" || (units !== "metric" && weatherImperial)
    weatherProc.command = ["curl", "-fsS", "--max-time", "5", "--max-filesize", "65536",
      "https://api.open-meteo.com/v1/forecast?latitude=" + weatherLat.toFixed(4)
      + "&longitude=" + weatherLon.toFixed(4)
      + "&current=temperature_2m,weather_code,is_day"
      + (imperial ? "&temperature_unit=fahrenheit" : "")]
    weatherProc.running = true
  }

  Process {
    id: geoProc
    command: ["curl", "-fsS", "--max-time", "4", "--max-filesize", "65536", "https://geo.omarchy.org/"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var g = JSON.parse(text)
          var lat = Number(g.latitude), lon = Number(g.longitude)
          if (!isFinite(lat) || !isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) return
          root.weatherLat = lat
          root.weatherLon = lon
          root.weatherImperial = ["US", "LR", "MM"].indexOf(String(g.country || "").toUpperCase()) !== -1
          root.fetchWeather()
        } catch (e) {}
      }
    }
  }

  Process {
    id: weatherProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var c = JSON.parse(text).current
          var t = Number(c.temperature_2m)
          if (!isFinite(t) || Math.abs(t) > 200) return
          root.weatherTemp = Commons.I18n.formatNumber(Math.round(t)) + "°"
          root.weatherIcon = WeatherIcons.iconForOpenMeteoCode(c.weather_code, Number(c.is_day) === 0)
          root.weatherFetchedAt = Date.now()
        } catch (e) {}
      }
    }
  }

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  // Same reasoning as the stock view: a stalled wake can flood the field with
  // key repeats, so only Backspace/Delete may repeat.
  function dropsAutoRepeat(key) {
    return key !== Qt.Key_Backspace && key !== Qt.Key_Delete
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function restorePasswordFocus() {
    if (inputEnabled && passwordInput.enabled && !passwordInput.activeFocus) forcePasswordFocus()
  }

  function replayEntrance() {
    shown = false
    Qt.callLater(function() { root.shown = true })
    refreshWeather()
    fetchArt()
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onVisibleChanged: if (visible) replayEntrance()
  onLoadBackgroundChanged: if (loadBackground) replayEntrance()
  // A wrong password: hide what was typed and shake the card.
  onFailedAttemptsChanged: {
    if (failedAttempts > 0) {
      revealPassword = false
      shake.restart()
    }
  }

  Window.onActiveFocusItemChanged: Qt.callLater(restorePasswordFocus)
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
    replayEntrance()
  }

  Timer {
    interval: 1000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  component Label: Text {
    textFormat: Text.PlainText
    font.family: Style.font.family
    color: root.textColor
  }

  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background

    BackgroundMedia {
      id: wallpaper
      anchors.fill: parent
      path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
      version: root.backgroundVersion
      cached: true
      constrainDecode: true
      decodeSize: Qt.size(width, height)
      visible: false
    }

    // Heavy blur plus a dark wash, so the wallpaper reads as a soft glow.
    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.ready
      blur: 1.0
      blurMax: 64
      blurMultiplier: 2.0
      brightness: -0.18
      saturation: 0.1
    }

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        // Personal: washed in the theme's navy rather than black.
        GradientStop { position: 0.0; color: Util.alpha(Commons.Color.background, 0.40) }
        GradientStop { position: 0.5; color: Util.alpha(Commons.Color.background, 0.20) }
        GradientStop { position: 1.0; color: Util.alpha(Commons.Color.background, 0.60) }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // ---- Status corner: Wi-Fi and battery ----
    Row {
      visible: root.showStatus
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: 28
      spacing: 22
      opacity: root.shown && root.showInput ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Style.duration(300); easing.type: Easing.OutCubic } }

      Row {
        spacing: 8
        Label { text: root.wifiIcon; font.pixelSize: 18; color: root.dimText }
        Label {
          text: root.wifiNetwork ? String(root.wifiNetwork.name || "") : (Networking.wifiEnabled ? strings.t("wifi.none") : strings.t("wifi.off"))
          font.pixelSize: 14
          color: root.dimText
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, 180)
          elide: Text.ElideRight
        }
      }

      Row {
        visible: root.hasBattery
        spacing: 8
        Label {
          text: root.batteryIcon
          font.pixelSize: 18
          color: root.charging ? root.accentLight : (root.batteryLevel <= 15 ? root.errorColor : root.dimText)
        }
        Label {
          text: Commons.I18n.formatNumber(root.batteryLevel) + "%"
          font.pixelSize: 14
          color: root.dimText
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    Column {
      id: content
      anchors.centerIn: parent
      anchors.verticalCenterOffset: root.player ? -10 : -20
      spacing: 0

      // Entrance: fade in and settle from 97% scale.
      opacity: root.shown && root.showInput ? 1 : 0
      scale: root.shown ? 1 : 0.97
      Behavior on opacity { NumberAnimation { duration: Style.duration(260); easing.type: Easing.OutCubic } }
      Behavior on scale {
        NumberAnimation { duration: Style.duration(260); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
      }

      // Clock
      Label {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.locale.toString(root.now, root.clock24 ? "HH:mm" : "h:mm AP")
        font.pixelSize: 104
        // Personal: the bold monospace clock of the old lock (JetBrains Mono).
        font.weight: Font.ExtraBold
        font.letterSpacing: -4
        opacity: 0.94
      }

      // Date, with the weather on the same line once it has loaded.
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Label {
          text: root.locale.toString(root.now, "dddd, d MMMM")
          color: root.dimText
          font.pixelSize: 20
          font.letterSpacing: 1
        }
        Label {
          visible: root.showWeather && root.weatherTemp.length > 0
          text: "·"
          color: root.dimText
          font.pixelSize: 20
        }
        Label {
          visible: root.showWeather && root.weatherTemp.length > 0
          text: root.weatherIcon + "  " + root.weatherTemp
          color: root.accentLight
          font.pixelSize: 20
        }
      }

      Item { width: 1; height: 44 }

      // Glass card
      BorderSurface {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        width: 400
        height: cardColumn.implicitHeight + 56
        radius: 14
        color: root.glass
        borderSpec: root.errorState ? root.errorRimSpec : root.rimSpec

        transform: Translate { id: shakeOffset; x: 0 }

        SequentialAnimation {
          id: shake
          NumberAnimation { target: shakeOffset; property: "x"; to: -14; duration: Style.duration(45); easing.type: Easing.OutCubic }
          NumberAnimation { target: shakeOffset; property: "x"; to: 12; duration: Style.duration(70) }
          NumberAnimation { target: shakeOffset; property: "x"; to: -9; duration: Style.duration(60) }
          NumberAnimation { target: shakeOffset; property: "x"; to: 6; duration: Style.duration(55) }
          NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: Style.duration(50); easing.type: Easing.OutCubic }
        }

        Column {
          id: cardColumn
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: 30
          spacing: 0

          // Round avatar with an accent ring; the initial when there is no image.
          Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 84
            height: 84

            Rectangle {
              anchors.fill: parent
              radius: width / 2
              color: "transparent"
              border.width: 2
              border.color: root.errorState ? root.errorColor : root.accent
              Behavior on border.color { ColorAnimation { duration: Style.duration(150) } }
            }

            Rectangle {
              anchors.fill: parent
              anchors.margins: 4
              radius: width / 2
              visible: avatar.status !== Image.Ready
              color: Util.alpha(root.accent, 0.25)

              Label {
                anchors.centerIn: parent
                text: root.displayName.charAt(0).toUpperCase()
                font.pixelSize: 32
                font.weight: Font.DemiBold
              }
            }

            Image {
              id: avatar
              anchors.fill: parent
              anchors.margins: 4
              source: Util.fileUrl(root.avatarPath)
              sourceSize: Qt.size(256, 256)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
              mipmap: true
              visible: false
            }

            Rectangle {
              id: avatarMask
              anchors.fill: avatar
              radius: width / 2
              visible: false
              layer.enabled: true
            }

            MultiEffect {
              anchors.fill: avatar
              visible: avatar.status === Image.Ready
              source: avatar
              maskEnabled: true
              maskSource: avatarMask
              maskThresholdMin: 0.5
              maskSpreadAtMin: 1.0
            }
          }

          Item { width: 1; height: 16 }

          Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, 340)
            elide: Text.ElideRight
            text: root.greeting
            font.pixelSize: 22
            font.weight: Font.DemiBold
          }

          Item { width: 1; height: 6 }

          Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, 340)
            elide: Text.ElideRight
            text: root.authenticatingPassword
              ? strings.t("checking")
              : (root.errorState ? root.failureMessage : strings.t("prompt"))
            color: root.errorState ? root.errorColor : root.dimText
            font.pixelSize: 13
            font.italic: root.errorState
          }

          Item { width: 1; height: 22 }

          // Password field
          BorderSurface {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 48
            radius: 10
            // Personal: a shade below the theme background (on Tokyo Night the
            // #16161e this used to fix), so the field follows the theme.
            color: Util.alpha(Qt.darker(Commons.Color.background, 1.15), 0.55)
            borderSpec: root.errorState ? root.errorRimSpec
                      : (passwordInput.activeFocus ? root.rimSpec
                         : Border.surfaceSpec("lock", "border", Util.alpha(root.accent, 0.5), 2, "border-alpha"))

            Label {
              id: lockIcon
              anchors.left: parent.left
              anchors.leftMargin: 14
              anchors.verticalCenter: parent.verticalCenter
              text: "󰌾"
              color: root.dimText
              font.pixelSize: 16
            }

            TextInput {
              id: passwordInput
              anchors.left: lockIcon.right
              anchors.leftMargin: 10
              anchors.right: eyeButton.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height
              verticalAlignment: TextInput.AlignVCenter
              horizontalAlignment: TextInput.AlignLeft
              activeFocusOnPress: true
              clip: true
              enabled: root.inputEnabled && !root.authenticatingPassword
              readOnly: root.authenticatingPassword
              echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password
              passwordCharacter: "●"
              passwordMaskDelay: 0
              color: root.textColor
              selectionColor: Util.alpha(root.accent, 0.45)
              selectedTextColor: root.textColor
              font.family: Style.font.family
              font.pixelSize: root.revealPassword ? 16 : 18
              font.letterSpacing: root.revealPassword ? 0 : 3
              cursorVisible: activeFocus && !root.authenticatingPassword
              cursorDelegate: Rectangle {
                width: 2
                color: root.accent
                visible: passwordInput.cursorVisible
              }

              onTextChanged: {
                if (!root.syncingPasswordText) root.passwordTextEdited(text)
                if (text.length > 0) root.wakeRequested()
                if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
                if (text.length === 0) root.revealPassword = false
              }

              onAccepted: {
                var submitted = root.passwordText
                root.passwordTextEdited("")
                if (submitted.length > 0) root.submitPassword(submitted)
              }

              Keys.onReleased: function(event) {
                if (event.key === Qt.Key_CapsLock) root.checkCapsLock()
              }

              Keys.onPressed: function(event) {
                root.wakeRequested()
                if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) {
                  event.accepted = true
                  return
                }
                if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                  root.passwordTextEdited("")
                  event.accepted = true
                } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_E) {
                  root.revealPassword = !root.revealPassword
                  event.accepted = true
                }
              }
            }

            Label {
              anchors.fill: passwordInput
              visible: passwordInput.text.length === 0
              text: strings.t("placeholder")
              color: Util.alpha(root.textColor, 0.35)
              font.pixelSize: 15
              verticalAlignment: Text.AlignVCenter
            }

            // Show/hide the typed password (Ctrl+E does the same).
            Label {
              id: eyeButton
              anchors.right: parent.right
              anchors.rightMargin: 14
              anchors.verticalCenter: parent.verticalCenter
              text: root.fingerprintConfigured
                ? (root.fingerprintUnavailable ? "󰺱" : "󰈷")
                : (root.revealPassword ? "󰈉" : "󰈈")
              color: eyeArea.containsMouse ? root.accentLight : root.dimText
              font.pixelSize: 18

              MouseArea {
                id: eyeArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                enabled: !root.fingerprintConfigured
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.revealPassword = !root.revealPassword
                  root.forcePasswordFocus()
                }
              }
            }
          }

          // ---- Caps Lock warning: takes space only while it is on ----
          Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: root.capsLock ? 28 : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }

            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              text: "󰘲  " + strings.t("capsLock")
              color: root.accent
              font.pixelSize: 13
              opacity: root.capsLock ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: Style.duration(150) } }
            }
          }

          // ---- Mini player ----
          Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: root.player ? 82 : 0
            visible: !!root.player
            clip: true

            Rectangle {
              anchors.fill: parent
              anchors.topMargin: 18
              radius: 10
              color: Util.alpha(root.accent, 0.12)
              border.width: 1
              border.color: Util.alpha(root.textColor, 0.10)

              // Album art when it is allowed, a music note otherwise.
              Rectangle {
                id: art
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 6
                color: Util.alpha(root.accent, 0.25)
                clip: true

                Image {
                  id: artImage
                  anchors.fill: parent
                  source: root.artUrl
                  visible: status === Image.Ready
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  sourceSize: Qt.size(88, 88)
                }
                Label {
                  anchors.centerIn: parent
                  visible: artImage.status !== Image.Ready
                  text: "󰝚"
                  color: root.accentLight
                  font.pixelSize: 20
                }
              }

              Column {
                anchors.left: art.right
                anchors.leftMargin: 12
                anchors.right: controls.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Label {
                  width: parent.width
                  text: root.player ? String(root.player.trackTitle || "") : ""
                  font.pixelSize: 13
                  font.weight: Font.DemiBold
                  elide: Text.ElideRight
                }
                Label {
                  width: parent.width
                  text: root.player ? String(root.player.trackArtist || "") : ""
                  color: root.dimText
                  font.pixelSize: 12
                  elide: Text.ElideRight
                }
              }

              Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                  model: [
                    { icon: "󰒮", action: "previous" },
                    { icon: "playpause", action: "toggle" },
                    { icon: "󰒭", action: "next" }
                  ]

                  delegate: Rectangle {
                    required property var modelData
                    readonly property bool usable: {
                      var p = root.player
                      if (!p) return false
                      if (modelData.action === "previous") return !!p.canGoPrevious
                      if (modelData.action === "next") return !!p.canGoNext
                      return !!(p.canTogglePlaying || p.canPlay || p.canPause)
                    }
                    width: 30
                    height: 30
                    radius: 15
                    color: btnArea.containsMouse && usable ? Util.alpha(root.accent, 0.22) : "transparent"
                    opacity: usable ? 1 : 0.35

                    Label {
                      anchors.centerIn: parent
                      text: parent.modelData.icon === "playpause"
                        ? (root.player && root.player.isPlaying ? "󰏤" : "󰐊")
                        : parent.modelData.icon
                      color: root.accentLight
                      font.pixelSize: parent.modelData.icon === "playpause" ? 18 : 15
                    }

                    MouseArea {
                      id: btnArea
                      anchors.fill: parent
                      hoverEnabled: true
                      enabled: parent.usable
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var p = root.player
                        if (!p) return
                        if (parent.modelData.action === "previous") p.previous()
                        else if (parent.modelData.action === "next") p.next()
                        else p.togglePlaying()
                        root.wakeRequested()
                        root.forcePasswordFocus()
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
  }
}
