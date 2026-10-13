[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Topic,
    [string]$Context = '',
    [string]$Work = '',
    [string]$Decision = '',
    [string]$Validation = '',
    [string]$Remaining = '없음',
    [string]$ProjectSlug = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$kiroDir = Split-Path $PSScriptRoot -Parent
$memoryDir = Join-Path $kiroDir 'memory'
$projectsDir = Join-Path $kiroDir 'projects'
$sanitizer = Join-Path $PSScriptRoot 'sanitize-memory.ps1'

if (-not (Test-Path -LiteralPath $sanitizer)) { throw 'sanitize-memory.ps1 is required. Memory write aborted.' }

function Sanitize([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $out = (& $sanitizer -Text $Value | Out-String).TrimEnd()
    if ($out -match '(?i)-----BEGIN .*PRIVATE KEY-----|\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b|\b(?:api[_-]?key|access[_-]?token|refresh[_-]?token|password|passwd|client[_-]?secret)\b\s*[:=]\s*(?!\[REDACTED_)') {
        throw 'Potential sensitive data remained after sanitization. Memory write aborted.'
    }
    return $out
}

function Slugify([string]$Value) {
    $s = $Value.Trim().ToLowerInvariant()
    $s = $s -replace '[<>:"/\\|?*\.]', ''
    $s = $s -replace '\s+', '-'
    $s = $s -replace '[^\p{L}\p{Nd}\-_]', ''
    $s = $s -replace '-{2,}', '-'
    $s = $s.Trim('-', '_')
    if (-not $s) { $s = 'session' }
    if ($s.Length -gt 48) { $s = $s.Substring(0, 48).TrimEnd('-','_') }
    return $s
}

$topic = Sanitize $Topic
$context = Sanitize $Context
$work = Sanitize $Work
$decision = Sanitize $Decision
$validation = Sanitize $Validation
$remaining = Sanitize $Remaining

$now = Get-Date
$date = $now.ToString('yyyy-MM-dd')
$time = $now.ToString('HHmmss')

if (-not $ProjectSlug) {
    $activePath = Join-Path $projectsDir 'ACTIVE'
    if (Test-Path -LiteralPath $activePath) {
        $ProjectSlug = ((Get-Content -LiteralPath $activePath -Raw -Encoding UTF8) -replace "`r", '').Split("`n")[0].Trim()
    }
}

$body = @"
## 세션: $topic

**맥락** $context
**한 일** $work
**결정** $decision
**검증** $validation
**남은 일** $remaining
"@

if ($ProjectSlug) {
    $projectDir = Join-Path $projectsDir $ProjectSlug
    if (-not (Test-Path -LiteralPath $projectDir -PathType Container)) { throw "Unknown project slug: $ProjectSlug" }
    $chatsDir = Join-Path $projectDir 'chats'
    $fileName = "$date-$time-$(Slugify $topic).md"
    $target = Join-Path $chatsDir $fileName
    $text = "# $date — $topic`n`n$body"
    $relative = "../projects/$ProjectSlug/chats/$fileName"
    $indexEntry = "- [$date]($relative) — [$ProjectSlug] $topic"

    if ($DryRun) { Write-Output $text; exit 0 }
    if (-not (Test-Path -LiteralPath $chatsDir)) { New-Item -ItemType Directory -Path $chatsDir | Out-Null }
    [System.IO.File]::WriteAllText($target, $text.TrimEnd() + "`n", $Utf8NoBom)

    $projectIndex = Join-Path $projectDir 'index.md'
    if (Test-Path -LiteralPath $projectIndex) {
        $content = Get-Content -LiteralPath $projectIndex -Raw -Encoding UTF8
        $entry = "- [$date $($now.ToString('HH:mm'))](chats/$fileName) — $topic"
        $content = $content -replace '(<!-- 목록 시작 -->\s*)', "`$1$entry`n"
        [System.IO.File]::WriteAllText($projectIndex, $content, $Utf8NoBom)
    }
}
else {
    $target = Join-Path $memoryDir "$date.md"
    $indexEntry = "- [$date]($date.md) — $topic"
    if ($DryRun) { Write-Output $body; exit 0 }
    if (-not (Test-Path -LiteralPath $memoryDir)) { New-Item -ItemType Directory -Path $memoryDir | Out-Null }

    if (-not (Test-Path -LiteralPath $target)) {
        [System.IO.File]::WriteAllText($target, "# $date`n`n$body".TrimEnd() + "`n", $Utf8NoBom)
    } else {
        [System.IO.File]::AppendAllText($target, "`n$body".TrimEnd() + "`n", $Utf8NoBom)
    }
}

$memoryIndex = Join-Path $memoryDir 'index.md'
if (-not (Test-Path -LiteralPath $memoryIndex)) {
    [System.IO.File]::WriteAllText($memoryIndex, "# 기억 목차`n`n$indexEntry`n", $Utf8NoBom)
} else {
    $idx = Get-Content -LiteralPath $memoryIndex -Raw -Encoding UTF8
    $lines = $idx -split "`r?`n"
    $insertAt = 0
    for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^# ') { $insertAt = $i + 1; break } }
    while ($insertAt -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$insertAt])) { $insertAt++ }
    $newLines = @()
    if ($insertAt -gt 0) { $newLines += $lines[0..($insertAt-1)] }
    $newLines += $indexEntry
    if ($insertAt -lt $lines.Count) { $newLines += $lines[$insertAt..($lines.Count-1)] }
    [System.IO.File]::WriteAllText($memoryIndex, (($newLines -join "`n").TrimEnd() + "`n"), $Utf8NoBom)
}

Write-Host "Memory written: $target"
