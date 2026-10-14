[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Topic,
    [string]$Context = '',
    [string]$Work = '',
    [string]$Decision = '',
    [string]$Validation = '',
    [string]$Remaining = 'none',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$kiroDir = Split-Path $PSScriptRoot -Parent
$memoryDir = Join-Path $kiroDir 'memory'
$sanitizer = Join-Path $PSScriptRoot 'sanitize-memory.ps1'

if (-not (Test-Path -LiteralPath $sanitizer)) {
    throw 'sanitize-memory.ps1 is required. Memory write aborted.'
}

function Sanitize([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $out = (& $sanitizer -Text $Value | Out-String).TrimEnd()
    if ($out -match '(?i)-----BEGIN .*PRIVATE KEY-----|\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b|\b(?:api[_-]?key|access[_-]?token|refresh[_-]?token|password|passwd|client[_-]?secret)\b\s*[:=]\s*(?!\[REDACTED_)') {
        throw 'Potential sensitive data remained after sanitization. Memory write aborted.'
    }
    return $out
}

$topic = Sanitize $Topic
$context = Sanitize $Context
$work = Sanitize $Work
$decision = Sanitize $Decision
$validation = Sanitize $Validation
$remaining = Sanitize $Remaining

$now = Get-Date
$date = $now.ToString('yyyy-MM-dd')
$body = @"
## Session: $topic

**Context** $context
**Work** $work
**Decision** $decision
**Validation** $validation
**Remaining** $remaining
"@

$target = Join-Path $memoryDir "$date.md"
$indexEntry = "- [$date]($date.md) - $topic"

if ($DryRun) {
    Write-Output $body
    exit 0
}

if (-not (Test-Path -LiteralPath $memoryDir)) {
    New-Item -ItemType Directory -Path $memoryDir | Out-Null
}

if (-not (Test-Path -LiteralPath $target)) {
    [System.IO.File]::WriteAllText($target, ("# $date`n`n$body").TrimEnd() + "`n", $Utf8NoBom)
}
else {
    [System.IO.File]::AppendAllText($target, ("`n$body").TrimEnd() + "`n", $Utf8NoBom)
}

$memoryIndex = Join-Path $memoryDir 'index.md'
if (-not (Test-Path -LiteralPath $memoryIndex)) {
    [System.IO.File]::WriteAllText($memoryIndex, "# Memory index`n`n$indexEntry`n", $Utf8NoBom)
}
else {
    $idx = Get-Content -LiteralPath $memoryIndex -Raw -Encoding UTF8
    $lines = $idx -split "`r?`n"
    $insertAt = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^# ') { $insertAt = $i + 1; break }
    }
    while ($insertAt -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$insertAt])) { $insertAt++ }
    $newLines = @()
    if ($insertAt -gt 0) { $newLines += $lines[0..($insertAt - 1)] }
    $newLines += $indexEntry
    if ($insertAt -lt $lines.Count) { $newLines += $lines[$insertAt..($lines.Count - 1)] }
    [System.IO.File]::WriteAllText($memoryIndex, (($newLines -join "`n").TrimEnd() + "`n"), $Utf8NoBom)
}

Write-Host "Memory written: $target"
