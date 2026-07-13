# Windows port

> ⚠️ **Untested / experimental.** This is the Windows counterpart of the macOS
> scripts, ported by mirroring the same design. It has **not yet been run on a
> real Windows + Stream Deck setup**. Treat it as a starting point; feedback and
> fixes welcome.

Same idea as the macOS version, adapted to Windows — and actually simpler,
because Windows needs **no special permission** to close a window or bring an
app to the foreground (there's no macOS-style Accessibility/Automation grant).

| macOS | Windows |
|---|---|
| Ghost app = `.app` AppleScript applet | Ghost app = a small `.exe` (compiled from `ghost-app/ghost.cs`) |
| Close editor via `Cmd-W` (System Events) | Close editor via `WM_CLOSE` (→ system tray) |
| `bin/sd-profile.sh` | `windows/sd-profile.ps1` |
| `bin/make-ghost-app.sh` | `windows/make-ghost-app.ps1` |
| Needs Accessibility/Automation | **No permission needed** |

## How it works

Stream Deck on Windows switches to the profile bound to the **frontmost
application** (the profile's `AppIdentifier`, an exe path). A ghost exe just
becomes frontmost for a moment so that switch fires, then exits. And because the
editor window suppresses switches while open, the first step is always to close
it (`WM_CLOSE` drops Stream Deck to the tray); then the switch goes through.

## Requirements

- Windows 10/11, the Elgato **Stream Deck** app
- Windows PowerShell 5+ (built in) — the `.exe` builder uses the bundled .NET
  compiler, so there's **no external toolchain** to install
- One ghost exe per profile you want to switch to

## Build a ghost app

```powershell
cd windows
.\make-ghost-app.ps1 -Name "Live Set"
```

Creates `SD_switch - Live Set.exe` in Stream Deck's `ProfileApps` folder. Then
bind it: in Stream Deck, open the target profile's settings → set it as the
profile for an application → choose the exe.

## Switch by name

```powershell
.\sd-profile.ps1 "Live Set"        # exact (case-insensitive) or unique substring
.\sd-profile.ps1 -List             # switchable profiles
.\sd-profile.ps1 -List -All        # every profile
.\sd-profile.ps1 "Live Set" -NoCloseConfig
```

If PowerShell blocks the scripts, allow them for the current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
