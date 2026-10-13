<#
  프로젝트 스캐폴딩.

  .kiro/projects/<slug>/ 를 만들고 project.md 템플릿과 빈 채팅 목차를 넣는다.
  projects/index.md 에 항목을 추가하고, 기본적으로 그 프로젝트를 활성화한다.

  사용 예:
    .\.kiro\scripts\new-project.ps1 -Name "USB 복구 도구" -Goal "Samsung USB 복구 스크립트 정리"
    .\.kiro\scripts\new-project.ps1 -Name "문서 파서" -Slug doc-parser -NoActivate

  설계 의도:
  - slug 에 한글을 허용한다. 워크스페이스 경로 자체가 한글이고 NTFS·git 모두
    처리하므로, 영문 slug 를 강제하면 사용자가 매번 작명 비용을 낸다.
    파일시스템에서 금지된 문자와 공백만 치환한다.
  - 템플릿은 비워두지 않고 "무엇을 적어야 하는지"를 주석으로 남긴다. 빈 섹션은
    매 세션 주입 컨텍스트만 잡아먹는다.
  - .md 는 BOM 없이 쓴다. git diff 를 더럽히지 않게.
    (이 .ps1 자체는 한글 리터럴 때문에 BOM 포함으로 저장해야 한다 — PowerShell
    5.1 은 BOM 없는 .ps1 을 ANSI 로 파싱한다.)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$Slug,

    [string]$Goal = '',

    [switch]$NoActivate
)

$ErrorActionPreference = 'Stop'

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-TextFile([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function ConvertTo-Slug([string]$Text) {
    $s = $Text.Trim().ToLowerInvariant()
    # 파일시스템 금지 문자와 점을 먼저 제거
    $s = $s -replace '[<>:"/\\|?*\.]', ''
    # 공백 묶음을 하이픈으로
    $s = $s -replace '\s+', '-'
    # 한글·영숫자·하이픈·밑줄만 남긴다
    $s = $s -replace '[^\p{L}\p{Nd}\-_]', ''
    $s = $s -replace '-{2,}', '-'
    return $s.Trim('-', '_')
}

$projectsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'projects'
if (-not (Test-Path -LiteralPath $projectsDir)) {
    $null = New-Item -ItemType Directory -Path $projectsDir
}

if (-not $Slug) { $Slug = ConvertTo-Slug $Name }
else            { $Slug = ConvertTo-Slug $Slug }

if (-not $Slug) {
    throw "'$Name' 에서 쓸 수 있는 slug 를 만들 수 없다. -Slug 로 직접 지정할 것."
}

$projectDir = Join-Path $projectsDir $Slug
if (Test-Path -LiteralPath $projectDir) {
    throw "프로젝트 '$Slug' 가 이미 있다: $projectDir"
}

$null = New-Item -ItemType Directory -Path $projectDir
$null = New-Item -ItemType Directory -Path (Join-Path $projectDir 'chats')

$today = Get-Date -Format 'yyyy-MM-dd'

$goalLine = if ($Goal) { $Goal } else { '<한 줄로. 이 프로젝트가 끝났다고 말할 수 있는 조건>' }

$projectMd = @"
# $Name

- slug: ``$Slug``
- 생성: $today

## 목표

$goalLine

## 범위

포함: <이 프로젝트가 다루는 것>
제외: <명시적으로 다루지 않는 것. 범위 밖 요청이 오면 확인받는다>

## 제약

- <기술 스택, 버전, 지키거나 건드리면 안 되는 것>

## 용어

- <이 주제에서만 통하는 약어나 도메인 용어. 없으면 이 섹션을 지운다>

## 참조

- <관련 파일·디렉터리 경로, 외부 문서 링크>

---

이 파일은 매 세션 시작 시 컨텍스트로 주입된다. 짧게 유지한다.
길어지면 별도 파일로 분리하고 위 "참조"에 경로만 남긴다.
"@

Write-TextFile (Join-Path $projectDir 'project.md') $projectMd

$chatIndexMd = @"
# $Name — 채팅 목차

최신이 위. 각 항목은 ``chats/`` 의 기록으로 연결된다.

<!-- 목록 시작 -->
"@

Write-TextFile (Join-Path $projectDir 'index.md') $chatIndexMd

# projects/index.md 갱신. 없으면 만들고, 있으면 마커 아래에 한 줄 추가한다.
$rootIndexPath = Join-Path $projectsDir 'index.md'
$marker = '<!-- 목록 시작 -->'
$entry  = "- [$Name]($Slug/index.md) — ``$Slug`` · 생성 $today"

if (-not (Test-Path -LiteralPath $rootIndexPath)) {
    $rootIndexMd = @"
# 프로젝트 목록

최신이 위. 활성 프로젝트는 ``ACTIVE`` 파일이 가리킨다.
전환은 ``.kiro\scripts\use-project.ps1 -Slug <slug>``.

$marker
$entry
"@
    Write-TextFile $rootIndexPath $rootIndexMd
}
else {
    $lines = [System.Collections.Generic.List[string]](
        (Get-Content -LiteralPath $rootIndexPath -Raw -Encoding UTF8) -replace "`r", '' -split "`n"
    )
    $at = $lines.IndexOf($marker)
    if ($at -ge 0) { $lines.Insert($at + 1, $entry) }
    else           { $lines.Add($entry) }
    Write-TextFile $rootIndexPath (($lines -join "`n").TrimEnd() + "`n")
}

if (-not $NoActivate) {
    Write-TextFile (Join-Path $projectsDir 'ACTIVE') ($Slug + "`n")
}

Write-Host "프로젝트 생성: $Slug"
Write-Host "  경로   : .kiro\projects\$Slug"
Write-Host "  정의   : .kiro\projects\$Slug\project.md  (범위·제약·용어를 채울 것)"
if (-not $NoActivate) { Write-Host "  활성화 : 예 (ACTIVE -> $Slug)" }
else                  { Write-Host "  활성화 : 아니오 (-NoActivate)" }
Write-Host ''
Write-Host '다음 세션 시작 시 이 프로젝트의 정의와 최근 채팅이 컨텍스트로 주입된다.'
