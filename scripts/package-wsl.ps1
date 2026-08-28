# Stage 2: turn the latest OCI tar from build.ps1 into a flat rootfs tar that `wsl --import` accepts.
param(
    [string]$Config = $null,
    [string]$Tag = $null
)

. "$PSScriptRoot\common.ps1"

Assert-DockerAvailable

$ImageName = Resolve-ImageName $Config
$ImageTag = Resolve-ImageTag $Tag

$ociTar = Get-LatestOciTar -ImageName $ImageName -ImageTag $ImageTag
if (-not $ociTar) {
    throw "No OCI tar matching '*-$ImageName-$ImageTag.tar' found in $OutputsDir. Run build.ps1 -Config $ImageName first."
}

Write-Host "Loading OCI image into Docker: $($ociTar.Name)"
$loadOutput = docker load -i $ociTar.FullName
if ($LASTEXITCODE -ne 0) {
    throw "docker load failed with exit code $LASTEXITCODE"
}
$loadOutput | ForEach-Object { Write-Host $_ }

# apko tags the image it bakes into the OCI tar as "<name>:<tag>-<arch>" (e.g.
# "iacvm:latest-amd64"), not the plain "<name>:<tag>" - read back what docker load actually
# reports instead of assuming the tag, so this keeps working regardless of arch/apko naming.
$loadedRef = $loadOutput |
    Select-String -Pattern 'Loaded image:\s*(.+)$' |
    ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() } |
    Select-Object -Last 1

if (-not $loadedRef) {
    throw "Could not determine the image reference docker loaded from $($ociTar.Name); check the 'docker load' output above."
}

$rootfsTarName = "$($ociTar.BaseName)-rootfs.tar"
$rootfsTarPath = Join-Path $OutputsDir $rootfsTarName

Write-Host "Exporting flattened rootfs for WSL2 import (from $loadedRef)..."
$cid = docker create $loadedRef
if ($LASTEXITCODE -ne 0) {
    throw "docker create failed with exit code $LASTEXITCODE"
}
try {
    docker export $cid -o $rootfsTarPath
    if ($LASTEXITCODE -ne 0) {
        throw "docker export failed with exit code $LASTEXITCODE"
    }
} finally {
    docker rm $cid | Out-Null
}

Write-Host "Packaged WSL2 rootfs -> $rootfsTarPath"

# The rootfs tar above is now the artifact of record - the image docker just loaded is a
# disposable build byproduct, so remove it to avoid piling up an image per build. This does
# NOT touch $ApkoDockerImage (the apko builder itself), which stays cached for faster builds.
Write-Host "Cleaning up local build-result image $loadedRef ..."
docker rmi $loadedRef *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not remove local image $loadedRef (safe to ignore if something else is using it)."
}
