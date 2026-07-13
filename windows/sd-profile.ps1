<#
.SYNOPSIS
  Switch Stream Deck to a profile BY NAME (Windows) — even with the config
  window open.

.DESCRIPTION
  The Windows counterpart of bin/sd-profile.sh. It resolves a profile by name
  from Stream Deck's ProfilesV3 folder, closes the editor window first (which
  lifts Stream Deck's editor-preview lock), then launches the ghost exe bound
  to that profile so Stream Deck switches to it.

.EXAMPLE
  .\sd-profile.ps1 "Live Set"        # exact (case-insensitive) or unique substring
  .\sd-profile.ps1 -List             # list switchable profiles
  .\sd-profile.ps1 -List -All        # list every profile
  .\sd-profile.ps1 "Live Set" -NoCloseConfig

.NOTES
  Requires ghost exes built with make-ghost-app.ps1 and bound in Stream Deck.
  Unlike macOS, no special permission is needed to close the editor window.
#>
param(
    [Parameter(Position = 0)][string]$Query,
    [switch]$List,
    [switch]$All,
    [switch]$NoCloseConfig
)
$ErrorActionPreference = 'Stop'

$profilesDir = if ($env:SD_PROFILES_DIR) { $env:SD_PROFILES_DIR }
               else { "$env:APPDATA\Elgato\StreamDeck\ProfilesV3" }
if (-not (Test-Path $profilesDir)) {
    Write-Error "Profiles folder not found: $profilesDir  (set SD_PROFILES_DIR if your install differs)"
    exit 1
}

function Get-Profiles {
    Get-ChildItem -Path $profilesDir -Filter manifest.json -Recurse -Depth 1 |
        ForEach-Object {
            try { $d = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json } catch { return }
            if (-not $d.Name) { return }
            [pscustomobject]@{
                Name = [string]$d.Name
                App  = [string]$d.AppIdentifier
                Dev  = [string]$d.Device.Model
            }
        }
}

function Close-SDConfig {
    # Close the Stream Deck editor window if open (it drops to the system tray).
    Add-Type -ErrorAction SilentlyContinue -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SdWin {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
}
"@
    foreach ($n in 'StreamDeck', 'Stream Deck') {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.MainWindowHandle -ne [IntPtr]::Zero) {
                [SdWin]::PostMessage($_.MainWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
            }
        }
    }
    Start-Sleep -Milliseconds 200   # let the window close before SD re-evaluates
}

$rows = @(Get-Profiles)

# --- list mode ---
if ($List) {
    foreach ($r in ($rows | Sort-Object { $_.Name.ToLower() })) {
        if ($r.App) {
            $mark = if (Test-Path -LiteralPath $r.App) { "OK " } else { "??  (linked app missing)" }
            Write-Host "$mark  $($r.Name)"
        }
        elseif ($All) {
            Write-Host "--  (not switchable)  $($r.Name)"
        }
    }
    Write-Host ""
    Write-Host "OK = switchable by name   -- = no linked app (-All to see them)"
    return
}

if (-not $Query) {
    Write-Error 'Usage: .\sd-profile.ps1 "<profile name>"   |   -List [-All]'
    exit 2
}

# --- resolve the name: exact (case-insensitive) first, else substring ---
$q = $Query.Trim().ToLower()
$exact = @($rows | Where-Object { $_.Name.Trim().ToLower() -eq $q })
$subs  = @($rows | Where-Object { $_.Name.Trim().ToLower().Contains($q) })
$chosen = if ($exact.Count) { $exact } else { $subs }

if (-not $chosen.Count) {
    Write-Error "No profile matches: `"$Query`"  ->  '.\sd-profile.ps1 -List' to see switchable profiles."
    exit 1
}

$switchable = @($chosen | Where-Object { $_.App -and (Test-Path -LiteralPath $_.App) })
if (-not $switchable.Count) {
    Write-Warning "Profile found but NOT switchable (no linked ghost exe):"
    $chosen | ForEach-Object { Write-Host "   - $($_.Name)" }
    Write-Host "This tool only switches app-linked profiles (see make-ghost-app.ps1)."
    exit 4
}

$distinct = @($switchable | Select-Object -ExpandProperty Name -Unique)
if ($distinct.Count -gt 1) {
    Write-Warning "Several profiles match `"$Query`" — be more specific:"
    $switchable | ForEach-Object { Write-Host "   - $($_.Name)   [$($_.Dev)]" }
    exit 3
}

Write-Host "Switching -> `"$($distinct[0])`""

# Lift the editor lock BEFORE switching, otherwise Stream Deck ignores it.
if (-not $NoCloseConfig) { Close-SDConfig }

# Launching the ghost exe brings it frontmost → Stream Deck switches → it exits.
foreach ($r in $switchable) { Start-Process -FilePath $r.App }
