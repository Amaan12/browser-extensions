<#
.SYNOPSIS
    Exports installed extensions from Brave (or other Chromium browsers) to extensions.json.
.DESCRIPTION
    Scans the local browser profile's Secure Preferences, extracts all Web Store extensions,
    and saves them in extensions.json so they can be version-controlled in Git.
.EXAMPLE
    .\export.ps1
#>

[CmdletBinding()]
param(
    [string]$ProfileName = "Default",
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $OutputFile = Join-Path $scriptDir "extensions.json"
}

$prefPath = Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data\$ProfileName\Secure Preferences"

if (-not (Test-Path $prefPath)) {
    Write-Error "Brave profile preferences not found at: $prefPath"
}

Write-Host "Reading Brave profile ($ProfileName)..." -ForegroundColor Cyan

$json = Get-Content $prefPath -Raw -Encoding UTF8 | ConvertFrom-Json
$extSettings = $json.extensions.settings

if (-not $extSettings) {
    Write-Warning "No extensions found in the profile."
    exit
}

$extensions = @()

foreach ($prop in $extSettings.PSObject.Properties) {
    $val = $prop.Value
    # Filter for extensions installed from Chrome Web Store (excludes built-in components)
    if ($val.from_webstore -eq $true -and $val.manifest.name) {
        $extensions += [PSCustomObject]@{
            id   = $prop.Name
            name = $val.manifest.name
            url  = "https://chromewebstore.google.com/detail/$($prop.Name)"
        }
    }
}

# Sort alphabetically by name
$extensions = $extensions | Sort-Object name

Write-Host "Found $($extensions.Count) user extensions:" -ForegroundColor Green
$extensions | ForEach-Object { Write-Host " - $($_.name) ($($_.id))" }

$extensions | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host "`nSuccessfully exported to $OutputFile" -ForegroundColor Green
