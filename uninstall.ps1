<#
.SYNOPSIS
    Cleans up extension policies created by install.ps1 across all browsers or a specific browser.
.EXAMPLE
    .\uninstall.ps1
.EXAMPLE
    .\uninstall.ps1 -Browser Chrome
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Brave", "Chrome", "Edge", "Vivaldi", "Opera")]
    [string]$Browser = "All"
)

$policyMap = @{
    "Brave"   = "Software\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
    "Chrome"  = "Software\Policies\Google\Chrome\ExtensionInstallForcelist"
    "Edge"    = "Software\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    "Vivaldi" = "Software\Policies\Vivaldi\ExtensionInstallForcelist"
    "Opera"   = "Software\Policies\Opera Software\ExtensionInstallForcelist"
}

$targets = if ($Browser -eq "All") { $policyMap.Keys } else { @($Browser) }
$hives = @("HKCU", "HKLM")

foreach ($b in $targets) {
    $policyPath = $policyMap[$b]
    foreach ($hive in $hives) {
        $path = "$hive`:\$policyPath"
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removed $b policy from: $path" -ForegroundColor Green
        }
    }
}

Write-Host "Policy cleanup finished." -ForegroundColor Cyan
