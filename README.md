# Stream Deck — switch profiles by name, from the command line

Switch your Elgato **Stream Deck** to any profile **by its name**, from a
script or the terminal — **reliably, even when the Stream Deck configuration
window is open**.

```bash
sd-profile.sh "Live Set"
sd-profile.sh "Ableton — Record"
```

No plugin to write, no WebSocket server to keep alive. Just macOS + a tiny
trick Stream Deck already supports: **ghost apps**.

---

## Why this is harder than it should be

Stream Deck has no public "switch to profile X by name" command for scripts.
It exposes profile switching only in two ways, and **both are deliberately
blocked while the Stream Deck configuration window is open**:

- the WebSocket `switchToProfile` API (plugins only), and
- the on-deck *Switch Profile* button action.

That block isn't a bug. **While the editor window is open, it live-previews
the profile you're editing directly on the hardware.** If a background switch
could change the active profile out from under you, the deck would show one
profile while you edit another — so Stream Deck freezes the active profile to
the edited one until you close the window. It's an editing-coherence lock.

## The mechanism: ghost apps + a focus bounce

Stream Deck also supports **app-specific profiles**: bind a profile to an
application, and Stream Deck switches to that profile whenever the app becomes
frontmost. A **ghost app** abuses this: it's a near-empty AppleScript applet
whose only job is to become frontmost for ~0.1 s and quit.

- Launch `SD_switch - Live Set.app` → it becomes frontmost → Stream Deck sees
  the frontmost app change and switches to the bound profile → the app quits
  and focus returns to whatever you were doing.
- This is the **only** approach that survives the editor lock, because the very
  thing it does — *change which app is frontmost* — is also what's needed to
  release the lock. If the editor window is open, the ghost app **closes it
  first** (`Cmd-W`; Stream Deck stays alive in the menu bar), then re-takes
  focus so the app-association fires now that the lock is lifted.

```
launch ghost app
   │
   ├─ editor window open?  ──yes──▶ close it (Cmd-W) ─▶ re-take focus
   │                                                        │
   └──────────────────────────no───────────────────────────┤
                                                            ▼
                          Stream Deck sees ghost app frontmost
                                     ▼
                          switches to the bound profile
                                     ▼
                              ghost app quits
```

---

## Requirements

- macOS
- The Elgato **Stream Deck** app (tested on 7.5)
- One **ghost app per profile** you want to switch to (built below)
- **Accessibility permission** for whatever closes the editor window
  (your terminal, and/or the ghost apps) — see below

## Install

```bash
git clone https://github.com/Beennnn/streamdeck-profile-switch.git
cd streamdeck-profile-switch
chmod +x bin/*.sh
# optional: put bin/ on your PATH, or symlink sd-profile.sh somewhere handy
```

## Create a ghost app for a profile

Two steps: **build the app**, then **bind it** in Stream Deck (one time).

### 1. Build

```bash
bin/make-ghost-app.sh "Live Set"
```

This creates `SD_switch - Live Set.app` in Stream Deck's `ProfileApps`
folder. (It's a normal AppleScript applet — you can also build it by hand:
open **Script Editor**, paste [`ghost-app/main.applescript`](ghost-app/main.applescript),
and *Export…* as an Application.)

### 2. Bind it in Stream Deck

1. Select the target profile in the Stream Deck app.
2. Open the profile's settings (the **•••** / gear next to the profile name).
3. Choose **set as profile for an application**, and pick the ghost app you
   just built.

Stream Deck records the app's path in the profile's `AppIdentifier`. That's
the link `sd-profile.sh` reads to know which app to launch for a given name.

## Switch by name

```bash
sd-profile.sh "Live Set"          # exact (case-insensitive) or unique substring
sd-profile.sh --list              # list switchable profiles
sd-profile.sh --list all          # list every profile (incl. non-switchable)
sd-profile.sh --no-close-config … # don't touch the editor window
```

Ambiguous names print the candidates and switch nothing. Profiles without a
linked ghost app are reported as not switchable.

## Accessibility permission (one time)

Closing the editor window uses macOS **System Events**, which requires
**Accessibility** permission for the app that sends it:

**System Settings → Privacy & Security → Accessibility** → enable your
terminal (for `sd-profile.sh`) and allow the ghost apps at first launch.

**First launch** of a ghost app also pops a one-time **Automation** consent
("… wants to control System Events") — allow it. All ghost apps built by
`make-ghost-app.sh` share one bundle identifier
(`com.streamdeck-profile-switch.ghostapp`), so you grant Automation and
Accessibility **once** and every ghost app inherits it.

Without these permissions, everything still runs — the editor just won't be
closed automatically, so switching only works when the editor is already
closed (the classic ghost-app behaviour). The scripts never hang once the
one-time consent has been answered.

---

## Files

| Path | What it is |
|---|---|
| [`bin/sd-profile.sh`](bin/sd-profile.sh) | CLI: switch a profile by name; closes the editor first |
| [`bin/make-ghost-app.sh`](bin/make-ghost-app.sh) | Build a `SD_switch - <name>.app` ghost app |
| [`ghost-app/main.applescript`](ghost-app/main.applescript) | The applet source (close editor → bounce focus → quit) |

## License

MIT — see [LICENSE](LICENSE).
