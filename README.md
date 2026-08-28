# iacvm

[![Latest Release](https://img.shields.io/github/v/release/yusronMu77/iacvm?label=release&sort=semver)](https://github.com/yusronMu77/iacvm/releases/latest)
[![Build & Release](https://github.com/yusronMu77/iacvm/actions/workflows/release.yml/badge.svg)](https://github.com/yusronMu77/iacvm/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Alpine-based IaC devbox, shipped as a ready-to-run [WSL2](https://learn.microsoft.com/windows/wsl/) distro:

- **Incus** — manages/hosts VMs (the hypervisor layer).
- **OpenTofu** (`tofu` CLI) — provisions VMs on top of Incus. Terraform-compatible fork; Alpine
  dropped the `terraform` package after HashiCorp's 2023 BSL relicense.
- **Ansible** — remotely configures the provisioned VMs (e.g. installing Kubernetes on them).

Built with [apko](https://github.com/chainguard-dev/apko) — declarative, Dockerfile-less OCI
image builds from apk package repos — from a single config: [`src/iacvm.yaml`](src/iacvm.yaml).

## Install

Pulls the pre-built rootfs straight from the [latest GitHub Release](https://github.com/yusronMu77/iacvm/releases/latest)
and imports it — no Docker, no build step. Requires
[WSL2](https://learn.microsoft.com/windows/wsl/install) (`wsl --import` needs WSL version
2.4.4+; run `wsl --update` if the import step below fails). Run in PowerShell:

```powershell
# Fetch the latest release, verify its checksum, import as a WSL2 distro
$release = Invoke-RestMethod https://api.github.com/repos/yusronMu77/iacvm/releases/latest
$asset   = $release.assets | Where-Object { $_.name -like '*-rootfs.tar' }
$sums    = ($release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' }).browser_download_url

Invoke-WebRequest $asset.browser_download_url -OutFile $asset.name
$expected = ((Invoke-WebRequest $sums).Content -split "`n" | Select-String $asset.name) -split '\s+' | Select-Object -First 1
if ((Get-FileHash $asset.name -Algorithm SHA256).Hash -ne $expected.ToUpper()) { throw "Checksum mismatch for $($asset.name)" }

wsl --import iacvm C:\WSL\iacvm .\$($asset.name) --version 2
wsl -d iacvm
```

Remove it later with:

```powershell
wsl --unregister iacvm
```

## Build from source

Optional — only needed to modify the image yourself; skip this if the [Install](#install)
section above already got you running. The image is fully defined by one file, [`src/iacvm.yaml`](src/iacvm.yaml) — everything else in
`scripts/` is generic apko-build-to-WSL2-import tooling, not iacvm-specific. Requires
[Docker](https://www.docker.com/) and, for the import step, `wsl.exe` on PATH:

```powershell
./scripts/build.ps1          # src/iacvm.yaml -> outputs/<date>-iacvm-latest.tar
./scripts/package-wsl.ps1    # -> outputs/<date>-iacvm-latest-rootfs.tar
./scripts/import-wsl.ps1     # registers the "iacvm" WSL2 distro
```

Each script takes `-Tag <tag>` to build something other than `latest`; `package-wsl.ps1` and
`import-wsl.ps1` always operate on the most recently modified matching tar in `outputs/`, so
they don't need to run on the same day as the build. Tear down with `./scripts/remove-wsl.ps1`
(unregisters the distro) and `./scripts/clean.ps1` (clears `outputs/`).

## Notes

- `incus` currently lives in Alpine's `edge/testing` repo (less stable than `main`/`community`)
  — if a build starts failing on package resolution, check whether `incus` has moved to
  `community` and drop the `testing` repo from `src/iacvm.yaml` accordingly.
- Incus **VM** support (as opposed to containers) needs nested virtualization/KVM available
  inside the WSL2 distro this image becomes — verify `.wslconfig` has nested virtualization
  enabled (Windows 11 + Hyper-V) before relying on Incus to actually launch VMs, not just
  import the image.

## Contributing

Issues and PRs are welcome — package resolution problems, WSL import quirks, or
improvements to [`src/iacvm.yaml`](src/iacvm.yaml)/`scripts/`. To contribute:

1. Fork the repo and branch from `main`.
2. Test locally with `./scripts/build.ps1` + `./scripts/package-wsl.ps1` (requires Docker).
3. Open a PR describing the change — CI runs the same build automatically on every PR.

## License

This repository's own files — `src/iacvm.yaml` and the scripts in `scripts/` — are MIT
licensed, see [LICENSE](LICENSE).

The image these scripts *build* bundles third-party open-source packages, each under their
own license, notably:

- **Incus** — [Apache License 2.0](https://github.com/lxc/incus/blob/main/COPYING)
- **OpenTofu** — [Mozilla Public License 2.0](https://github.com/opentofu/opentofu/blob/main/LICENSE)
- **Ansible** — [GNU GPL v3.0 or later](https://github.com/ansible/ansible/blob/devel/COPYING)
- Alpine base packages (`bash`, `openssh-client`, `python3`, etc.) — see each package's own
  license in Alpine's [aports](https://gitlab.alpinelinux.org/alpine/aports) repo.

Distributing the built OCI/rootfs image (e.g. via this repo's Releases) is standard practice
for a container/distro image — the same model Alpine's and Docker Hub's official images
use — but using or further redistributing the *built image* is governed by each bundled
package's own license, not just this repo's MIT license on the config/scripts.

## Support

If `iacvm` saves you some setup time, consider supporting its development:

- ☕ [Ko-fi](https://ko-fi.com/yusronmu77)
- 💛 [Teer.id](https://teer.id/yusronmu77)
