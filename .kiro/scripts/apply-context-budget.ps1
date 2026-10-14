[CmdletBinding()]
param(
    [string]$Lessons = '',
    [string]$LongTerm = '',
    [string]$RecentMemory = '',
    [string]$ConfigPath = ''
)

$ErrorActionPreference = 'Stop'
$kiroDir = Split-Path $PSScriptRoot -Parent
if (-not $ConfigPath) { $ConfigPath = Join-Path $kiroDir 'context-budget.json' }
if (-not (Test-Path -LiteralPath $ConfigPath)) { throw 'Context budget config not found.' }

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$charsPerToken = [int]$config.approxCharsPerToken
if ($charsPerToken -lt 1) { $charsPerToken = 4 }

function Clip-Head([string]$Text, [int]$TokenBudget) {
    if ([string]::IsNullOrEmpty($Text) -or $TokenBudget -le 0) { return '' }
    $maxChars = $TokenBudget * $charsPerToken
    if ($Text.Length -le $maxChars) { return $Text }
    return $Text.Substring(0, $maxChars) + "`n[context clipped]"
}

function Clip-Tail([string]$Text, [int]$TokenBudget) {
    if ([string]::IsNullOrEmpty($Text) -or $TokenBudget -le 0) { return '' }
    $maxChars = $TokenBudget * $charsPerToken
    if ($Text.Length -le $maxChars) { return $Text }
    return "[context clipped]`n" + $Text.Substring($Text.Length - $maxChars)
}

$parts = New-Object System.Collections.Generic.List[string]
$lessonsOut = Clip-Tail $Lessons ([int]$config.sections.lessons)
$longTermOut = Clip-Head $LongTerm ([int]$config.sections.longTerm)
$recentOut = Clip-Head $RecentMemory ([int]$config.sections.recentMemory)

if ($lessonsOut) { $parts.Add("=== LESSONS ===`n$lessonsOut") }
if ($longTermOut) { $parts.Add("=== LONG TERM MEMORY ===`n$longTermOut") }
if ($recentOut) { $parts.Add("=== RECENT MEMORY ===`n$recentOut") }

$body = $parts -join "`n`n---`n`n"
$globalMax = [int]$config.totalTokens * $charsPerToken
if ($globalMax -gt 0 -and $body.Length -gt $globalMax) {
    $body = $body.Substring(0, $globalMax) + "`n[total context budget reached]"
}

$body
