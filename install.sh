#!/usr/bin/env bash
#
# install.sh — set up streamdeck-profile-switch to run permanently (no terminal
# window to keep open, survives logout/reboot).
#
# What it does:
#   1. makes the scripts executable;
#   2. installs a LaunchAgent so the FIFO daemon starts at login and stays up;
#   3. opens the Accessibility pane and tells you exactly what to enable
#      (the ONE manual step — a macOS security boundary that can't be scripted).
#
# It does NOT generate the per-profile apps — do that with:
#   bin/gen-apps.sh            # ghost + signal apps for every switchable profile
#   bin/make-ghost-app.sh  "<name>"   /   bin/make-signal-app.sh "<name>"
#
# Uninstall:  ./install.sh --uninstall
#
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
BIN="$REPO/bin"
LABEL="com.streamdeck-profile-switch.daemon"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DAEMON="$BIN/sd-switch-daemon.sh"

if [[ "${1:-}" == "--uninstall" ]]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "✅ Uninstalled the LaunchAgent (scripts and apps left in place)."
  exit 0
fi

[[ -f "$DAEMON" ]] || { echo "❌ Not found: $DAEMON" >&2; exit 1; }
chmod +x "$BIN"/*.sh "$BIN"/*.py 2>/dev/null || true

echo "▸ Installing LaunchAgent → $PLIST"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$DAEMON</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/sd-switch-daemon.log</string>
  <key>StandardErrorPath</key><string>/tmp/sd-switch-daemon.log</string>
</dict></plist>
EOF

# (re)load it
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
sleep 1
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  echo "✅ Daemon loaded (starts at login, auto-restarts). Log: /tmp/sd-switch-daemon.log"
else
  echo "⚠️  Could not confirm the LaunchAgent loaded — check: launchctl print gui/$(id -u)/$LABEL"
fi

cat <<'MSG'

────────────────────────────────────────────────────────────────────────────
ONE manual step — grant Accessibility (macOS security, can't be automated):

  System Settings → Privacy & Security → Accessibility

  Enable the process that RUNS the daemon so it can close the editor window.
  The Accessibility pane is opening now. See the README ("Setup") for exactly
  which entry to add for a LaunchAgent-hosted daemon on your macOS version.

Then build a signal app for a profile and wire a button to launch it:
  bin/make-signal-app.sh "Live Set"
  → button: built-in "Open Application" action, or trevligaspel {launch}.
────────────────────────────────────────────────────────────────────────────
MSG
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
