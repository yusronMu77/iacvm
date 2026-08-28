# Cleanup: unregister the WSL2 distro and delete its on-disk artifacts (ext4.vhdx, etc.)
# from wsl/. Use this after testing is done, or before re-importing a fresh build.
param(
    [string]$Config = $null,
    [string]$DistroName = $null,
    [string]$InstallPath = $null
)

. "$PSScriptRoot\common.ps1"

$ImageName = Resolve-ImageName $Config
if (-not $DistroName) { $DistroName = $ImageName }
if (-not $InstallPath) { $InstallPath = Join-Path $WslDir $DistroName }

$registered = wsl --list --quiet 2>$null |
    ForEach-Object { ($_ -replace "`0", "").Trim() } |
    Where-Object { $_ -eq $DistroName }

if ($registered) {
    Write-Host "Unregistering WSL2 distro '$DistroName'..."
    wsl --unregister $DistroName
    if ($LASTEXITCODE -ne 0) {
        throw "wsl --unregister failed with exit code $LASTEXITCODE"
    }
} else {
    Write-Host "Distro '$DistroName' is not currently registered; skipping unregister."
}

if (Test-Path $InstallPath) {
    Write-Host "Removing on-disk artifacts at $InstallPath ..."
    Remove-Item -Path $InstallPath -Recurse -Force
} else {
    Write-Host "No artifacts found at $InstallPath."
}

Write-Host "Done."
