<#
.SYNOPSIS
    Universal Browser Extension Auto-Installer for Windows (Brave, Chrome, Edge, Vivaldi, Opera, Arc).
.DESCRIPTION
    Reads extensions from extensions.json (locally or fetched from GitHub) and automatically
    configures extension policies so all detected browsers silently download and install them.

    Works locally or via one-liner:
    irm https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/install.ps1 | iex
.EXAMPLE
    .\install.ps1
.EXAMPLE
    .\install.ps1 -Browser Brave
.EXAMPLE
    .\install.ps1 -OpenTabs
#>

[CmdletBinding()]
param(
    # "All", "Brave", "Chrome", "Edge", "Vivaldi", "Opera"
    [string]$Browser = "All",

    # Path to local JSON file or remote URL
    [string]$Source = "",

    # Open extension store pages in browser tabs instead of setting policies
    [switch]$OpenTabs
)

$ErrorActionPreference = "Stop"

# Configuration: Supported browsers & their registry policy paths
$SupportedBrowsers = @{
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
    # 1. Check Windows registered App Paths
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
    # 2. Check fallback standard paths
    foreach ($p in $config.FallbackPaths) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

# --- 1. Load Extension List ---
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
        Write-Host "Local extensions.json not found (running in remote memory mode)." -ForegroundColor Yellow
        $user = Read-Host "Enter your GitHub username (or full raw URL to extensions.json)"
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

Write-Host "`nExtensions to install ($($extensions.Count)):" -ForegroundColor Green
$extensions | ForEach-Object { Write-Host " - $($_.name) ($($_.id))" }
Write-Host ""

# --- 2. Detect Installed Browsers on this PC ---
Write-Host "Scanning PC for installed browsers..." -ForegroundColor Cyan
$detectedBrowsers = @{}

foreach ($key in $SupportedBrowsers.Keys) {
    $cfg = $SupportedBrowsers[$key]
    $exe = Find-BrowserExe $cfg
    if ($exe) {
        $detectedBrowsers[$key] = @{
            Config = $cfg
            Exe    = $exe
        }
        Write-Host " [x] Detected $($cfg.Name) at $exe" -ForegroundColor Green
    }
}

if ($detectedBrowsers.Count -eq 0) {
    Write-Warning "No supported Chromium browsers detected on this PC."
}

# Determine target browsers
$targets = @()
if ($Browser -eq "All") {
    $targets = $detectedBrowsers.Keys
} else {
    if ($SupportedBrowsers.ContainsKey($Browser)) {
        $targets = @($Browser)
    } else {
        Write-Error "Unsupported browser: $Browser. Supported: $($SupportedBrowsers.Keys -join ', ')"
    }
}

# --- 3. Execute Installation ---
if ($OpenTabs) {
    foreach ($b in $targets) {
        $exe = if ($detectedBrowsers.ContainsKey($b)) { $detectedBrowsers[$b].Exe } else { Find-BrowserExe $SupportedBrowsers[$b] }
        if ($exe) {
            Write-Host "Opening $($extensions.Count) tabs in $b..." -ForegroundColor Cyan
            $urls = $extensions | ForEach-Object { $_.url }
            Start-Process -FilePath $exe -ArgumentList $urls
        } else {
            Write-Warning "Cannot open tabs: $b executable not found."
        }
    }
    Write-Host "`nTabs opened! Click 'Add to browser' on each page." -ForegroundColor Green
    return
}

# Automated Force-Install Policy Mode
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$hives = if ($isAdmin) { @("HKLM", "HKCU") } else { @("HKCU") }
$updateUrl = "https://clients2.google.com/service/update2/crx"

foreach ($b in $targets) {
    $cfg = $SupportedBrowsers[$b]
    Write-Host "`nConfiguring auto-install policy for $($cfg.Name)..." -ForegroundColor Cyan

    foreach ($hive in $hives) {
        $regPath = "$hive`:\$($cfg.PolicyPath)"
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
    Write-Host " [x] Successfully configured $($cfg.Name)" -ForegroundColor Green
}

Write-Host "`n[SUCCESS] Completed! All extensions are set to auto-install." -ForegroundColor Green
Write-Host "They will automatically download and activate when you launch the browser(s)." -ForegroundColor Yellow

if (-not $isAdmin) {
    Write-Host "Note: Applied to Current User (HKCU). For system-wide policies, run as Administrator." -ForegroundColor DarkGray
}
