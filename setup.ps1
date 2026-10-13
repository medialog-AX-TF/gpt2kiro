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

Step '1/3 Install workspace hook'
& (Join-Path $root 'install.ps1')
if ($LASTEXITCODE -ne 0) { throw 'install.ps1 failed.' }

Step '2/3 Validate workspace'
& (Join-Path $root 'validate.ps1')
if ($LASTEXITCODE -ne 0) { throw 'validate.ps1 failed.' }

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
& (Join-Path $root '.kiro\scripts\new-project.ps1') -Name $ProjectName -Goal $Goal
if ($LASTEXITCODE -ne 0) { throw 'new-project.ps1 failed.' }

Write-Host ''
Write-Host 'Setup complete.'
Write-Host 'Next: open Kiro in this workspace and start chatting.'
