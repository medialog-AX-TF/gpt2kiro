<#
  SessionStart 훅용 스크립트.

  .kiro/projects/ACTIVE 가 가리키는 프로젝트의 정의·채팅 목차·최근 채팅을
  stdout으로 내보낸다. SessionStart 훅은 exit 0 일 때 stdout을 세션 컨텍스트로
  전달하므로, 이 출력이 매 세션 시작 시 모델 컨텍스트에 들어간다.

  설계 의도:
  - load-memory.ps1 과 같은 규칙을 따른다. 실패해도 세션을 막지 않고, 출력에
    상한을 두고, 최근 것만 주입하고 전체는 index.md 로 가리킨다.
  - 활성 프로젝트가 없어도 프로젝트가 존재하면 목록만 알린다. 그래야 모델이
    "프로젝트가 있다는 사실"을 알고 사용자에게 활성화를 물어볼 수 있다.
  - 자동 전환은 하지 않는다. ACTIVE 는 사용자의 명시적 선택이다.

  인코딩 주의:
  Write-Output 은 PowerShell 5.1 에서 콘솔 코드페이지(한국어 Windows 는 949)로
  stdout을 인코딩해 한글이 깨진다. UTF-8 바이트를 표준 출력 스트림에 직접 쓴다.
  이 스크립트 파일 자체도 UTF-8 BOM 포함으로 저장해야 한다 (BOM 없으면 5.1 이
  ANSI 로 파싱해 아래 한글 리터럴이 깨진다).
#>

$ErrorActionPreference = 'SilentlyContinue'

# 훅은 stdin으로 세션 컨텍스트 JSON을 넘긴다. 이 스크립트는 쓰지 않으므로 버린다.
try { $null = $input } catch { }

$RecentChats = 2
$MaxChars    = 14000

function Write-Utf8Stdout([string]$Text) {
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $stream = [Console]::OpenStandardOutput()
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
}

try {
    # $PSScriptRoot = <workspace>\.kiro\scripts  ->  <workspace>\.kiro\projects
    $projectsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'projects'
    if (-not (Test-Path -LiteralPath $projectsDir)) { exit 0 }

    # 점으로 시작하는 디렉터리는 내부용(.probe 등)이므로 프로젝트로 보지 않는다
    $available = @(Get-ChildItem -LiteralPath $projectsDir -Directory |
                   Where-Object { $_.Name -notlike '.*' } |
                   Sort-Object Name |
                   Select-Object -ExpandProperty Name)
    if ($available.Count -eq 0) { exit 0 }

    $slug = ''
    $activePath = Join-Path $projectsDir 'ACTIVE'
    if (Test-Path -LiteralPath $activePath) {
        $raw = Get-Content -LiteralPath $activePath -Raw -Encoding UTF8
        if ($raw) {
            $slug = (($raw -replace "`r", '') -split "`n" |
                     Where-Object { $_.Trim() -ne '' } |
                     Select-Object -First 1)
            if ($slug) { $slug = $slug.Trim() }
        }
    }

    # 활성 프로젝트가 없거나 ACTIVE 가 존재하지 않는 slug 를 가리키는 경우
    if (-not $slug -or ($available -notcontains $slug)) {
        $lines = @('=== 프로젝트 (.kiro/projects) ===')
        if ($slug) {
            $lines += "ACTIVE 가 '$slug' 를 가리키지만 그런 프로젝트 디렉터리가 없다."
        }
        $lines += '활성 프로젝트가 없다. 사용 가능한 프로젝트:'
        $lines += ($available | ForEach-Object { "  - $_" })
        $lines += ''
        $lines += '사용자의 요청이 위 중 하나와 명백히 관련되면 활성화할지 물어볼 것.'
        $lines += '조용히 전환하지 말 것. 이번 세션만 참고하려면 해당 디렉터리를 직접 읽을 것.'
        $lines += '=== 프로젝트 끝 ==='
        $lines += ''
        Write-Utf8Stdout (($lines -join "`n"))
        exit 0
    }

    $projectDir = Join-Path $projectsDir $slug
    $parts = @()

    $defPath = Join-Path $projectDir 'project.md'
    if (Test-Path -LiteralPath $defPath) {
        $parts += "[프로젝트 정의: projects/$slug/project.md]`n" +
                  (Get-Content -LiteralPath $defPath -Raw -Encoding UTF8).TrimEnd()
    }

    $idxPath = Join-Path $projectDir 'index.md'
    if (Test-Path -LiteralPath $idxPath) {
        $parts += "[채팅 목차: projects/$slug/index.md]`n" +
                  (Get-Content -LiteralPath $idxPath -Raw -Encoding UTF8).TrimEnd()
    }

    # 파일명이 YYYY-MM-DD- 로 시작하므로 이름 역순 = 날짜 역순
    $chatsDir = Join-Path $projectDir 'chats'
    if (Test-Path -LiteralPath $chatsDir) {
        $recent = @(Get-ChildItem -LiteralPath $chatsDir -Filter '*.md' -File |
                    Sort-Object Name -Descending |
                    Select-Object -First $RecentChats)
        foreach ($f in $recent) {
            $parts += "[최근 채팅: projects/$slug/chats/$($f.Name)]`n" +
                      (Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8).TrimEnd()
        }
    }

    if ($parts.Count -eq 0) { exit 0 }

    $body = $parts -join "`n`n---`n`n"
    if ($body.Length -gt $MaxChars) {
        $body = $body.Substring(0, $MaxChars) +
                "`n`n[...상한 $MaxChars 자 초과로 잘림. 전체는 .kiro/projects/$slug/ 에서 직접 읽을 것]"
    }

    $others = @($available | Where-Object { $_ -ne $slug })
    $header = @(
        "=== 활성 프로젝트: $slug (.kiro/projects/$slug) ==="
        '이 주제의 정의와 이전 채팅 이력이다. 현재 코드와 어긋나면 코드가 맞다.'
        '세션 기록은 이 프로젝트의 chats/ 에 쓴다. memory/YYYY-MM-DD.md 에 중복 기록하지 말 것.'
        '이 블록을 읽었다고 사용자에게 보고하지 말고 바로 본론으로 들어갈 것.'
    )
    if ($others.Count -gt 0) {
        $header += ('다른 프로젝트: ' + ($others -join ', ') + ' (전환은 사용자 요청 시에만)')
    }
    $header += ''

    Write-Utf8Stdout (($header -join "`n") + $body + "`n`n=== 활성 프로젝트 끝 ===`n")
}
catch {
    # 프로젝트 로딩 실패가 세션 시작을 막아선 안 된다
}

exit 0
