<#
.SYNOPSIS
    Removes the extension policy keys added by install.ps1.
.DESCRIPTION
    Clears the ExtensionInstallForcelist policy for Brave, Chrome, or Edge.
.EXAMPLE
    .\uninstall.ps1
.EXAMPLE
    .\uninstall.ps1 -Browser Chrome
#>

[CmdletBinding()]
param(
    [ValidateSet("Brave", "Chrome", "Edge")]
    [string]$Browser = "Brave"
)

$policyPath = switch ($Browser) {
    "Brave"  { "Software\Policies\BraveSoftware\Brave\ExtensionInstallForcelist" }
    "Chrome" { "Software\Policies\Google\Chrome\ExtensionInstallForcelist" }
    "Edge"   { "Software\Policies\Microsoft\Edge\ExtensionInstallForcelist" }
}

$hives = @("HKCU", "HKLM")

foreach ($hive in $hives) {
    $path = "$hive`:\$policyPath"
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed policy from: $path" -ForegroundColor Green
    }
}

Write-Host "Policy cleanup complete for $Browser." -ForegroundColor Cyan
