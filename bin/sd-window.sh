#!/usr/bin/env bash
#
# sd-window.sh — hide / show / toggle the Stream Deck CONFIGURATION window.
#
# Companion to the profile switcher: sometimes you just want to get the editor
# out of the way (or bring it back) without switching profiles.
#
#   hide    close the config window   (Stream Deck stays in the menu bar)
#   show    open  the config window
#   toggle  close it if open, open it if closed
#
# `hide` and `toggle` need Accessibility (they read/close the window), so run
# this from the daemon or a terminal that has it. `show` needs nothing.
#
# Usage:  sd-window.sh hide | show | toggle
#
set -uo pipefail

SD_APP="Elgato Stream Deck"

wcount() {
  /usr/bin/osascript <<'OSA' 2>/dev/null
tell application "System Events"
	if exists (process "Stream Deck") then
		tell process "Stream Deck" to return (count of windows)
	end if
	return 0
end tell
OSA
}

close_win() {
  /usr/bin/osascript <<'OSA' >/dev/null 2>&1
tell application "System Events"
	if exists (process "Stream Deck") then
		tell process "Stream Deck"
			if (count of windows) > 0 then
				set frontmost to true
				keystroke "w" using command down
			end if
		end tell
	end if
end tell
OSA
}

open_win() { /usr/bin/open -a "$SD_APP"; }

case "${1:-toggle}" in
  hide|masquer|close)  close_win ;;
  show|afficher|open)  open_win ;;
  toggle|bascule)      n="$(wcount)"; if [ "${n:-0}" -gt 0 ] 2>/dev/null; then close_win; else open_win; fi ;;
  *) echo "usage: $(basename "$0") hide|show|toggle" >&2; exit 2 ;;
esac
