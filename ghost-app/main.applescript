-- Ghost app — Stream Deck profile switcher
-- ------------------------------------------------------------------
-- A "ghost app" is a tiny, invisible AppleScript applet whose only job is
-- to become the frontmost application for a fraction of a second. Stream
-- Deck watches which app is frontmost and switches to the profile bound to
-- it (the profile's "AppIdentifier"), so bringing this app forward triggers
-- a profile switch — then it quits and focus returns to whatever you were on.
--
-- The catch: while the Stream Deck CONFIG WINDOW is open, it live-previews
-- the edited profile on the hardware and SUPPRESSES every profile switch
-- (app-association *and* the WebSocket API). So if the editor is open we
-- first close its window (Cmd-W — Stream Deck keeps running in the menu bar),
-- then re-take focus so Stream Deck replays the app-association now that the
-- lock is lifted.
--
-- The whole System Events block is wrapped in `try` so the applet ALWAYS
-- reaches `quit`, even if Accessibility permission hasn't been granted yet
-- (in that case it just can't close the editor, and behaves like the classic
-- ghost app — which only works when the editor is already closed).

set editorWasOpen to false
try
	tell application "System Events"
		if exists (process "Stream Deck") then
			tell process "Stream Deck"
				if (count of windows) > 0 then
					set editorWasOpen to true
					set frontmost to true
					keystroke "w" using command down
				end if
			end tell
		end if
	end tell
end try

if editorWasOpen then
	delay 0.2
	tell me to activate
	delay 0.15
else
	delay 0.1
end if

tell me to quit
