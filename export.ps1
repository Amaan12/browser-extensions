<#
.SYNOPSIS
    Exports installed extensions from any browser (Brave, Chrome, Edge, Vivaldi, Opera) to extensions.json.
.DESCRIPTION
    Scans the local browser profile, extracts all user extensions installed from Chrome Web Store,
    and saves them in extensions.json.
.EXAMPLE
    .\export.ps1
.EXAMPLE
    .\export.ps1 -Browser Chrome
#>

[CmdletBinding()]
param(
    [ValidateSet("Auto", "Brave", "Chrome", "Edge", "Vivaldi", "Opera")]
    [string]$Browser = "Auto",

    [string]$ProfileName = "Default",
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $OutputFile = Join-Path $scriptDir "extensions.json"
}

$browserProfiles = @{
    "Brave"   = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\$ProfileName\Secure Preferences"
    "Chrome"  = "$env:LOCALAPPDATA\Google\Chrome\User Data\$ProfileName\Secure Preferences"
    "Edge"    = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\$ProfileName\Secure Preferences"
    "Vivaldi" = "$env:LOCALAPPDATA\Vivaldi\User Data\$ProfileName\Secure Preferences"
    "Opera"   = "$env:APPDATA\Opera Software\Opera Stable\Secure Preferences"
}

$targetBrowser = $Browser
$targetPrefPath = ""

if ($Browser -eq "Auto") {
    # Scan for the first browser that has an existing profile
    foreach ($b in @("Brave", "Chrome", "Edge", "Vivaldi", "Opera")) {
        $p = $browserProfiles[$b]
        if (Test-Path $p) {
            $targetBrowser = $b
            $targetPrefPath = $p
            Write-Host "Auto-detected browser with active profile: $b" -ForegroundColor Cyan
            break
        }
    }
    if (-not $targetPrefPath) {
        Write-Error "Could not find an active profile for Brave, Chrome, Edge, Vivaldi, or Opera."
    }
} else {
    $targetPrefPath = $browserProfiles[$Browser]
    if (-not (Test-Path $targetPrefPath)) {
        Write-Error "Preferences not found for $Browser at: $targetPrefPath"
    }
}

Write-Host "Reading $targetBrowser profile preferences..." -ForegroundColor Cyan

$json = Get-Content $targetPrefPath -Raw -Encoding UTF8 | ConvertFrom-Json
$extSettings = $json.extensions.settings

if (-not $extSettings) {
    Write-Warning "No extensions found in the profile."
    exit
}

$extensions = @()

foreach ($prop in $extSettings.PSObject.Properties) {
    $val = $prop.Value
    if ($val.from_webstore -eq $true -and $val.manifest.name) {
        $extensions += [PSCustomObject]@{
            id   = $prop.Name
            name = $val.manifest.name
            url  = "https://chromewebstore.google.com/detail/$($prop.Name)"
        }
    }
}

$extensions = $extensions | Sort-Object name

Write-Host "Found $($extensions.Count) extensions in $($targetBrowser):" -ForegroundColor Green
$extensions | ForEach-Object { Write-Host " - $($_.name) ($($_.id))" }

$extensions | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host "`nSuccessfully saved $($extensions.Count) extensions to $OutputFile" -ForegroundColor Green
