<#
.SYNOPSIS
  Build a Windows Stream Deck "ghost app" (SD_switch - <name>.exe) for one profile.

.DESCRIPTION
  Compiles ghost-app/ghost.cs into an executable using the .NET compiler that
  ships with Windows (via Add-Type) — no external toolchain required. The exe,
  when launched, becomes frontmost so Stream Deck switches to the profile you
  bind to it, closing the editor window first if it's open.

.EXAMPLE
  .\make-ghost-app.ps1 -Name "Live Set"
  .\make-ghost-app.ps1 -Name "Live Set" -TargetDir "D:\SDGhosts"

.NOTES
  After building, bind it in Stream Deck (one time):
    1. Select the target profile in the Stream Deck app.
    2. Open the profile's settings.
    3. Set it as the profile for an application, and choose this exe.
  Stream Deck records the exe path in the profile's AppIdentifier.
#>
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$TargetDir = "$env:APPDATA\Elgato\StreamDeck\ProfileApps"
)
$ErrorActionPreference = 'Stop'

$src = Join-Path $PSScriptRoot 'ghost-app\ghost.cs'
if (-not (Test-Path $src)) { throw "Source not found: $src" }

if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir | Out-Null }
$exe = Join-Path $TargetDir "SD_switch - $Name.exe"
if (Test-Path $exe) { throw "Already exists: $exe  (delete it first to rebuild)" }

# Add-Type compiles the C# source to a console exe with the bundled csc.
Add-Type -TypeDefinition (Get-Content -Raw $src) `
         -OutputType ConsoleApplication `
         -OutputAssembly $exe

Write-Host "OK  ->  $exe"
Write-Host ""
Write-Host "Next (in Stream Deck): open the target profile's settings, set it as the"
Write-Host "profile for an application, and choose this exe. Then:"
Write-Host "  Start-Process `"$exe`"   switches to that profile."
