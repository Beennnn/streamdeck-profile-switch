#!/usr/bin/env bash
#
# make-ghost-app.sh — build a Stream Deck "ghost app" for one profile.
#
# Creates `SD_switch - <name>.app`, a tiny AppleScript applet that, when
# launched, momentarily becomes frontmost so Stream Deck switches to the
# profile you bind to it — closing the editor window first if it's open
# (see ghost-app/main.applescript for the full rationale).
#
# Usage:
#   make-ghost-app.sh "<name>"                 # → ProfileApps/SD_switch - <name>.app
#   make-ghost-app.sh "<name>" "<target dir>"  # → custom directory
#
# After building, bind it in Stream Deck (one time):
#   1. Select the target profile in the Stream Deck app.
#   2. Open the profile's settings (the "•••" / gear next to its name).
#   3. Set it as the profile for an application → choose this ghost app.
#      Stream Deck writes the app's path into the profile's AppIdentifier.
#
set -euo pipefail

name="${1:-}"
if [[ -z "$name" ]]; then
  echo "Usage: $(basename "$0") \"<profile name>\" [target dir]" >&2
  exit 2
fi

# Default target = the folder Stream Deck uses for app-linked profiles.
default_dir="$HOME/Library/Application Support/com.elgato.StreamDeck/ProfileApps"
target_dir="${2:-$default_dir}"

src_dir="$(cd "$(dirname "$0")/.." && pwd)"
applescript="$src_dir/ghost-app/main.applescript"
if [[ ! -f "$applescript" ]]; then
  echo "❌ Introuvable : $applescript" >&2
  exit 1
fi

mkdir -p "$target_dir"
app_path="$target_dir/SD_switch - ${name}.app"

if [[ -e "$app_path" ]]; then
  echo "⚠️  Existe déjà : $app_path"
  echo "    Supprime-le d'abord si tu veux le régénérer."
  exit 1
fi

# osacompile -o <foo.app> produit un applet complet (bundle .app) à partir
# de la source AppleScript. C'est l'outil standard pour CRÉER une ghost app.
osacompile -o "$app_path" "$applescript"

# osacompile ne pose AUCUN bundle identifier. macOS indexe alors les
# permissions (Automation pour piloter System Events, Accessibilité pour
# fermer la fenêtre) par identité d'app — sans ID partagé, CHAQUE ghost app
# redemanderait l'autorisation. On force donc un ID commun : toutes les ghost
# apps créées par ce script partagent une seule autorisation → tu accordes une
# fois, ça couvre toutes les suivantes.
GHOST_BUNDLE_ID="com.streamdeck-profile-switch.ghostapp"
/usr/bin/defaults write "$app_path/Contents/Info.plist" CFBundleIdentifier "$GHOST_BUNDLE_ID"
# Re-signe ad-hoc pour lier l'ID à la signature (sinon macOS ignore parfois
# l'Info.plist modifié). `-` = signature ad-hoc locale, sans certificat.
/usr/bin/codesign --force --sign - "$app_path" >/dev/null 2>&1 || true

echo "✅ Ghost app créée :"
echo "   $app_path"
echo
echo "➡️  Dernière étape (dans Stream Deck) : ouvre le profil cible, règle-le"
echo "   comme profil d'une application, et choisis cette ghost app."
echo "   Ensuite : open -a \"$app_path\"  bascule sur ce profil."
