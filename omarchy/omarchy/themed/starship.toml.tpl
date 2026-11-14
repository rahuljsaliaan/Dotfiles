add_newline = false

# Omarchy theme template for the Starship prompt. omarchy theme set renders it
# into ~/.local/state/omarchy/current/theme/starship.toml with the theme's
# colors.toml values (any key `omarchy-theme-color --all` lists, written in
# double braces), before the theme is swapped in, like the terminal colours.
# ~/.config/starship.toml is a symlink to that file, and Starship rereads it on
# every prompt, so prompts drawn after a switch use the new colours. Edit this
# file, then re-apply the theme (omarchy theme set "$(omarchy theme current)").
#
# Prompt in the plain style of the Claude Code status line
# (~/.claude/statusline.sh), with the folder on one rounded accent pill
# (like the active workspace in the bar) so it is the first thing you see:
#
#   󰉋 omarchy  main !? │  .venv                          󱎫 1s234ms
#   ❯
#
# Everything after the folder is a coloured icon and text on the terminal's
# own background. Segments after git start with their own dim divider, so a
# divider only shows when its segment does. No clock: the top bar has one.

format = """
$directory\
$git_branch$git_status\
$python$nodejs$rust$golang\
$docker_context$kubernetes\
$fill\
$cmd_duration\
$line_break\
$character"""

[fill]
symbol = " "

# ========================
# DIRECTORY (the accent pill)
# ========================
[directory]
style = "fg:{{ background }} bg:{{ accent }} bold"
truncation_length = 2
truncate_to_repo = true
read_only = " 󰌾"
read_only_style = "fg:{{ red }}"
format = "[](fg:{{ accent }})[󰉋 $path]($style)[](fg:{{ accent }})[$read_only]($read_only_style)"

# ========================
# GIT
# ========================
[git_branch]
symbol = " "
style = "fg:{{ bright_foreground }}"
format = " [$symbol](fg:{{ bright_magenta }})[$branch]($style)"

[git_status]
style = "fg:{{ yellow }}"
format = "([ $all_status$ahead_behind]($style))"

# ========================
# LANGUAGES
# ========================
[python]
symbol = " "
style = "fg:{{ bright_foreground }}"
format = "[ │ ](fg:{{ dark_foreground }})[$symbol](fg:{{ green }})[$virtualenv]($style)"
# Only when a virtualenv is active: with no files to detect, the module shows
# solely because $VIRTUAL_ENV is set, and stays hidden otherwise.
detect_extensions = []
detect_files = []
detect_folders = []

[nodejs]
symbol = " "
style = "fg:{{ bright_foreground }}"
format = "[ │ ](fg:{{ dark_foreground }})[$symbol](fg:{{ green }})[$version]($style)"

[rust]
symbol = " "
style = "fg:{{ bright_foreground }}"
format = "[ │ ](fg:{{ dark_foreground }})[$symbol](fg:{{ orange }})[$version]($style)"

[golang]
symbol = " "
style = "fg:{{ bright_foreground }}"
format = "[ │ ](fg:{{ dark_foreground }})[$symbol](fg:{{ bright_cyan }})[$version]($style)"

# ========================
# CONTAINERS
# ========================
[docker_context]
symbol = " "
style = "fg:{{ bright_foreground }}"
format = "[ │ ](fg:{{ dark_foreground }})[$symbol](fg:{{ bright_cyan }})[$context]($style)"
only_with_files = true

[kubernetes]
symbol = "󱃾 "
style = "fg:{{ bright_foreground }}"
format = "[ │ ](fg:{{ dark_foreground }})[$symbol](fg:{{ bright_cyan }})[$context]($style)"

# ========================
# CMD DURATION
# ========================
[cmd_duration]
min_time = 100
show_milliseconds = true
style = "fg:{{ yellow }}"
format = "[󱎫 ](fg:{{ dark_foreground }})[$duration]($style)"

# ========================
# CHARACTER
# ========================
[character]
success_symbol = "[❯](bold fg:{{ accent }})"
error_symbol = "[❯](bold fg:{{ red }})"
