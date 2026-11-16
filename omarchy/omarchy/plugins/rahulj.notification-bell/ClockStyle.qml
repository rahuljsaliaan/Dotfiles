import QtQuick
import Quickshell
import Quickshell.Io

// Follows the top bar clock's 12/24-hour choice, so changing it there changes
// it everywhere that prints a time. The bar clock (omarchy.clock) keeps its
// format string in shell.json; a format with an AM/PM token (AP, ap, A, a) is
// 12-hour, any other format with an hour is 24-hour. Quoted literals such as
// 'W' are ignored. A format with no hour at all (the date-only alternate)
// leaves `fallback24` in charge.
//
// Keep the copies of this file in the plugins that use it identical.
Item {
  id: root

  property bool fallback24: true

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
  property string clockFormat: ""

  readonly property string bare: String(clockFormat).replace(/'[^']*'/g, "")
  readonly property bool hasHour: /[Hh]/.test(bare)
  readonly property bool hour24: hasHour ? !/[Aa]/.test(bare) : fallback24

  // "14:30" or "2:30 PM".
  readonly property string timeFormat: hour24 ? "HH:mm" : "h:mm AP"

  function findClock(node) {
    if (!node || typeof node !== "object") return null
    if (Array.isArray(node)) {
      for (var i = 0; i < node.length; i++) {
        var hit = findClock(node[i])
        if (hit) return hit
      }
      return null
    }
    if (node.id === "omarchy.clock") return node
    for (var key in node) {
      var found = findClock(node[key])
      if (found) return found
    }
    return null
  }

  function parse() {
    var text = ""
    try { text = String(file.text()) } catch (e) { text = "" }
    if (text.length === 0) return
    try {
      var cfg = JSON.parse(text)
      var entry = findClock(cfg.bar && cfg.bar.layout ? cfg.bar.layout : cfg)
      if (!entry) { root.clockFormat = ""; return }
      var vertical = cfg.bar && (cfg.bar.position === "left" || cfg.bar.position === "right")
      var fmt = vertical ? entry.verticalFormat : entry.format
      // Fall back to the other orientation's format when this one is unset.
      if (fmt === undefined || fmt === null) fmt = vertical ? entry.format : entry.verticalFormat
      root.clockFormat = fmt === undefined || fmt === null ? "" : String(fmt)
    } catch (e) {
      // A half-written file keeps the last good value.
    }
  }

  FileView {
    id: file
    path: root.configPath
    watchChanges: true
    printErrors: false
    blockLoading: true
    onFileChanged: reload()
    onLoaded: root.parse()
  }

  Component.onCompleted: parse()
}
