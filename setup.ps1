[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Run-PowerShellScript {
    param([Parameter(Mandatory = $true)][string]$Path)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Path
    if ($LASTEXITCODE -ne 0) {
        throw ("Script failed ({0}): {1}" -f $LASTEXITCODE, $Path)
    }
}

Write-Host '== 1/2 Install gpt2kiro =='
Run-PowerShellScript -Path (Join-Path $root 'install.ps1')

Write-Host ''
Write-Host '== 2/2 Validate =='
Run-PowerShellScript -Path (Join-Path $root 'validate.ps1')

Write-Host ''
Write-Host 'Setup complete.'
Write-Host 'Open Kiro in this workspace and just start chatting.'
