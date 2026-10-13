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
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path)) { $errors.Add("Missing required file: $relative") }
}

$hookPath = Join-Path $kiro 'hooks\load-context.json'
if (Test-Path -LiteralPath $hookPath) {
    try {
        $hook = Get-Content -LiteralPath $hookPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $command = [string]$hook.hooks[0].action.command
        if (-not $command) { $errors.Add('Unified context hook has no command.') }
        elseif ($command -notmatch [regex]::Escape($root)) {
            $warnings.Add('Unified context hook is not installed with this workspace absolute path. Run .\install.ps1')
        }
    }
    catch { $errors.Add('Invalid hook JSON: load-context.json') }
}

foreach ($legacyHook in @('load-memory.json', 'load-project.json')) {
    if (Test-Path -LiteralPath (Join-Path $kiro ("hooks\" + $legacyHook))) {
        $warnings.Add("Legacy SessionStart hook still exists: $legacyHook. It can duplicate context injection.")
    }
}

$budgetPath = Join-Path $kiro 'context-budget.json'
if (Test-Path -LiteralPath $budgetPath) {
    try {
        $budget = Get-Content -LiteralPath $budgetPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $sum = [int]$budget.sections.lessons + [int]$budget.sections.longTerm + [int]$budget.sections.recentMemory + [int]$budget.sections.project
        if ($sum -gt [int]$budget.totalTokens) {
            $errors.Add("Section token budgets ($sum) exceed totalTokens ($($budget.totalTokens)).")
        }
        if ([int]$budget.approxCharsPerToken -lt 1) { $errors.Add('approxCharsPerToken must be >= 1.') }
    }
    catch { $errors.Add('Invalid context-budget.json') }
}

$activePath = Join-Path $kiro 'projects\ACTIVE'
if (Test-Path -LiteralPath $activePath) {
    $active = (Get-Content -LiteralPath $activePath -Raw -Encoding UTF8).Trim()
    if ($active) {
        $activeDir = Join-Path $kiro ("projects\" + $active)
        if (-not (Test-Path -LiteralPath $activeDir)) { $warnings.Add("ACTIVE points to a missing project: $active") }
    }
}

$scanRoots = @((Join-Path $kiro 'memory'), (Join-Path $kiro 'projects')) | Where-Object { Test-Path -LiteralPath $_ }
$patterns = @{
    'email' = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
    'secret-assignment' = '(?im)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|password|passwd|secret|client[_-]?secret)\b\s*[:=]'
    'private-key' = '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
    'windows-user-path' = '(?i)\b[A-Z]:\\Users\\[^\\\s]+'
}

foreach ($scanRoot in $scanRoots) {
    Get-ChildItem -LiteralPath $scanRoot -Filter '*.md' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
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
