# Shared configuration sourced (dot-sourced) by every other script in this folder.
# Keep paths in one place so build/package/import/remove/clean stay in sync.

$Root = Split-Path $PSScriptRoot -Parent
$SrcDir = Join-Path $Root "src"
$OutputsDir = Join-Path $Root "outputs"
$WslDir = Join-Path $Root "wsl"

$ApkoDockerImage = "cgr.dev/chainguard/apko:latest"
$DefaultImageTag = "latest"

New-Item -ItemType Directory -Force -Path $OutputsDir | Out-Null
New-Item -ItemType Directory -Force -Path $WslDir | Out-Null

# The image name/tag are never hardcoded: the name is derived from whichever apko config file
# in src/ is being built (src/iacvm.yaml -> image name "iacvm"), and the tag defaults to
# "latest" but can be overridden per invocation. This lets src/ hold more than one image
# definition without renaming any script.

function Resolve-ImageName {
    param([string]$Config)

    if ($Config) {
        return $Config.ToLower()
    }

    $configs = Get-ChildItem -Path $SrcDir -Filter "*.yaml" -File -ErrorAction SilentlyContinue
    if ($configs.Count -eq 1) {
        return $configs[0].BaseName.ToLower()
    }
    if ($configs.Count -eq 0) {
        throw "No apko config (*.yaml) found in $SrcDir."
    }
    throw "Multiple apko configs found in ${SrcDir}: $(($configs.BaseName) -join ', ') - specify -Config <name>."
}

function Resolve-ImageTag {
    param([string]$Tag)
    if ($Tag) { return $Tag }
    return $DefaultImageTag
}

function Get-ApkoConfigPath {
    param([Parameter(Mandatory)][string]$ImageName)
    $configPath = Join-Path $SrcDir "$ImageName.yaml"
    if (-not (Test-Path $configPath)) {
        throw "No apko config found at $configPath."
    }
    $configPath
}

# Build artifacts are named "<date>-<image-name>-<tag>.tar" (OCI image) and
# "<date>-<image-name>-<tag>-rootfs.tar" (flattened rootfs for WSL2 import). The date is
# baked into the filename at build time, so later stages look up the most recent matching
# file instead of assuming "today" is still the build date.

function Get-LatestOciTar {
    param(
        [Parameter(Mandatory)][string]$ImageName,
        [Parameter(Mandatory)][string]$ImageTag
    )
    Get-ChildItem -Path $OutputsDir -Filter "*-$ImageName-$ImageTag.tar" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Get-LatestRootfsTar {
    param(
        [Parameter(Mandatory)][string]$ImageName,
        [Parameter(Mandatory)][string]$ImageTag
    )
    Get-ChildItem -Path $OutputsDir -Filter "*-$ImageName-$ImageTag-rootfs.tar" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

# Fail fast with a clear message instead of a confusing docker CLI error mid-build.
function Assert-DockerAvailable {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker CLI not found on PATH. Install Docker Desktop (with WSL2 integration) and try again."
    }
    docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker CLI found but the daemon isn't responding. Start Docker Desktop/Docker Engine and try again."
    }
}
