// Personal reminder panel (rahulj.reminders): one line, typed the way you'd
// say it, read into whole minutes for omarchy-reminder.
//
//   30m Check the oven       45 Stretch          1h30 Stand-up
//   at 15:30 Call mom        at 9am Pay rent     Tea in 10 min
//
// A time goes first ("30m …", "at 15:30 …"), or last after "in"/"at"
// ("… in 10 min", "… at 6pm"). A bare number is minutes. A clock time that has
// already passed today means tomorrow.

var UNITS = { h: 60, hr: 60, hrs: 60, hour: 60, hours: 60, m: 1, min: 1, mins: 1, minute: 1, minutes: 1 }

function durationMinutes(text) {
  var s = String(text || "").trim().toLowerCase().replace(/^in\s+/, "")
  if (!s) return 0
  if (/^\d+$/.test(s)) return Number(s)
  // 1h30 / 1h30m
  var hm = s.match(/^(\d+)\s*h(?:ours?|rs?)?\s*(\d+)\s*(?:m(?:in(?:ute)?s?)?)?$/)
  if (hm) return Number(hm[1]) * 60 + Number(hm[2])
  var total = 0, rest = s, part
  var re = /^(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m)\s*/
  while (rest && (part = rest.match(re))) {
    total += Number(part[1]) * UNITS[part[2]]
    rest = rest.slice(part[0].length).replace(/^(and|,)\s*/, "")
  }
  return rest ? 0 : Math.round(total)
}

function clockMinutes(text, now) {
  var m = String(text || "").trim().toLowerCase().replace(/^at\s+/, "")
    .match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$/)
  if (!m) return 0
  var hour = Number(m[1]), minute = Number(m[2] || 0), half = m[3]
  if (!half && !m[2]) return 0 // "at 5" could mean anything; ask for 5pm or 5:00
  if (minute > 59 || hour > (half ? 12 : 23) || (half && hour === 0)) return 0
  if (half === "pm" && hour < 12) hour += 12
  if (half === "am" && hour === 12) hour = 0
  var target = new Date(now.getTime())
  target.setHours(hour, minute, 0, 0)
  if (target.getTime() <= now.getTime()) target.setDate(target.getDate() + 1)
  return Math.max(1, Math.ceil((target.getTime() - now.getTime()) / 60000))
}

var LEAD_TIME = /^(at\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?|\d{1,2}:\d{2}\s*(?:am|pm)?|\d{1,2}\s*(?:am|pm)|in\s+(?:[\d.]+\s*(?:hours?|hrs?|h|minutes?|mins?|m)\s*)+|in\s+\d+|\d+\s*h\s*\d+\s*m?|(?:[\d.]+\s*(?:hours?|hrs?|h|minutes?|mins?|m)\s*)+|\d+)(?=\s|$)/i
var TRAIL_TIME = /\s+(in\s+(?:[\d.]+\s*(?:hours?|hrs?|h|minutes?|mins?|m)\s*)+|in\s+\d+|at\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?)$/i

// parse("30m Check the oven", now) → { minutes: 30, message: "Check the oven" }
// minutes is 0 when no time could be read.
function parse(text, now) {
  var s = String(text || "").trim()
  now = now || new Date()
  var lead = s.match(LEAD_TIME)
  if (lead) {
    var t = lead[0].trim()
    var mins = /^at\s|:|am|pm/i.test(t) ? clockMinutes(t, now) : durationMinutes(t)
    if (mins > 0) return { minutes: mins, message: s.slice(lead[0].length).trim() }
  }
  var trail = s.match(TRAIL_TIME)
  if (trail) {
    var tt = trail[1].trim()
    var m2 = /^at\s/i.test(tt) ? clockMinutes(tt, now) : durationMinutes(tt)
    if (m2 > 0) return { minutes: m2, message: s.slice(0, s.length - trail[0].length).trim() }
  }
  return { minutes: 0, message: s }
}

// "1 h 30 min" style for the preview.
function describeMinutes(minutes) {
  var h = Math.floor(minutes / 60), m = minutes % 60
  if (h && m) return h + " h " + m + " min"
  if (h) return h + (h === 1 ? " hour" : " hours")
  return m + " min"
}

// Clock time the reminder fires: "17:58", or "tomorrow 09:00".
function describeAt(minutes, now) {
  now = now || new Date()
  var at = new Date(now.getTime() + minutes * 60000)
  var hh = ("0" + at.getHours()).slice(-2), mm = ("0" + at.getMinutes()).slice(-2)
  var tomorrow = at.getDate() !== now.getDate()
  return (tomorrow ? "tomorrow " : "") + hh + ":" + mm
}

// Put a chip's time at the start of the text, keeping the message.
function withLeadTime(text, time) {
  var s = String(text || "").trim()
  var parsed = parse(s, new Date())
  var message = parsed.minutes > 0 ? parsed.message : s
  return time + " " + message
}

function validMinutes(value) {
  var minutes = String(value || "").trim()
  return /^[0-9]+$/.test(minutes) && Number(minutes) > 0 ? minutes : ""
}

function reminderArgs(minutes, message) {
  var valid = validMinutes(minutes)
  if (!valid) return []
  var args = [valid]
  var text = String(message || "")
  if (text.length > 0) args.push(text)
  return args
}

if (typeof module !== "undefined") {
  module.exports = { parse: parse, durationMinutes: durationMinutes, clockMinutes: clockMinutes,
                     describeMinutes: describeMinutes, describeAt: describeAt, withLeadTime: withLeadTime,
                     validMinutes: validMinutes, reminderArgs: reminderArgs }
}
