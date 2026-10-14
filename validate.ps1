[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$kiro = Join-Path $root '.kiro'
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$required = @(
    '.kiro\steering\security.md',
    '.kiro\steering\retrieval.md',
    '.kiro\steering\memory.md',
    '.kiro\context-budget.json',
    '.kiro\scripts\load-context.ps1',
    '.kiro\scripts\apply-context-budget.ps1',
    '.kiro\scripts\consolidate-memory.ps1',
    '.kiro\scripts\sanitize-memory.ps1',
    '.kiro\scripts\search-memory.ps1',
    '.kiro\scripts\write-memory.ps1',
    '.kiro\hooks\load-context.json'
)

foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative))) {
        $errors.Add("Missing required file: $relative")
    }
}

$projectArtifacts = @(
    '.kiro\projects',
    '.kiro\scripts\new-project.ps1',
    '.kiro\scripts\use-project.ps1',
    '.kiro\scripts\load-project.ps1',
    '.kiro\steering\projects.md'
)
foreach ($relative in $projectArtifacts) {
    if (Test-Path -LiteralPath (Join-Path $root $relative)) {
        $warnings.Add("Legacy project artifact remains: $relative")
    }
}

$hookPath = Join-Path $kiro 'hooks\load-context.json'
if (Test-Path -LiteralPath $hookPath) {
    try {
        $hook = Get-Content -LiteralPath $hookPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $command = [string]$hook.hooks[0].action.command
        if (-not $command) {
            $errors.Add('Unified context hook has no command.')
        }
        elseif ($command -notmatch [regex]::Escape('.kiro\scripts\load-context.ps1')) {
            $errors.Add('Unified context hook must use the workspace-relative load-context.ps1 path.')
        }
    }
    catch { $errors.Add('Invalid hook JSON: load-context.json') }
}

$budgetPath = Join-Path $kiro 'context-budget.json'
if (Test-Path -LiteralPath $budgetPath) {
    try {
        $budget = Get-Content -LiteralPath $budgetPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $sum = [int]$budget.sections.lessons + [int]$budget.sections.longTerm + [int]$budget.sections.recentMemory
        if ($sum -gt [int]$budget.totalTokens) {
            $errors.Add("Section token budgets ($sum) exceed totalTokens ($($budget.totalTokens)).")
        }
        if ([int]$budget.approxCharsPerToken -lt 1) { $errors.Add('approxCharsPerToken must be >= 1.') }
    }
    catch { $errors.Add('Invalid context-budget.json') }
}

$memoryDir = Join-Path $kiro 'memory'
$patterns = @{
    'email' = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
    'secret-assignment' = '(?im)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|password|passwd|secret|client[_-]?secret)\b\s*[:=]'
    'private-key' = '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
    'windows-user-path' = '(?i)\b[A-Z]:\\Users\\[^\\\s]+'
}

if (Test-Path -LiteralPath $memoryDir) {
    Get-ChildItem -LiteralPath $memoryDir -Filter '*.md' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $text = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if (-not $text) { return }
        foreach ($name in $patterns.Keys) {
            if ([regex]::IsMatch($text, $patterns[$name])) {
                $relative = $_.FullName.Substring($root.Length).TrimStart('\', '/')
                $warnings.Add("Potential $name in $relative; review or sanitize before sharing.")
            }
        }
    }
}

Write-Host 'gpt2kiro validation'
Write-Host '-------------------'
if ($errors.Count -eq 0) { Write-Host '[OK] required files, budget, and unified hook checks passed.' }
else { foreach ($item in $errors) { Write-Host "[ERROR] $item" } }
foreach ($item in ($warnings | Sort-Object -Unique)) { Write-Host "[WARN] $item" }
Write-Host ''
Write-Host ("Errors: {0}, Warnings: {1}" -f $errors.Count, @($warnings | Sort-Object -Unique).Count)
if ($errors.Count -gt 0) { exit 1 }
exit 0
