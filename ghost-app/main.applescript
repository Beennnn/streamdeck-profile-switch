-- Ghost app — Stream Deck profile switcher
-- ------------------------------------------------------------------
-- A "ghost app" is a tiny AppleScript applet whose only job is to become the
-- frontmost application for a fraction of a second. Stream Deck watches which
-- app is frontmost and switches to the profile bound to it (the profile's
-- "AppIdentifier"), so bringing this app forward triggers a profile switch —
-- then it quits and focus returns to whatever you were on.
--
-- This applet does NOT try to close the Stream Deck config window itself.
-- Closing it requires Accessibility permission, and ad-hoc-signed AppleScript
-- applets do not get a working Accessibility grant on current macOS: the entry
-- appears enabled in System Settings, yet System Events calls still fail with
-- -25211 (see the "Investigations & findings" section of the README). So the
-- editor is closed by `sd-profile.sh` instead — run from your terminal, which
-- is a properly signed app and CAN hold Accessibility. Launched on its own, a
-- ghost app therefore switches only when the editor window is already closed.
--
-- The `delay` is deliberate: 0.1 s was too short — Stream Deck sometimes missed
-- the frontmost-app change and didn't switch. 0.45 s reliably latches it.

tell me to activate
delay 0.45
tell me to quit
