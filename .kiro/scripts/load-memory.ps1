<#
  SessionStart 훅용 스크립트.

  .kiro/memory/ 의 목차·누적 교훈·최근 날짜 기록을 stdout으로 내보낸다.
  SessionStart 훅은 exit 0 일 때 stdout을 세션 컨텍스트로 전달하므로,
  이 출력이 매 세션 시작 시 모델 컨텍스트에 들어간다.

  설계 의도:
  - 실패해도 세션을 막지 않는다. 어떤 오류든 조용히 exit 0.
  - 출력 크기에 상한을 둔다. 기억이 쌓여도 매 세션 컨텍스트를 잠식하지 않게.
  - 날짜 파일은 최신 2개만. 전체 이력은 index.md 로 가리키고 필요할 때 읽게 한다.

  인코딩 주의:
  Write-Output / Write-Host 는 PowerShell 5.1 에서 콘솔 코드페이지(한국어 Windows
  는 949)로 stdout을 인코딩해 한글이 깨진다. 그래서 문자열을 UTF-8 바이트로 직접
  변환해 표준 출력 스트림에 쓴다. 이 경로는 코드페이지와 무관하다.
#>

$ErrorActionPreference = 'SilentlyContinue'

# 훅은 stdin으로 세션 컨텍스트 JSON을 넘긴다. 이 스크립트는 쓰지 않으므로 버린다.
try { $null = $input } catch { }

# 최근 날짜 파일 개수와 총 출력 상한
$RecentCount = 2
$MaxChars    = 12000

function Write-Utf8Stdout([string]$Text) {
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $stream = [Console]::OpenStandardOutput()
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
}

try {
    # $PSScriptRoot = <workspace>\.kiro\scripts  ->  <workspace>\.kiro\memory
    $memoryDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'memory'
    if (-not (Test-Path -LiteralPath $memoryDir)) { exit 0 }

    $parts = @()

    $indexPath = Join-Path $memoryDir 'index.md'
    if (Test-Path -LiteralPath $indexPath) {
        $parts += (Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8).TrimEnd()
    }

    $lessonsPath = Join-Path $memoryDir 'lessons.md'
    if (Test-Path -LiteralPath $lessonsPath) {
        $parts += (Get-Content -LiteralPath $lessonsPath -Raw -Encoding UTF8).TrimEnd()
    }

    # YYYY-MM-DD.md 형식만 집는다. 이름 역순 = 날짜 역순
    $recent = @(Get-ChildItem -LiteralPath $memoryDir -Filter '????-??-??.md' -File |
                Sort-Object Name -Descending |
                Select-Object -First $RecentCount)

    foreach ($f in $recent) {
        $fileBody = (Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8).TrimEnd()
        $parts += "(최근 기록: $($f.Name))`n$fileBody"
    }

    if ($parts.Count -eq 0) { exit 0 }

    $body = $parts -join "`n`n---`n`n"
    if ($body.Length -gt $MaxChars) {
        $body = $body.Substring(0, $MaxChars) +
                "`n`n[...상한 $MaxChars 자 초과로 잘림. 전체는 .kiro/memory/ 에서 직접 읽을 것]"
    }

    $header = @(
        '=== 이전 세션 기억 (.kiro/memory) ==='
        '과거의 내가 남긴 기록이다. 현재 코드와 어긋나면 코드가 맞다.'
        '이 블록을 읽었다고 사용자에게 보고하지 말고 바로 본론으로 들어갈 것.'
        ''
    ) -join "`n"

    Write-Utf8Stdout ($header + $body + "`n`n=== 기억 끝 ===`n")
}
catch {
    # 기억 로딩 실패가 세션 시작을 막아선 안 된다
}

exit 0
