# Removes all generated artifacts from outputs/.
. "$PSScriptRoot\common.ps1"

Write-Host "Cleaning $OutputsDir ..."
Get-ChildItem -Path $OutputsDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
Write-Host "Done."
