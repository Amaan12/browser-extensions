<#
.SYNOPSIS
    Removes the extension auto-install policy for a specified browser.
.DESCRIPTION
    Deletes the ExtensionInstallForcelist policy key from Windows Registry.
    When you next open the browser, Chromium recognizes that the extensions are no longer
    mandated by policy and automatically uninstalls them.

    This DOES NOT touch your bookmarks, browsing history, passwords, or personal settings.
.EXAMPLE
    .\uninstall.ps1 -Browser Brave
.EXAMPLE
    .\uninstall.ps1 (interactively prompts which browser to clean up)
#>

[CmdletBinding()]
param(
    [ValidateSet("Brave", "Chrome", "Edge", "Vivaldi", "Opera", "All", "")]
    [string]$Browser = ""
)

$policyMap = [ordered]@{
    "Brave"   = "Software\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
    "Chrome"  = "Software\Policies\Google\Chrome\ExtensionInstallForcelist"
    "Edge"    = "Software\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    "Vivaldi" = "Software\Policies\Vivaldi\ExtensionInstallForcelist"
    "Opera"   = "Software\Policies\Opera Software\ExtensionInstallForcelist"
}

if ([string]::IsNullOrWhiteSpace($Browser)) {
    Write-Host "`nSelect which browser's extension policy you want to remove:" -ForegroundColor Cyan
    $keys = [string[]]$policyMap.Keys
    for ($i = 0; $i -lt $keys.Count; $i++) {
        Write-Host "  [$($i + 1)] $($keys[$i])"
    }
    Write-Host "  [$($keys.Count + 1)] All"
    $choice = Read-Host "`nEnter selection [1-$($keys.Count + 1)]"
    $idx = 0
    if (-not [string]::IsNullOrWhiteSpace($choice)) {
        $idx = [int]$choice - 1
    }
    if ($idx -eq $keys.Count) {
        $Browser = "All"
    } elseif ($idx -ge 0 -and $idx -lt $keys.Count) {
        $Browser = $keys[$idx]
    } else {
        Write-Error "Invalid selection."
    }
}

$targets = if ($Browser -eq "All") { $policyMap.Keys } else { @($Browser) }
$hives = @("HKCU", "HKLM")

foreach ($b in $targets) {
    $policyPath = $policyMap[$b]
    $found = $false
    foreach ($hive in $hives) {
        $path = "$hive`:\$policyPath"
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host " [x] Removed policy for $b from: $path" -ForegroundColor Green
            $found = $true
        }
    }
    if (-not $found) {
        Write-Host " [-] No active policy was found for $b." -ForegroundColor DarkGray
    }
}

Write-Host "`n[SUCCESS] Policy cleanup finished." -ForegroundColor Green
Write-Host "When you next launch your browser, the policy-managed extensions will be uninstalled." -ForegroundColor Yellow
