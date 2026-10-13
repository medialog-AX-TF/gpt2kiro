[CmdletBinding()]
param(
    [string]$ProjectName = '',
    [string]$Goal = '',
    [switch]$SkipProject,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Step([string]$Text) {
    Write-Host ''
    Write-Host ("== {0} ==" -f $Text)
}

function Run-PowerShellScript {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string[]]$Arguments = @()
    )

    & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw ("Script failed ({0}): {1}" -f $LASTEXITCODE, $Path)
    }
}

Step '1/3 Install workspace hook'
Run-PowerShellScript -Path (Join-Path $root 'install.ps1')

Step '2/3 Validate workspace'
Run-PowerShellScript -Path (Join-Path $root 'validate.ps1')

if ($SkipProject) {
    Step '3/3 Project creation skipped'
    Write-Host 'Setup complete. Start Kiro in this workspace.'
    exit 0
}

if (-not $ProjectName -and -not $NonInteractive) {
    $ProjectName = Read-Host 'Create your first project? Enter a project name, or press Enter to skip'
}

if (-not $ProjectName) {
    Step '3/3 No project created'
    Write-Host 'Setup complete. You can create a project later with:'
    Write-Host '.\.kiro\scripts\new-project.ps1 -Name "My Project" -Goal "What I want to achieve"'
    exit 0
}

if (-not $Goal -and -not $NonInteractive) {
    $Goal = Read-Host 'Enter a short goal for this project'
}

if (-not $Goal) { $Goal = 'First gpt2kiro project' }

Step '3/3 Create first project'
Run-PowerShellScript `
    -Path (Join-Path $root '.kiro\scripts\new-project.ps1') `
    -Arguments @('-Name', $ProjectName, '-Goal', $Goal)

Write-Host ''
Write-Host 'Setup complete.'
Write-Host 'Next: open Kiro in this workspace and start chatting.'
