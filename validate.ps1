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
    '.kiro\scripts\load-memory.ps1',
    '.kiro\scripts\load-project.ps1',
    '.kiro\scripts\sanitize-memory.ps1',
    '.kiro\scripts\search-memory.ps1',
    '.kiro\scripts\write-memory.ps1',
    '.kiro\hooks\load-memory.json',
    '.kiro\hooks\load-project.json'
)

foreach ($relative in $required) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path)) {
        $errors.Add("Missing required file: $relative")
    }
}

foreach ($hookName in @('load-memory.json', 'load-project.json')) {
    $hookPath = Join-Path $kiro ("hooks\" + $hookName)
    if (-not (Test-Path -LiteralPath $hookPath)) { continue }

    try {
        $hook = Get-Content -LiteralPath $hookPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $command = [string]$hook.hooks[0].action.command
        if (-not $command) {
            $errors.Add("Hook has no command: $hookName")
        }
        elseif ($command -notmatch [regex]::Escape($root)) {
            $warnings.Add("Hook appears to target another workspace: $hookName. Run .\install.ps1")
        }
    }
    catch {
        $errors.Add("Invalid hook JSON: $hookName")
    }
}

$activePath = Join-Path $kiro 'projects\ACTIVE'
if (Test-Path -LiteralPath $activePath) {
    $active = (Get-Content -LiteralPath $activePath -Raw -Encoding UTF8).Trim()
    if ($active) {
        $activeDir = Join-Path $kiro ("projects\" + $active)
        if (-not (Test-Path -LiteralPath $activeDir)) {
            $warnings.Add("ACTIVE points to a missing project: $active")
        }
    }
}

# Report potential sensitive-data categories without printing the matched values.
$scanRoots = @(
    (Join-Path $kiro 'memory'),
    (Join-Path $kiro 'projects')
) | Where-Object { Test-Path -LiteralPath $_ }

$patterns = @{
    'email' = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
    'secret-assignment' = '(?im)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|password|passwd|secret|client[_-]?secret)\b\s*[:=]'
    'private-key' = '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
    'windows-user-path' = '(?i)\b[A-Z]:\\Users\\[^\\\s]+'
}

foreach ($scanRoot in $scanRoots) {
    Get-ChildItem -LiteralPath $scanRoot -Filter '*.md' -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
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

if ($errors.Count -eq 0) {
    Write-Host '[OK] required files and hook JSON checks passed.'
}
else {
    foreach ($item in $errors) { Write-Host "[ERROR] $item" }
}

foreach ($item in ($warnings | Sort-Object -Unique)) {
    Write-Host "[WARN] $item"
}

Write-Host ''
Write-Host ("Errors: {0}, Warnings: {1}" -f $errors.Count, @($warnings | Sort-Object -Unique).Count)

if ($errors.Count -gt 0) { exit 1 }
exit 0
