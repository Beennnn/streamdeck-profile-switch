# DeckShift — Stream Deck plugin (scaffold, v0.1)

The native-plugin front-end for DeckShift. **Status: scaffold** — the structure,
manifest, actions, plugin logic and Property Inspector are here; it still needs
icons, a build/package pass, and testing on a real deck before it ships.

## What it does

Four actions (configured in the Stream Deck UI, **no per-profile apps**):

| Action | UUID | On press |
|---|---|---|
| **Switch Profile** | `com.deckshift.switch` | switch to the profile name set in the PI |
| **Hide Editor** | `com.deckshift.hide` | close the config window |
| **Show Editor** | `com.deckshift.show` | open the config window |
| **Toggle Editor** | `com.deckshift.toggle` | toggle the config window |

## How this version works (v0.1)

Thin front-end over the **DeckShift daemon**: each press writes a command to the
FIFO (`/tmp/sd-switch`); the daemon (which holds Accessibility) closes the editor
and switches. So this reuses everything from the scripts side — **the daemon must
be running** (`../install.sh`), and `/bin/bash` must have Accessibility.

The win vs the scripts: the **target profile lives in the action's settings**, so
there are no ghost/signal apps to generate per profile.

## Roadmap (v0.2 — bundle the close helper)

Goal: drop the external daemon. Two things to know first (see the main README):

- **The ghost apps stay.** `switchToProfile` is restricted by Elgato to profiles
  the *plugin* bundles — it **can't switch a user's own profiles** — so the plugin
  still launches per-profile ghost apps to switch. It only removes the *signal*
  apps.
- **Closing the editor still needs Accessibility.** So "self-contained" = the
  plugin ships the editor-close capability instead of relying on the daemon:
  1. **cheapest, untested:** grant Accessibility to **`Elgato Stream Deck.app`**
     and close the editor from the plugin's own `osascript` (if macOS attributes
     it to the Developer-ID-signed SD app, keystrokes post). Also the natural
     **request to Elgato** — an official close-editor / user-profile-switch
     capability would retire these hacks.
  2. a **bundled signed helper** (Swift/ObjC, Developer-ID) — real dev + signing.

Install the helper at a documented path (e.g.
`~/Library/Application Support/DeckShift/`) so the **trevligaspel MIDI plugin can
still call it** with `{launch:"…/DeckShift/…app"}` — MIDI stays first-class next
to the native action.

## Build & install (dev)

```bash
cd com.deckshift.sdPlugin
npm install                          # fetches ws into the bundle

# sideload: symlink the bundle into Stream Deck's plugin folder, then restart SD
ln -s "$PWD" \
  "$HOME/Library/Application Support/com.elgato.StreamDeck/Plugins/com.deckshift.sdPlugin"
```

To distribute: package with Elgato's `streamdeck` CLI
(`streamdeck pack com.deckshift.sdPlugin`) → a `.streamDeckPlugin` users install
by double-click (GitHub release). Marketplace submission is optional/separate.

## TODO before shipping

- [ ] Icons (`icons/plugin`, `icons/switch`, `icons/hide`, `icons/show`, `icons/toggle`, `icons/category`) — PNG @1x/@2x.
- [ ] Validate the manifest against the current Stream Deck SDK (`SDKVersion`, `Nodejs` runtime) — see https://docs.elgato.com/streamdeck/sdk/.
- [ ] Test all 4 actions on a real deck (editor open + closed).
- [ ] v0.2: bundled signed helper + `switchToProfile`; drop the FIFO/daemon dependency.
- [ ] Sign the packaged plugin (Developer ID) to avoid the Gatekeeper prompt.
