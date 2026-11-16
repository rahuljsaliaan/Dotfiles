-- Popups that stay in front.
--
-- Hyprland draws every floating window above every tiled one, whatever has
-- focus. A window that opens tiled underneath a floating one is hidden behind
-- it, and focusing it does not bring it forward.

-- File pickers. Apps that use the portal get their Open/Save dialogs from
-- Files (Nautilus). Omarchy floats those only when the app titles the dialog
-- Open…, Save… or Choose…; Obsidian's folder picker is titled "Location", so on
-- a tiled or scrolling workspace it opened tiled, behind Obsidian's floating
-- vault window. A picker is titled before it opens, with the title the app
-- asked for; Files' own windows open untitled and only then become "Loading…"
-- (a folder already loaded, Recent and Trash too). So a Files window that
-- opens with any other title is a dialog: it floats, centred, at the size
-- Omarchy gives dialogs. ("Loading…" is the English text; under another
-- language it is translated, and this needs the translation.)
o.window({
  class = "^org\\.gnome\\.Nautilus$",
  initial_title = "negative:^(Loading…)?$",
}, { tag = "+floating-window" })
