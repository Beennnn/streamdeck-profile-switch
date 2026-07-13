// Ghost app (Windows) — Stream Deck profile switcher.
// ------------------------------------------------------------------
// The Windows counterpart of the macOS AppleScript ghost app. When launched it
// becomes the foreground process for a fraction of a second, so Stream Deck —
// which switches to the profile bound to the frontmost application — switches
// to this exe's bound profile, then it exits and focus returns.
//
// The same editor lock applies on Windows: while the Stream Deck config window
// is open it live-previews the edited profile and suppresses switches. So if a
// Stream Deck window is open, we close it first (WM_CLOSE → Stream Deck drops
// to the system tray), then grab the foreground so the app-association fires.
//
// Unlike macOS, none of this needs a special permission grant.

using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

static class Ghost
{
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
    const uint WM_CLOSE = 0x0010;

    static void Main()
    {
        bool editorWasOpen = false;

        // Close the Stream Deck editor window if it's open (the process name has
        // varied across versions, so try both spellings).
        foreach (var name in new[] { "StreamDeck", "Stream Deck" })
        {
            foreach (var p in Process.GetProcessesByName(name))
            {
                if (p.MainWindowHandle != IntPtr.Zero)
                {
                    PostMessage(p.MainWindowHandle, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                    editorWasOpen = true;
                }
            }
        }

        Thread.Sleep(editorWasOpen ? 250 : 100);

        // Grab the foreground so Stream Deck sees THIS exe frontmost and switches
        // to the profile bound to it.
        IntPtr h = GetConsoleWindow();
        if (h != IntPtr.Zero) SetForegroundWindow(h);

        Thread.Sleep(120);
        // exit → focus returns to the previous app
    }
}
