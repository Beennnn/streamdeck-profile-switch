#!/usr/bin/env python3
"""
sd-switch-midi.py — switch Stream Deck profiles from a MIDI message.

Same idea as sd-switch-daemon.sh, but the trigger is MIDI instead of a FIFO.
Any MIDI source (a controller, a pedal, Ableton, Bome MIDI Translator, a
trevligaspel button…) can switch a profile — and, crucially, a MIDI message
from a NON-Stream-Deck source fires **even while the Stream Deck config window
is open** (the SD editor only captures presses on the deck itself, not MIDI
from other devices).

How it works:
  • opens a MIDI input port (a virtual "SD Profile Switch" port by default, so
    you can route to it from Bome/your DAW; or an existing port with --port),
  • on a mapped note-on (or CC), runs `sd-profile.sh "<profile name>"`, which
    closes the editor window then switches.

Because it calls sd-profile.sh, the editor-close still needs Accessibility —
so run this daemon from a terminal you've granted Accessibility (it inherits
that terminal's grant; see the README).

Mapping: a JSON file next to this script, `sd-midi-map.json`:
  {
    "virtual": true,
    "port": "SD Profile Switch",
    "channel": null,                 // null = any channel, or 1..16
    "notes": { "60": "Songs", "62": "FNK - Chameleon" },
    "cc":    { }                     // optional: "20": "Live Set"  (on value>0)
  }

Requires: mido + python-rtmidi  (pip install mido python-rtmidi)
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SD_PROFILE = os.path.join(HERE, "sd-profile.sh")
# Your real mapping lives in sd-midi-map.json (git-ignored — keep your own
# profile names private). Falls back to the committed example.
MAP_PATH = os.path.join(HERE, "sd-midi-map.json")
if not os.path.exists(MAP_PATH):
    MAP_PATH = os.path.join(HERE, "sd-midi-map.example.json")

DEFAULT_MAP = {
    "virtual": True,
    "port": "SD Profile Switch",
    "channel": None,
    "notes": {},
    "cc": {},
}


def load_map():
    cfg = dict(DEFAULT_MAP)
    if os.path.exists(MAP_PATH):
        try:
            cfg.update(json.load(open(MAP_PATH)))
        except Exception as e:
            print(f"⚠️  {MAP_PATH} illisible ({e}) — mapping vide.", file=sys.stderr)
    # allow --port to override
    if "--port" in sys.argv:
        i = sys.argv.index("--port")
        cfg["port"] = sys.argv[i + 1]
        cfg["virtual"] = False
    return cfg


def switch(name):
    print(f"→ switch: {name}", flush=True)
    try:
        subprocess.run([SD_PROFILE, name], check=True)
        print("   ✅ ok", flush=True)
    except subprocess.CalledProcessError as e:
        print(f"   ⚠️  échec ({name}) rc={e.returncode}", flush=True)


def main():
    try:
        import mido
    except ImportError:
        print("❌ mido introuvable. Installe : pip install mido python-rtmidi", file=sys.stderr)
        sys.exit(1)

    if not os.access(SD_PROFILE, os.X_OK):
        print(f"❌ Introuvable / non exécutable : {SD_PROFILE}", file=sys.stderr)
        sys.exit(1)

    cfg = load_map()
    notes = {int(k): v for k, v in cfg.get("notes", {}).items()}
    ccs = {int(k): v for k, v in cfg.get("cc", {}).items()}
    ch = cfg.get("channel")

    port_name = cfg["port"]
    if cfg.get("virtual", True):
        inport = mido.open_input(port_name, virtual=True)
        kind = "port virtuel (route ton MIDI vers lui)"
    else:
        inport = mido.open_input(port_name)
        kind = "port existant"

    print(f"🎹 sd-switch-midi : j'écoute « {inport.name} » — {kind}")
    print(f"   notes: { {k: v for k, v in notes.items()} }")
    if ccs:
        print(f"   cc:    { {k: v for k, v in ccs.items()} }")
    print("   Ctrl-C pour arrêter.")

    for msg in inport:
        if ch is not None and getattr(msg, "channel", None) is not None and (msg.channel + 1) != ch:
            continue
        if msg.type == "note_on" and msg.velocity > 0 and msg.note in notes:
            switch(notes[msg.note])
        elif msg.type == "control_change" and msg.value > 0 and msg.control in ccs:
            switch(ccs[msg.control])


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n👋 arrêt.")
