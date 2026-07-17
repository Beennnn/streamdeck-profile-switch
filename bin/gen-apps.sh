#!/usr/bin/env bash
#
# gen-apps.sh — generate a ghost app AND a signal app for every switchable
# Stream Deck profile (i.e. every profile already linked to a ghost app via its
# AppIdentifier). Idempotent: safe to re-run.
#
#   ghost app  = the switch target (Stream Deck jumps to it — jordikt's trick)
#   signal app = what a button launches to tell the daemon which profile to pick
#
# Usage:
#   gen-apps.sh                 # ghost + signal for every switchable profile
#   gen-apps.sh --signals-only  # only signal apps (if your ghosts already exist)
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROFILES_DIR="${SD_PROFILES_DIR:-$HOME/Library/Application Support/com.elgato.StreamDeck/ProfilesV3}"
signals_only=0
[[ "${1:-}" == "--signals-only" ]] && signals_only=1

[[ -d "$PROFILES_DIR" ]] || { echo "❌ Profiles folder not found: $PROFILES_DIR" >&2; exit 1; }

# list distinct switchable profile names (those with an AppIdentifier)
names="$(/usr/bin/python3 - "$PROFILES_DIR" <<'PY'
import json, glob, os, sys
root = sys.argv[1]
seen = set()
for man in glob.glob(os.path.join(root, "*.sdProfile", "manifest.json")):
    try: d = json.load(open(man))
    except Exception: continue
    name, app = d.get("Name", ""), d.get("AppIdentifier", "")
    if name and app and name not in seen:
        seen.add(name); print(name)
PY
)"

[[ -z "$names" ]] && { echo "No switchable profiles found (none linked to a ghost app)."; exit 0; }

n=0
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  [[ $signals_only -eq 0 ]] && "$HERE/make-ghost-app.sh"  "$name" >/dev/null 2>&1 || true
  "$HERE/make-signal-app.sh" "$name" >/dev/null 2>&1 || true
  n=$((n+1))
  printf '  · %s\n' "$name"
done <<< "$names"

echo "✅ Generated apps for $n profile(s)."
[[ $signals_only -eq 0 ]] && echo "   (Remember: each ghost app must be linked to its profile in the Stream Deck app.)"
