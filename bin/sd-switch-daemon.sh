#!/usr/bin/env bash
#
# sd-switch-daemon.sh — watch a FIFO for profile names and switch to each.
#
# Why a daemon? A Stream Deck button can't close the editor window itself:
# doing so needs Accessibility permission, and the ad-hoc apps a button can
# launch don't get a working one (see the README's "Investigations &
# findings"). The fix is to DECOUPLE:
#
#   • the button only *signals* — it writes a profile name to this FIFO
#     (`echo "Live Set" > /tmp/sd-switch`). Writing a file needs NO permission,
#     so any plugin (even ad-hoc) can do it.
#   • this daemon runs in a context that HOLDS Accessibility — launch it from a
#     terminal you've granted Accessibility (System Settings → Privacy &
#     Security → Accessibility). It reads the FIFO and runs `sd-profile.sh`,
#     which closes the editor (needs Accessibility) then switches.
#
# The daemon inherits the terminal's (robust, properly-signed) Accessibility,
# which is why it succeeds where a stand-alone signed applet failed.
#
# Usage:
#   sd-switch-daemon.sh [fifo-path]      # default: /tmp/sd-switch
#
# Then, from anywhere (a Stream Deck button, a script, the shell):
#   echo "Live Set" > /tmp/sd-switch
#
set -uo pipefail

FIFO="${1:-/tmp/sd-switch}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SD_PROFILE="$HERE/sd-profile.sh"
SD_WINDOW="$HERE/sd-window.sh"

if [[ ! -x "$SD_PROFILE" ]]; then
  echo "❌ Introuvable ou non exécutable : $SD_PROFILE" >&2
  exit 1
fi

# (Re)create the FIFO. If a stale non-FIFO file is there, replace it.
if [[ ! -p "$FIFO" ]]; then
  rm -f "$FIFO"
  mkfifo "$FIFO" || { echo "❌ mkfifo a échoué : $FIFO" >&2; exit 1; }
fi

echo "🎛  sd-switch-daemon : j'écoute $FIFO"
echo "    (déclenche avec :  echo \"<nom du profil>\" > $FIFO )"
echo "    Ctrl-C pour arrêter."

# Read one line per writer. `read < fifo` blocks until a writer appears, returns
# the line, then EOF when the writer closes — so we loop to re-open the FIFO.
while true; do
  if IFS= read -r name < "$FIFO"; then
    [[ -z "${name// }" ]] && continue
    case "$name" in
      # reserved words control the editor window instead of switching a profile
      hide|masquer|show|afficher|toggle|bascule)
        echo "→ $(date '+%H:%M:%S')  window: $name"
        "$SD_WINDOW" "$name" && echo "   ✅ ok" || echo "   ⚠️  échec ($name)"
        ;;
      *)
        echo "→ $(date '+%H:%M:%S')  switch: $name"
        if "$SD_PROFILE" "$name"; then
          echo "   ✅ ok"
        else
          echo "   ⚠️  échec ($name)"
        fi
        ;;
    esac
  fi
done
