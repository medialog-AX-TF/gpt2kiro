[CmdletBinding()]
param(
    [int]$OlderThanDays = 7,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$kiroDir = Split-Path $PSScriptRoot -Parent
$memoryDir = Join-Path $kiroDir 'memory'
$weeklyDir = Join-Path $memoryDir 'weekly'
$longTermPath = Join-Path $memoryDir 'long-term.md'

if (-not (Test-Path -LiteralPath $memoryDir)) { exit 0 }

function Get-WeekKey([datetime]$Date) {
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $calendar = $culture.Calendar
    $week = $calendar.GetWeekOfYear(
        $Date,
        [System.Globalization.CalendarWeekRule]::FirstFourDayWeek,
        [DayOfWeek]::Monday
    )
    return ('{0}-W{1:00}' -f $Date.Year, $week)
}

function Extract-SummaryLines([string]$Text) {
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Text -split "`r?`n")) {
        $trim = $line.Trim()
        if (-not $trim) { continue }
        if ($trim -match '^##\s+' -or $trim -match '^\*\*.+\*\*') {
            if ($trim.Length -gt 240) { $trim = $trim.Substring(0, 240) + '...' }
            $out.Add($trim)
        }
    }
    return $out
}

$cutoff = (Get-Date).Date.AddDays(-1 * [Math]::Abs($OlderThanDays))
$groups = @{}
$dailyFiles = @(Get-ChildItem -LiteralPath $memoryDir -Filter '????-??-??.md' -File | Sort-Object Name)

foreach ($file in $dailyFiles) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $date = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($base, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$date)) {
        continue
    }
    if ($date -gt $cutoff) { continue }

    $key = Get-WeekKey $date
    if (-not $groups.ContainsKey($key)) { $groups[$key] = New-Object System.Collections.Generic.List[object] }
    $groups[$key].Add($file)
}

$weeklyOutputs = New-Object System.Collections.Generic.List[object]
foreach ($key in ($groups.Keys | Sort-Object)) {
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add("# Weekly memory $key")
    $parts.Add('')
    $parts.Add('Generated deterministically from daily memory. Source files remain authoritative.')

    foreach ($file in $groups[$key]) {
        $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        $summary = @(Extract-SummaryLines $text)
        if ($summary.Count -eq 0) { continue }
        $parts.Add('')
        $parts.Add("## Source: $($file.Name)")
        foreach ($line in $summary) { $parts.Add($line) }
    }

    $weeklyText = ($parts -join "`n").TrimEnd() + "`n"
    $weeklyPath = Join-Path $weeklyDir "$key.md"
    $weeklyOutputs.Add([pscustomobject]@{ Path = $weeklyPath; Text = $weeklyText })
}

$longTermLines = New-Object System.Collections.Generic.List[string]
$longTermLines.Add('# Long-term memory')
$longTermLines.Add('')
$longTermLines.Add('Compact pointers and durable facts derived from weekly memory. Weekly files remain the source of detail.')

foreach ($item in $weeklyOutputs) {
    $weekName = [System.IO.Path]::GetFileNameWithoutExtension($item.Path)
    $longTermLines.Add('')
    $longTermLines.Add("## $weekName")
    $selected = @($item.Text -split "`r?`n" | Where-Object {
        $_ -match '^## Source:' -or $_ -match '^\*\*.+\*\*'
    } | Select-Object -First 80)
    foreach ($line in $selected) { $longTermLines.Add($line) }
}
$longTermText = ($longTermLines -join "`n").TrimEnd() + "`n"

if ($DryRun) {
    foreach ($item in $weeklyOutputs) {
        Write-Output "--- $($item.Path) ---"
        Write-Output $item.Text
    }
    Write-Output "--- $longTermPath ---"
    Write-Output $longTermText
    exit 0
}

if ($weeklyOutputs.Count -gt 0 -and -not (Test-Path -LiteralPath $weeklyDir)) {
    New-Item -ItemType Directory -Path $weeklyDir | Out-Null
}
foreach ($item in $weeklyOutputs) {
    [System.IO.File]::WriteAllText($item.Path, $item.Text, $Utf8NoBom)
}
[System.IO.File]::WriteAllText($longTermPath, $longTermText, $Utf8NoBom)

Write-Host ("Consolidated daily memory into {0} weekly file(s)." -f $weeklyOutputs.Count)
Write-Host "Long-term memory: $longTermPath"
