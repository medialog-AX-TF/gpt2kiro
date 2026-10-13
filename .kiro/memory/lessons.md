# 누적 교훈

매 세션 시작 시 읽는다. 기록 기준과 형식은 `.kiro/steering/learning.md` 참조.

---

### 모르는 도구 이름은 추측으로 메우지 않고 해석을 밝힌다
- 날짜: 2026-10-13
- 상황: 사용자가 "오픈클로나 GPT 같은 방식"을 요청했으나 "오픈클로"가 어떤 도구인지
  알 수 없었다. 조용히 추측해서 진행하면 틀린 결과물을 내놓게 되는 상황이었다.
- 교훈: 모르는 고유명사가 요청의 핵심일 때, 침묵한 추측은 되돌릴 작업을 만든다.
  작업을 멈추는 대신 해석을 명시하고 진행하면 사용자가 즉시 교정할 수 있다.
- 적용: 핵심 용어를 모를 때는 "이렇게 해석했다"를 첫 문장에 쓰고 진행한다.
  작업 전체를 멈추고 질문만 던지지 않는다.

### 워크스페이스 steering이 사용자·조직 레벨보다 우선한다
- 날짜: 2026-10-13
- 상황: 이 세션에는 상위 레벨에서 온 워크플로 오케스트레이션 규칙이 걸려 있었고,
  사용자는 반대 방향(직접 작업)을 원했다. `.kiro/steering/direct-mode.md` 를
  워크스페이스에 두는 것으로 상쇄됐고, 주입된 규칙에서 우선순위가 확인됐다.
- 교훈: 상위 레벨 규칙을 바꾸려고 `~/.kiro` 나 클라우드 캐시를 건드릴 필요가 없다.
  워크스페이스 파일로 덮으면 된다.
- 적용: 전역 규칙과 충돌하는 요청을 받으면 상위 설정을 수정하지 않고
  `.kiro/steering/` 에 워크스페이스 파일을 추가한다.

### 이 환경은 Windows / PowerShell이다
- 날짜: 2026-10-13
- 상황: 워크스페이스 경로가 `e:\DEV\새 폴더` (한글·공백 포함), 홈은
  `C:\Users\choiss`, 셸은 PowerShell.
- 교훈: bash 문법을 쓰면 실패하거나, 더 나쁘게는 리터럴 문자열로 해석돼
  엉뚱한 파일·폴더를 만든다 (`%TEMP%` 같은 cmd 문법 포함).
- 적용: 명령 구분자는 `;`, 환경변수는 `$env:VAR`, 파일 조작은 `Get-ChildItem` /
  `Remove-Item` / `New-Item`. 한글·공백 포함 경로는 항상 큰따옴표로 감싼다.

### 한글이 든 .ps1 은 UTF-8 BOM으로 저장해야 한다
- 날짜: 2026-10-13
- 상황: `load-memory.ps1` 실행 결과에서 파일을 읽어온 본문은 멀쩡한데 스크립트 안에
  박아둔 한글 문자열 리터럴만 깨져 나왔다. 원인은 PowerShell 5.1 이 BOM 없는 `.ps1`
  을 UTF-8 이 아니라 ANSI(한국어 Windows = cp949)로 파싱하는 것이었다.
- 교훈: 파일 작성 도구는 BOM 없는 UTF-8로 저장한다. 런타임에 `-Encoding UTF8` 로
  읽는 데이터는 괜찮지만, 스크립트 소스 자체의 파싱은 BOM 유무로 갈린다.
  "일부만 깨진다"는 증상은 런타임 인코딩이 아니라 파싱 인코딩을 의심해야 한다.
- 적용: 한글이 포함된 `.ps1` 을 만든 직후 BOM을 붙인다.
  `$c = Get-Content -LiteralPath $p -Raw -Encoding UTF8 ; [System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($true)))`
  검증은 선두 3바이트가 `EF BB BF` 인지 확인.

### PowerShell 5.1 의 stdout은 콘솔 코드페이지로 인코딩된다
- 날짜: 2026-10-13
- 상황: 훅 스크립트에서 `Write-Output` 으로 한글을 내보냈더니 파이프 건너편에서
  깨졌다. `[Console]::OutputEncoding = UTF8` 을 설정해도 해결되지 않았다.
- 교훈: 다른 프로세스가 읽을 stdout에 UTF-8을 보장해야 할 때는 PowerShell의
  텍스트 출력 계층을 신뢰하지 말고 바이트를 직접 쓴다.
- 적용: `$b = [System.Text.Encoding]::UTF8.GetBytes($text)` 후
  `[Console]::OpenStandardOutput()` 스트림에 `.Write($b, 0, $b.Length)` + `.Flush()`.

### Start-Process 의 ArgumentList 배열은 공백 있는 경로를 깨뜨린다
- 날짜: 2026-10-13
- 상황: `-ArgumentList '-File','e:\DEV\새 폴더\...ps1'` 로 호출했더니 PowerShell이
  `-File 'e:\DEV\새'` 까지만 인자로 받아 실패했다. 배열 요소를 공백으로 join할 때
  개별 요소를 따옴표로 감싸주지 않는다.
- 교훈: 워크스페이스 경로 `e:\DEV\새 폴더` 에는 공백이 있어 이 함정에 매번 걸린다.
- 적용: `Start-Process` 에는 인자를 **하나의 문자열**로 넘기고 경로를 내가 직접
  따옴표로 감싼다. `-ArgumentList '-NoProfile -File "e:\DEV\새 폴더\x.ps1"'`
