#!/usr/bin/env bash
#
# sd-profile.sh — switch Stream Deck to a profile BY NAME, from the CLI.
#
# Works even if the Stream Deck config window is open: it closes the editor
# first (which lifts Stream Deck's "editor preview" lock — see README), then
# launches the ghost app bound to the target profile, which brings itself
# frontmost so Stream Deck switches to it.
#
# Usage:
#   sd-profile.sh "<profile name>"       switch (exact or unique substring)
#   sd-profile.sh --list                 list switchable profiles
#   sd-profile.sh --list all             list every profile
#   sd-profile.sh --no-close-config …    do NOT close the editor first
#
# Name matching: case-insensitive exact first, else substring. An ambiguous
# pattern prints the candidates and switches nothing.
#
# Requires: macOS, the Stream Deck app, and one ghost app per profile you want
# to switch to (build them with make-ghost-app.sh). Closing the editor needs
# Accessibility permission for your terminal (System Settings → Privacy &
# Security → Accessibility).
#
set -euo pipefail

# Editor is closed by default before switching; --no-close-config skips it.
CLOSE_CONFIG=1
if [[ "${1:-}" == "--no-close-config" ]]; then
  CLOSE_CONFIG=0
  shift
fi

# Location Stream Deck actually reads its profiles from (override if needed).
PROFILES_DIR="${SD_PROFILES_DIR:-$HOME/Library/Application Support/com.elgato.StreamDeck/ProfilesV3}"

if [[ ! -d "$PROFILES_DIR" ]]; then
  echo "❌ Profiles folder not found: $PROFILES_DIR" >&2
  echo "   (set SD_PROFILES_DIR if your install differs)" >&2
  exit 1
fi

# Closes the Stream Deck editor window if open (Stream Deck keeps running in
# the menu bar). Non-fatal: if Accessibility isn't granted, we warn and go on.
close_sd_config() {
  # Renvoie "closed" si une fenetre d'editeur ouverte a bien ete fermee, sinon
  # "none" (ou vide si l'Accessibilite manque). On n'attend le delai long QUE
  # si on a vraiment ferme : le verrou de l'editeur n'est relache qu'un instant
  # APRES la fermeture, sinon la bascule ghost qui suit est ignoree (mesure :
  # 0,2 s trop court, ~1,3 s fiable). Cas editeur-ferme (concert) : reste rapide.
  local result
  result="$(/usr/bin/osascript <<'OSA' 2>/dev/null
tell application "System Events"
	if exists (process "Stream Deck") then
		tell process "Stream Deck"
			if (count of windows) > 0 then
				set frontmost to true
				keystroke "w" using command down
				return "closed"
			end if
		end tell
	end if
	return "none"
end tell
OSA
)"
  if [[ -z "$result" ]]; then
    echo "⚠️  Could not talk to the SD editor (Accessibility not granted to your terminal?)." >&2
    echo "    System Settings → Privacy & Security → Accessibility → enable your terminal." >&2
  fi
  if [[ "$result" == "closed" ]]; then
    sleep 1.3   # laisser Stream Deck relacher le verrou avant la bascule
  else
    sleep 0.1
  fi
}

# All JSON parsing + matching happens in Python: profile names can contain
# tabs/spaces, which makes bash field-splitting unsafe. Python writes human
# diagnostics to stderr and, on a successful switch, the ghost-app paths to
# launch on stdout (one per line — a .app path never contains a newline).
run_py() {
  /usr/bin/python3 - "$PROFILES_DIR" "$@" <<'PY'
import json, os, sys, glob

root = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else ""
arg  = sys.argv[3] if len(sys.argv) > 3 else ""

def load():
    rows = []
    for man in glob.glob(os.path.join(root, "*.sdProfile", "manifest.json")):
        try:
            d = json.load(open(man))
        except Exception:
            continue
        name = d.get("Name", "")
        if not name:
            continue
        app = d.get("AppIdentifier", "") or ""
        dev = d.get("Device", {}).get("Model", "")
        rows.append({"name": name, "app": app, "dev": dev})
    return rows

rows = load()

if mode == "--list":
    show_all = (arg == "all")
    for r in sorted(rows, key=lambda r: r["name"].lower()):
        if r["app"]:
            mark = "✅" if os.path.exists(r["app"]) else "⚠️  (linked app missing)"
            print(f"{mark}  {r['name']}", file=sys.stderr)
        elif show_all:
            print(f"⛔ (not switchable)  {r['name']}", file=sys.stderr)
    print("", file=sys.stderr)
    print("✅ = switchable by name   ⛔ = no linked app (--list all to see them)",
          file=sys.stderr)
    sys.exit(0)

# --- switch mode: resolve the name ---
q = arg.strip().lower()
exact = [r for r in rows if r["name"].strip().lower() == q]
subs  = [r for r in rows if q in r["name"].strip().lower()]
chosen = exact if exact else subs

if not chosen:
    print(f'❌ No profile matches: "{arg}"', file=sys.stderr)
    print("   → 'sd-profile.sh --list' to see switchable profiles.", file=sys.stderr)
    sys.exit(1)

switchable = [r for r in chosen if r["app"] and os.path.exists(r["app"])]

if not switchable:
    print("⚠️  Profile found but NOT switchable (no linked ghost app):", file=sys.stderr)
    for r in chosen:
        print(f"   - {r['name']}", file=sys.stderr)
    print("   This tool only switches app-linked profiles (see make-ghost-app.sh).",
          file=sys.stderr)
    sys.exit(4)

distinct = sorted({r["name"] for r in switchable})
if len(distinct) > 1:
    print(f'🤔 Several profiles match "{arg}" — be more specific:', file=sys.stderr)
    for r in switchable:
        print(f"   - {r['name']}   [{r['dev']}]", file=sys.stderr)
    sys.exit(3)

name = distinct[0]
print(f'🎛  Switching → "{name}"', file=sys.stderr)
for r in switchable:
    print(r["app"])
sys.exit(0)
PY
}

# --- list mode ---
if [[ "${1:-}" == "--list" ]]; then
  run_py --list "${2:-}"
  exit 0
fi

query="${1:-}"
if [[ -z "$query" ]]; then
  echo "Usage: $(basename "$0") \"<profile name>\"   |   --list [all]" >&2
  exit 2
fi

# Disable set -e around the capture so a non-zero exit doesn't abort before
# we read the status; command substitution keeps stderr on the terminal.
set +e
apps="$(run_py --switch "$query")"
status=$?
set -e
[[ $status -ne 0 ]] && exit $status

# Lift the editor lock BEFORE switching, otherwise Stream Deck ignores it.
[[ $CLOSE_CONFIG -eq 1 ]] && close_sd_config

# `open -a` brings the ghost app frontmost → Stream Deck switches → it quits.
while IFS= read -r app; do
  [[ -n "$app" ]] && open -a "$app"
done <<<"$apps"
