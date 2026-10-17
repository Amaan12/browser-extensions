<#
.SYNOPSIS
    Smart additive extension installer for Brave, Chrome, Edge, Vivaldi, Opera.
.DESCRIPTION
    Compares extensions.json with the extensions ALREADY installed in your browser.
    - If an extension is already present, it is SKIPPED.
    - Only MISSING extensions are installed.
    - Never deletes or touches any of your existing extensions or browser data.
.EXAMPLE
    .\install.ps1 -Browser Brave
.EXAMPLE
    .\install.ps1 -Browser Chrome
.EXAMPLE
    .\install.ps1 -Browser Brave -OpenTabs
#>

[CmdletBinding()]
param(
    [ValidateSet("Brave", "Chrome", "Edge", "Vivaldi", "Opera", "")]
    [string]$Browser = "",

    # Path to local JSON file or remote URL
    [string]$Source = "",

    # Only open store pages in tabs for the missing extensions
    [switch]$OpenTabs
)

$ErrorActionPreference = "Stop"

$SupportedBrowsers = [ordered]@{
    "Brave"   = @{
        Name        = "Brave"
        AppId       = "brave.exe"
        PolicyPath  = "Software\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
        ProfilePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
        FallbackExe = @(
            "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
            "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
            "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"
        )
    }
    "Chrome"  = @{
        Name        = "Google Chrome"
        AppId       = "chrome.exe"
        PolicyPath  = "Software\Policies\Google\Chrome\ExtensionInstallForcelist"
        ProfilePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
        FallbackExe = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        )
    }
    "Edge"    = @{
        Name        = "Microsoft Edge"
        AppId       = "msedge.exe"
        PolicyPath  = "Software\Policies\Microsoft\Edge\ExtensionInstallForcelist"
        ProfilePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
        FallbackExe = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        )
    }
    "Vivaldi" = @{
        Name        = "Vivaldi"
        AppId       = "vivaldi.exe"
        PolicyPath  = "Software\Policies\Vivaldi\ExtensionInstallForcelist"
        ProfilePath = "$env:LOCALAPPDATA\Vivaldi\User Data\Default"
        FallbackExe = @(
            "$env:LOCALAPPDATA\Vivaldi\Application\vivaldi.exe",
            "$env:ProgramFiles\Vivaldi\Application\vivaldi.exe"
        )
    }
    "Opera"   = @{
        Name        = "Opera"
        AppId       = "launcher.exe"
        PolicyPath  = "Software\Policies\Opera Software\ExtensionInstallForcelist"
        ProfilePath = "$env:APPDATA\Opera Software\Opera Stable"
        FallbackExe = @(
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
    foreach ($p in $config.FallbackExe) {
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
    if (-not $SupportedBrowsers.Contains($Browser)) {
        Write-Error "Unsupported browser '$Browser'. Supported: $($SupportedBrowsers.Keys -join ', ')"
    }
    $cfg = $SupportedBrowsers[$Browser]
    $exe = Find-BrowserExe $cfg
    $target = [PSCustomObject]@{
        Key    = $Browser
        Name   = $cfg.Name
        Exe    = $exe
        Config = $cfg
    }
} else {
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

# --- 3. Load Extension List from JSON ---
$extensions = @()

if (-not [string]::IsNullOrWhiteSpace($Source)) {
    if ($Source -match '^https?://') {
        Write-Host "Fetching extensions from: $Source" -ForegroundColor Cyan
        $extensions = Invoke-RestMethod -Uri $Source
    } else {
        $extensions = Get-Content $Source -Raw -Encoding UTF8 | ConvertFrom-Json
    }
} else {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $localJson = Join-Path $scriptDir "extensions.json"

    if (Test-Path $localJson) {
        Write-Host "Loading list from: $localJson" -ForegroundColor Cyan
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

# --- 4. Smart Check: Find what is ALREADY installed in the target browser ---
$installedIds = @()

# Check Secure Preferences or Preferences file
$prefFiles = @(
    (Join-Path $target.Config.ProfilePath "Secure Preferences"),
    (Join-Path $target.Config.ProfilePath "Preferences")
)
foreach ($pf in $prefFiles) {
    if (Test-Path $pf) {
        try {
            $json = Get-Content $pf -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($json.extensions -and $json.extensions.settings) {
                $installedIds += @($json.extensions.settings.PSObject.Properties.Name)
            }
        } catch { }
    }
}

# Also check Extensions directory on disk
$extDir = Join-Path $target.Config.ProfilePath "Extensions"
if (Test-Path $extDir) {
    $dirs = Get-ChildItem -Path $extDir -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    if ($dirs) { $installedIds += $dirs }
}

$installedIds = $installedIds | Select-Object -Unique

# Separate already-installed vs missing
$missing = @()
$alreadyPresent = @()

foreach ($ext in $extensions) {
    if ($installedIds -contains $ext.id) {
        $alreadyPresent += $ext
    } else {
        $missing += $ext
    }
}

# Display status
if ($alreadyPresent.Count -gt 0) {
    Write-Host "`n[SKIPPED] Already installed in $($target.Name) ($($alreadyPresent.Count)):" -ForegroundColor DarkGray
    $alreadyPresent | ForEach-Object { Write-Host "  - $($_.name)" -ForegroundColor DarkGray }
}

if ($missing.Count -eq 0) {
    Write-Host "`n[ALL SET] All $($extensions.Count) extensions are already installed in $($target.Name)!" -ForegroundColor Green
    Write-Host "Nothing needs to be installed." -ForegroundColor Green
    return
}

Write-Host "`n[TO INSTALL] Missing extensions ($($missing.Count)):" -ForegroundColor Cyan
$missing | ForEach-Object { Write-Host "  + $($_.name) ($($_.id))" -ForegroundColor Green }
Write-Host ""

# --- 5. Install ONLY the Missing Extensions ---
if ($OpenTabs) {
    if (-not $target.Exe) {
        Write-Error "$($target.Name) executable could not be found."
    }
    Write-Host "Opening $($missing.Count) missing store tabs in $($target.Name)..." -ForegroundColor Cyan
    $urls = $missing | ForEach-Object { $_.url }
    Start-Process -FilePath $target.Exe -ArgumentList $urls
    Write-Host "Tabs opened! Just click 'Add to $($target.Name)' on each tab." -ForegroundColor Green
    return
}

# Policy Mode: Add missing extensions to registry list
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$hives = if ($isAdmin) { @("HKLM", "HKCU") } else { @("HKCU") }
$updateUrl = "https://clients2.google.com/service/update2/crx"

foreach ($hive in $hives) {
    $regPath = "$hive`:\$($target.Config.PolicyPath)"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    # Find the next available index in the registry key
    $existingProps = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).PSObject.Properties |
                     Where-Object { $_.Name -match '^\d+$' } |
                     Select-Object -ExpandProperty Name
    
    $maxIndex = 0
    foreach ($p in $existingProps) {
        $val = [int]$p
        if ($val -gt $maxIndex) { $maxIndex = $val }
    }

    # Only append the missing ones
    foreach ($ext in $missing) {
        $maxIndex++
        $entryVal = "$($ext.id);$updateUrl"
        New-ItemProperty -Path $regPath -Name "$maxIndex" -Value $entryVal -PropertyType String -Force | Out-Null
    }
}

# For Google Chrome on non-domain Windows machines, also register via External Extensions
if ($target.Key -eq "Chrome") {
    foreach ($ext in $missing) {
        $extKeyPath = "HKCU:\Software\Google\Chrome\Extensions\$($ext.id)"
        if (-not (Test-Path $extKeyPath)) {
            New-Item -Path $extKeyPath -Force | Out-Null
        }
        Set-ItemProperty -Path $extKeyPath -Name "update_url" -Value $updateUrl -Force | Out-Null
    }
}

Write-Host "[SUCCESS] Added $($missing.Count) missing extensions to $($target.Name)!" -ForegroundColor Green
Write-Host "When you launch $($target.Name), the missing extensions will automatically download." -ForegroundColor Yellow
