# Stage 3: import the latest rootfs tar from package-wsl.ps1 as a WSL2 distro.
param(
    [string]$Config = $null,
    [string]$Tag = $null,
    [string]$DistroName = $null,
    [string]$InstallPath = $null
)

. "$PSScriptRoot\common.ps1"

$ImageName = Resolve-ImageName $Config
$ImageTag = Resolve-ImageTag $Tag
if (-not $DistroName) { $DistroName = $ImageName }
if (-not $InstallPath) { $InstallPath = Join-Path $WslDir $DistroName }

$rootfsTar = Get-LatestRootfsTar -ImageName $ImageName -ImageTag $ImageTag
if (-not $rootfsTar) {
    throw "No rootfs tar matching '*-$ImageName-$ImageTag-rootfs.tar' found in $OutputsDir. Run package-wsl.ps1 -Config $ImageName first."
}

New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null

Write-Host "Importing $($rootfsTar.Name) as WSL2 distro '$DistroName'..."
wsl --import $DistroName $InstallPath $rootfsTar.FullName --version 2
if ($LASTEXITCODE -ne 0) {
    throw "wsl --import failed with exit code $LASTEXITCODE"
}

Write-Host "Imported into WSL2 as distro '$DistroName'."
Write-Host "Disk artifacts (ext4.vhdx, etc.) -> $InstallPath"
Write-Host "Open it with: code --remote wsl+$DistroName /"
