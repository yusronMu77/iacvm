# Stage 1: build an OCI image tar from a src/<name>.yaml config using apko (via its Docker image).
param(
    [string]$Config = $null,
    [string]$Tag = $null
)

. "$PSScriptRoot\common.ps1"

Assert-DockerAvailable

$ImageName = Resolve-ImageName $Config
$ImageTag = Resolve-ImageTag $Tag
$ApkoConfigPath = Get-ApkoConfigPath $ImageName

$BuildDate = Get-Date -Format "yyyy-MM-dd"
$OciTarName = "$BuildDate-$ImageName-$ImageTag.tar"

Write-Host "Building OCI image '${ImageName}:${ImageTag}' from $ApkoConfigPath ..."

docker run --rm `
  -v "${SrcDir}:/work/src" `
  -v "${OutputsDir}:/work/outputs" `
  -w /work `
  $ApkoDockerImage build "src/$ImageName.yaml" "${ImageName}:${ImageTag}" "outputs/$OciTarName" --arch host

if ($LASTEXITCODE -ne 0) {
    throw "apko build failed with exit code $LASTEXITCODE"
}

Write-Host "Built OCI image -> $(Join-Path $OutputsDir $OciTarName)"
