#!/usr/bin/env node
"use strict";
//
// DeckShift — Stream Deck plugin (v0.1 scaffold)
// ---------------------------------------------------------------------------
// This first version is a thin FRONT-END over the DeckShift daemon: each action
// press writes a command to the daemon's FIFO (/tmp/sd-switch), and the daemon
// (which holds Accessibility) closes the editor + switches. That means:
//   • no per-profile "ghost"/"signal" apps — the target profile lives in the
//     action's settings and is written to the FIFO on press;
//   • it reuses the daemon + the one Accessibility grant you already set up.
//
// ROADMAP (v0.2+, self-contained): drop the external daemon by (a) switching via
// this plugin's own WebSocket `switchToProfile` API *after* (b) a bundled, signed
// helper closes the editor. Until then, the daemon must be running (install.sh).
//
// Stream Deck launches this with: -port N -pluginUUID U -registerEvent E -info J
//
const { execFile } = require("node:child_process");

const args = process.argv.slice(2);
const opt = {};
for (let i = 0; i < args.length; i += 2) {
  if (args[i] && args[i].startsWith("-")) opt[args[i].slice(1)] = args[i + 1];
}

const FIFO = process.env.SD_SWITCH_FIFO || "/tmp/sd-switch";

// Write one command to the daemon's FIFO. Non-blocking with a 2 s watchdog so a
// missing daemon never wedges the plugin.
function signal(cmd) {
  if (!cmd) return;
  execFile(
    "/bin/sh",
    ["-c", `printf '%s\\n' "$1" > ` + JSON.stringify(FIFO), "_", cmd],
    { timeout: 2000 },
    () => {}
  );
}

let WebSocketImpl = globalThis.WebSocket;
try { if (!WebSocketImpl) WebSocketImpl = require("ws"); } catch (_) {}
if (!WebSocketImpl) { console.error("No WebSocket available (npm i ws)"); process.exit(1); }

const ws = new WebSocketImpl("ws://127.0.0.1:" + opt.port);

const onOpen = () => ws.send(JSON.stringify({ event: opt.registerEvent, uuid: opt.pluginUUID }));
const onMessage = (raw) => {
  let msg;
  try { msg = JSON.parse(typeof raw === "string" ? raw : raw.data ?? raw); } catch { return; }
  if (msg.event !== "keyDown") return;
  const action = String(msg.action || "");
  const settings = (msg.payload && msg.payload.settings) || {};
  if (action.endsWith(".switch")) signal(String(settings.profileName || "").trim());
  else if (action.endsWith(".hide")) signal("hide");
  else if (action.endsWith(".show")) signal("show");
  else if (action.endsWith(".toggle")) signal("toggle");
};

// support both the WHATWG (global WebSocket) and the `ws` (EventEmitter) styles
if (typeof ws.on === "function") { ws.on("open", onOpen); ws.on("message", onMessage); }
else { ws.addEventListener("open", onOpen); ws.addEventListener("message", (e) => onMessage(e.data)); }
