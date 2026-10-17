<#
.SYNOPSIS
    Automated extension installer for Brave, Chrome, and Edge from a GitHub repository or local file.
.DESCRIPTION
    Reads extensions from extensions.json (or remote GitHub URL) and configures the browser's
    ExtensionInstallForcelist policy, causing the browser to automatically and silently
    download and install all extensions upon launch.

    Can also be run directly from PowerShell via:
    irm https://raw.githubusercontent.com/<USER>/<REPO>/main/install.ps1 | iex
.EXAMPLE
    .\install.ps1
.EXAMPLE
    .\install.ps1 -OpenTabs
.EXAMPLE
    .\install.ps1 -Browser Chrome
#>

[CmdletBinding()]
param(
    [ValidateSet("Brave", "Chrome", "Edge")]
    [string]$Browser = "Brave",

    # Path to local JSON file or remote URL
    [string]$Source = "",

    # Open Chrome Web Store tabs instead of applying registry policies
    [switch]$OpenTabs
)

$ErrorActionPreference = "Stop"

# --- 1. Resolve Extension Data Source ---
$extensions = @()

if (-not [string]::IsNullOrWhiteSpace($Source)) {
    if ($Source -match '^https?://') {
        Write-Host "Fetching extensions from remote URL: $Source" -ForegroundColor Cyan
        $extensions = Invoke-RestMethod -Uri $Source
    } else {
        $extensions = Get-Content $Source -Raw -Encoding UTF8 | ConvertFrom-Json
    }
} else {
    # Check if local extensions.json exists in script directory
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $localJson = Join-Path $scriptDir "extensions.json"

    if (Test-Path $localJson) {
        Write-Host "Loading extensions from local file: $localJson" -ForegroundColor Cyan
        $extensions = Get-Content $localJson -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        # Fallback prompt if run via one-liner without embedded URL
        Write-Host "extensions.json not found locally." -ForegroundColor Yellow
        $repoUser = Read-Host "Enter your GitHub username or full raw URL to extensions.json"
        if ($repoUser -match '^https?://') {
            $extensions = Invoke-RestMethod -Uri $repoUser
        } else {
            $repoName = Read-Host "Enter your GitHub repository name [default: brave-extensions-sync]"
            if ([string]::IsNullOrWhiteSpace($repoName)) { $repoName = "brave-extensions-sync" }
            $rawUrl = "https://raw.githubusercontent.com/$repoUser/$repoName/main/extensions.json"
            Write-Host "Downloading from $rawUrl ..." -ForegroundColor Cyan
            $extensions = Invoke-RestMethod -Uri $rawUrl
        }
    }
}

if (-not $extensions -or $extensions.Count -eq 0) {
    Write-Error "No extensions found to install."
}

Write-Host "`nExtensions to install ($($extensions.Count)):" -ForegroundColor Green
$extensions | ForEach-Object { Write-Host " - $($_.name) ($($_.id))" }
Write-Host ""

# --- 2. Determine Browser Paths & Registry Targets ---
$browserConfig = switch ($Browser) {
    "Brave" {
        @{
            Name        = "Brave"
            PolicyPath  = "Software\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
            ExePaths    = @(
                "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
                "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
                "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"
            )
        }
    }
    "Chrome" {
        @{
            Name        = "Google Chrome"
            PolicyPath  = "Software\Policies\Google\Chrome\ExtensionInstallForcelist"
            ExePaths    = @(
                "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
            )
        }
    }
    "Edge" {
        @{
            Name        = "Microsoft Edge"
            PolicyPath  = "Software\Policies\Microsoft\Edge\ExtensionInstallForcelist"
            ExePaths    = @(
                "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
                "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
            )
        }
    }
}

# Find browser executable
$browserExe = $browserConfig.ExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

# --- 3. Execution Mode: Open Tabs vs Policy Install ---
if ($OpenTabs) {
    if (-not $browserExe) {
        Write-Error "$($browserConfig.Name) executable could not be found."
    }
    Write-Host "Opening $($extensions.Count) extension pages in $($browserConfig.Name)..." -ForegroundColor Cyan
    $urls = $extensions | ForEach-Object { $_.url }
    Start-Process -FilePath $browserExe -ArgumentList $urls
    Write-Host "Done! Click 'Add to $($browserConfig.Name)' on each tab." -ForegroundColor Green
    return
}

# Default Mode: Automatic Registry Policy Force-Install
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Prefer HKLM if Administrator (machine-wide), otherwise HKCU (current user)
$targetHives = @()
if ($isAdmin) {
    $targetHives += "HKLM"
}
$targetHives += "HKCU"

$updateUrl = "https://clients2.google.com/service/update2/crx"

foreach ($hive in $targetHives) {
    $regPath = "$hive`:\$($browserConfig.PolicyPath)"
    Write-Host "Configuring registry: $regPath" -ForegroundColor Cyan

    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    $index = 1
    foreach ($ext in $extensions) {
        $entryValue = "$($ext.id);$updateUrl"
        New-ItemProperty -Path $regPath -Name "$index" -Value $entryValue -PropertyType String -Force | Out-Null
        $index++
    }
}

Write-Host "`n[SUCCESS] Successfully configured $($extensions.Count) extensions for $($browserConfig.Name)!" -ForegroundColor Green
Write-Host "The extensions will be automatically downloaded and installed the next time you open $($browserConfig.Name)." -ForegroundColor Yellow

$restart = Read-Host "`nWould you like to launch/restart $($browserConfig.Name) now? (y/n)"
if ($restart -eq 'y' -or $restart -eq 'Y') {
    if ($browserExe) {
        # Check if browser is running and restart
        $procName = [System.IO.Path]::GetFileNameWithoutExtension($browserExe)
        Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Process -FilePath $browserExe
        Write-Host "$($browserConfig.Name) launched!" -ForegroundColor Green
    } else {
        Write-Warning "Could not find browser executable to launch automatically. Please open $($browserConfig.Name) manually."
    }
}
