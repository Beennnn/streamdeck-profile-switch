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

## Roadmap (v0.2 — self-contained)

Drop the external daemon: switch via this plugin's own WebSocket
`switchToProfile` API **after** a **bundled, signed helper** closes the editor
(the only piece that needs Accessibility). Install that helper at a documented
path (e.g. `~/Library/Application Support/DeckShift/`) so the **trevligaspel MIDI
plugin can still call it** with `{launch:"…/DeckShift/…app"}` — MIDI stays a
first-class trigger next to the native action.

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
