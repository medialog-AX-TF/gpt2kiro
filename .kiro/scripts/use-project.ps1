<#
  활성 프로젝트 전환 / 조회 / 해제.

  .kiro/projects/ACTIVE 한 줄을 바꾸는 것이 전부다. 다음 세션 시작 시
  load-project.ps1 훅이 이 값을 읽어 해당 프로젝트를 주입한다.

  사용 예:
    .\.kiro\scripts\use-project.ps1 -List
    .\.kiro\scripts\use-project.ps1 -Slug doc-parser
    .\.kiro\scripts\use-project.ps1 -Clear

  주의:
  ACTIVE 는 워크스페이스 전역이고 세션별이 아니다. 열려 있는 다른 세션의
  "다음" 시작에도 영향이 간다. 현재 진행 중인 세션의 컨텍스트는 바뀌지 않는다.

  이 .ps1 은 한글 리터럴 때문에 UTF-8 BOM 포함으로 저장해야 한다.
#>

[CmdletBinding(DefaultParameterSetName = 'Set')]
param(
    [Parameter(ParameterSetName = 'Set', Position = 0)]
    [string]$Slug,

    [Parameter(ParameterSetName = 'List')]
    [switch]$List,

    [Parameter(ParameterSetName = 'Clear')]
    [switch]$Clear
)

$ErrorActionPreference = 'Stop'

$Utf8NoBom   = New-Object System.Text.UTF8Encoding($false)
$projectsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'projects'
$activePath  = Join-Path $projectsDir 'ACTIVE'

if (-not (Test-Path -LiteralPath $projectsDir)) {
    Write-Host '프로젝트 디렉터리가 없다. new-project.ps1 로 먼저 만들 것.'
    exit 0
}

$available = @(Get-ChildItem -LiteralPath $projectsDir -Directory |
               Where-Object { $_.Name -notlike '.*' } |
               Sort-Object Name |
               Select-Object -ExpandProperty Name)

$current = ''
if (Test-Path -LiteralPath $activePath) {
    $raw = Get-Content -LiteralPath $activePath -Raw -Encoding UTF8
    if ($raw) {
        $first = ($raw -replace "`r", '') -split "`n" |
                 Where-Object { $_.Trim() -ne '' } |
                 Select-Object -First 1
        if ($first) { $current = $first.Trim() }
    }
}

if ($Clear) {
    [System.IO.File]::WriteAllText($activePath, '', $Utf8NoBom)
    Write-Host '활성 프로젝트 해제. 다음 세션부터 memory/YYYY-MM-DD.md 에 기록된다.'
    exit 0
}

if ($List -or -not $Slug) {
    if ($available.Count -eq 0) {
        Write-Host '프로젝트가 없다. new-project.ps1 로 만들 것.'
        exit 0
    }
    Write-Host '프로젝트:'
    foreach ($p in $available) {
        $mark = if ($p -eq $current) { '*' } else { ' ' }
        $chatsDir = Join-Path (Join-Path $projectsDir $p) 'chats'
        $count = 0
        if (Test-Path -LiteralPath $chatsDir) {
            $count = @(Get-ChildItem -LiteralPath $chatsDir -Filter '*.md' -File).Count
        }
        Write-Host ("  {0} {1}  (채팅 {2}건)" -f $mark, $p, $count)
    }
    if ($current) { Write-Host ''; Write-Host "활성: $current  (* 표시)" }
    else          { Write-Host ''; Write-Host '활성 프로젝트 없음' }
    exit 0
}

if ($available -notcontains $Slug) {
    Write-Host "'$Slug' 라는 프로젝트가 없다. 사용 가능:"
    foreach ($p in $available) { Write-Host "  - $p" }
    exit 1
}

[System.IO.File]::WriteAllText($activePath, ($Slug + "`n"), $Utf8NoBom)
Write-Host "활성 프로젝트: $Slug"
Write-Host '현재 세션의 컨텍스트는 바뀌지 않는다. 다음 세션 시작 시 적용된다.'
