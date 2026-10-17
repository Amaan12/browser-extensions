<#
.SYNOPSIS
    Installs extensions into a specified browser (Brave, Chrome, Edge, Vivaldi, Opera).
.DESCRIPTION
    Reads extensions from extensions.json and configures the selected browser's
    ExtensionInstallForcelist policy so the browser automatically installs them.

    Can be specified via -Browser parameter, or chosen from an interactive prompt.
.EXAMPLE
    .\install.ps1 -Browser Brave
.EXAMPLE
    .\install.ps1 -Browser Chrome
.EXAMPLE
    .\install.ps1 (interactively prompts which browser to use)
#>

[CmdletBinding()]
param(
    [ValidateSet("Brave", "Chrome", "Edge", "Vivaldi", "Opera", "")]
    [string]$Browser = "",

    # Path to local JSON file or remote URL
    [string]$Source = "",

    # Open extension store pages in browser tabs instead of setting policies
    [switch]$OpenTabs
)

$ErrorActionPreference = "Stop"

# Configuration: Supported browsers & registry policy paths
$SupportedBrowsers = [ordered]@{
    "Brave"   = @{
        Name       = "Brave"
        AppId      = "brave.exe"
        PolicyPath = "Software\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
        FallbackPaths = @(
            "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
            "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
            "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"
        )
    }
    "Chrome"  = @{
        Name       = "Google Chrome"
        AppId      = "chrome.exe"
        PolicyPath = "Software\Policies\Google\Chrome\ExtensionInstallForcelist"
        FallbackPaths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        )
    }
    "Edge"    = @{
        Name       = "Microsoft Edge"
        AppId      = "msedge.exe"
        PolicyPath = "Software\Policies\Microsoft\Edge\ExtensionInstallForcelist"
        FallbackPaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        )
    }
    "Vivaldi" = @{
        Name       = "Vivaldi"
        AppId      = "vivaldi.exe"
        PolicyPath = "Software\Policies\Vivaldi\ExtensionInstallForcelist"
        FallbackPaths = @(
            "$env:LOCALAPPDATA\Vivaldi\Application\vivaldi.exe",
            "$env:ProgramFiles\Vivaldi\Application\vivaldi.exe"
        )
    }
    "Opera"   = @{
        Name       = "Opera"
        AppId      = "launcher.exe"
        PolicyPath = "Software\Policies\Opera Software\ExtensionInstallForcelist"
        FallbackPaths = @(
            "$env:LOCALAPPDATA\Programs\Opera\launcher.exe",
            "$env:ProgramFiles\Opera\launcher.exe"
        )
    }
}

function Find-BrowserExe($config) {
    $regPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\$($config.AppId)",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\$($config.AppId)"
    )
    foreach ($rp in $regPaths) {
        if (Test-Path $rp) {
            $val = (Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue).'(Default)'
            if ($val -and (Test-Path $val)) { return $val }
        }
    }
    foreach ($p in $config.FallbackPaths) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

# --- 1. Detect Installed Browsers on this PC ---
$detected = @()
foreach ($key in $SupportedBrowsers.Keys) {
    $cfg = $SupportedBrowsers[$key]
    $exe = Find-BrowserExe $cfg
    if ($exe) {
        $detected += [PSCustomObject]@{
            Key    = $key
            Name   = $cfg.Name
            Exe    = $exe
            Config = $cfg
        }
    }
}

# --- 2. Resolve Single Target Browser ---
$target = $null

if (-not [string]::IsNullOrWhiteSpace($Browser)) {
    # Browser specified via parameter
    $cfg = $SupportedBrowsers[$Browser]
    $exe = Find-BrowserExe $cfg
    $target = [PSCustomObject]@{
        Key    = $Browser
        Name   = $cfg.Name
        Exe    = $exe
        Config = $cfg
    }
} else {
    # Interactive selection
    if ($detected.Count -eq 0) {
        Write-Error "No supported Chromium browser found on this PC."
    }

    Write-Host "`nChoose which browser to install extensions into:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $detected.Count; $i++) {
        Write-Host "  [$($i + 1)] $($detected[$i].Name)"
    }
    $choice = Read-Host "`nEnter selection [1-$($detected.Count)] (default: 1)"
    $idx = 0
    if (-not [string]::IsNullOrWhiteSpace($choice)) {
        $idx = [int]$choice - 1
    }
    if ($idx -lt 0 -or $idx -ge $detected.Count) {
        Write-Error "Invalid selection."
    }
    $target = $detected[$idx]
}

Write-Host "`nTarget Browser: $($target.Name)" -ForegroundColor Green

# --- 3. Load Extension List ---
$extensions = @()

if (-not [string]::IsNullOrWhiteSpace($Source)) {
    if ($Source -match '^https?://') {
        Write-Host "Fetching extensions from remote URL: $Source" -ForegroundColor Cyan
        $extensions = Invoke-RestMethod -Uri $Source
    } else {
        $extensions = Get-Content $Source -Raw -Encoding UTF8 | ConvertFrom-Json
    }
} else {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $localJson = Join-Path $scriptDir "extensions.json"

    if (Test-Path $localJson) {
        Write-Host "Loading extensions from local file: $localJson" -ForegroundColor Cyan
        $extensions = Get-Content $localJson -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        Write-Host "Local extensions.json not found." -ForegroundColor Yellow
        $user = Read-Host "Enter your GitHub username (or raw URL to extensions.json)"
        if ($user -match '^https?://') {
            $extensions = Invoke-RestMethod -Uri $user
        } else {
            $repo = Read-Host "Enter repository name [default: browser-extensions-sync]"
            if ([string]::IsNullOrWhiteSpace($repo)) { $repo = "browser-extensions-sync" }
            $rawUrl = "https://raw.githubusercontent.com/$user/$repo/main/extensions.json"
            Write-Host "Fetching: $rawUrl" -ForegroundColor Cyan
            $extensions = Invoke-RestMethod -Uri $rawUrl
        }
    }
}

if (-not $extensions -or $extensions.Count -eq 0) {
    Write-Error "No extensions found in list."
}

Write-Host "Loaded $($extensions.Count) extensions to install." -ForegroundColor Green

# --- 4. Install Mode: Open Tabs vs Policy Install ---
if ($OpenTabs) {
    if (-not $target.Exe) {
        Write-Error "$($target.Name) executable could not be found."
    }
    Write-Host "Opening $($extensions.Count) tabs in $($target.Name)..." -ForegroundColor Cyan
    $urls = $extensions | ForEach-Object { $_.url }
    Start-Process -FilePath $target.Exe -ArgumentList $urls
    Write-Host "Tabs opened! Click 'Add to $($target.Name)' on each tab." -ForegroundColor Green
    return
}

# Policy Mode: Configure ExtensionInstallForcelist for the chosen browser only
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$hives = if ($isAdmin) { @("HKLM", "HKCU") } else { @("HKCU") }
$updateUrl = "https://clients2.google.com/service/update2/crx"

Write-Host "Configuring auto-install policy for $($target.Name)..." -ForegroundColor Cyan

foreach ($hive in $hives) {
    $regPath = "$hive`:\$($target.Config.PolicyPath)"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    $i = 1
    foreach ($ext in $extensions) {
        $val = "$($ext.id);$updateUrl"
        New-ItemProperty -Path $regPath -Name "$i" -Value $val -PropertyType String -Force | Out-Null
        $i++
    }
}

Write-Host "`n[SUCCESS] Successfully configured $($extensions.Count) extensions for $($target.Name)!" -ForegroundColor Green
Write-Host "When you open $($target.Name), the extensions will automatically download and activate." -ForegroundColor Yellow
