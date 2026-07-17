#!/usr/bin/env bash
#
# make-signal-app.sh — build a "signal app" for one profile.
#
# A signal app is a tiny background app whose only job, when launched, is to
# write ONE profile name to the daemon's FIFO. It needs NO permission (it just
# writes a file), so it can be launched by anything a Stream Deck button can
# reach:
#   • the built-in "Open Application" action  (no plugin needed)
#   • the trevligaspel MIDI plugin's  {launch:"…SD-sig - <name>.app"}
#   • an OSAScript  do shell script
#   • the shell / a script / another app
#
# The daemon (sd-switch-daemon.sh) then does the privileged part: close the
# Stream Deck editor window (needs Accessibility) and switch the profile.
#
# Why one app PER profile instead of one app that takes the name as an argument?
# Because the built-in "Open Application" action does NOT forward its Arguments
# field to the launched app (verified) — so the profile name has to be baked in.
# Generating them is cheap (this script), and they need no signing, no
# permission, and no Stream Deck binding.
#
# Usage:
#   make-signal-app.sh "<profile name>"            # → ~/Applications/SD-sig - <name>.app
#   make-signal-app.sh "<profile name>" "<dir>"    # custom directory
#
set -euo pipefail

name="${1:-}"
if [[ -z "$name" ]]; then
  echo "Usage: $(basename "$0") \"<profile name>\" [target dir]" >&2
  exit 2
fi

target_dir="${2:-$HOME/Applications}"
fifo="${SD_SWITCH_FIFO:-/tmp/sd-switch}"
app="$target_dir/SD-sig - ${name}.app"

mkdir -p "$app/Contents/MacOS"

slug="$(printf '%s' "$name" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>sig</string>
  <key>CFBundleIdentifier</key><string>com.streamdeck-profile-switch.sig.${slug}</string>
  <key>CFBundleName</key><string>SD-sig - ${name}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSBackgroundOnly</key><true/>
</dict></plist>
EOF

# The executable writes the (baked-in) profile name to the FIFO. The write is
# backgrounded with a 2 s watchdog so it never hangs forever if the daemon
# isn't running.
cat > "$app/Contents/MacOS/sig" <<EOF
#!/bin/bash
( printf '%s\n' "${name}" > "${fifo}" ) &
w=\$!; ( sleep 2; kill \$w 2>/dev/null ) 2>/dev/null & wait \$w 2>/dev/null
EOF
chmod +x "$app/Contents/MacOS/sig"
/usr/bin/codesign --force --sign - "$app" >/dev/null 2>&1 || true

echo "✅ Signal app: $app"
echo "   Bind a button to LAUNCH it — e.g. the built-in \"Open Application\" action,"
echo "   or the trevligaspel plugin's  {launch:\"$app\"} ."
echo "   Make sure sd-switch-daemon.sh is running (it does the editor-close + switch)."
