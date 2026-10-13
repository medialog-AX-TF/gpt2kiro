[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$hookPath = Join-Path $root '.kiro\hooks\load-context.json'
$scriptPath = Join-Path $root '.kiro\scripts\load-context.ps1'

if (-not (Test-Path -LiteralPath $hookPath)) { throw "Missing hook file: $hookPath" }
if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Missing script file: $scriptPath" }

$json = Get-Content -LiteralPath $hookPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $json.hooks -or $json.hooks.Count -lt 1) { throw "Invalid hook definition: $hookPath" }

$escaped = $scriptPath.Replace('"', '\"')
$json.hooks[0].action.command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$escaped`""
$text = $json | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($hookPath, $text + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))

Write-Host 'gpt2kiro unified context hook installed for this workspace.'
Write-Host "Workspace: $root"
Write-Host 'Run .\validate.ps1 to verify the installation.'
