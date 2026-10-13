[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$hookDir = Join-Path $root '.kiro\hooks'
$scriptDir = Join-Path $root '.kiro\scripts'

$targets = @(
    @{ Hook = 'load-memory.json'; Script = 'load-memory.ps1' },
    @{ Hook = 'load-project.json'; Script = 'load-project.ps1' }
)

foreach ($target in $targets) {
    $hookPath = Join-Path $hookDir $target.Hook
    $scriptPath = Join-Path $scriptDir $target.Script

    if (-not (Test-Path -LiteralPath $hookPath)) {
        throw "Missing hook file: $hookPath"
    }
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Missing script file: $scriptPath"
    }

    $json = Get-Content -LiteralPath $hookPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $json.hooks -or $json.hooks.Count -lt 1) {
        throw "Invalid hook definition: $hookPath"
    }

    $escaped = $scriptPath.Replace('"', '\"')
    $json.hooks[0].action.command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$escaped`""

    $text = $json | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($hookPath, $text + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host 'gpt2kiro hooks installed for this workspace.'
Write-Host "Workspace: $root"
Write-Host 'Run .\validate.ps1 to verify the installation.'
