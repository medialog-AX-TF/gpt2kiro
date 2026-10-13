# gpt2kiro

Kiro를 ChatGPT·Claude 채팅처럼 **단일 에이전트 대화형 조수** 방식으로 운용하기 위한
`.kiro` 설정 모음. 워크플로 위임 대신 직접 읽고 직접 고치게 만들고, 세션 간
기억과 학습을 파일로 유지한다.

## 구성

```
.kiro/
├─ steering/                  모든 대화에 주입되는 규칙 (front-matter 없음 = 항상 포함)
│  ├─ identity.md             정체성: 역할, 아닌 것, 관계 원칙, 언어
│  ├─ direct-mode.md          위임 금지, 직접 읽기·수정·검증, 확인이 필요한 작업 경계
│  ├─ response-style.md       결론 우선, 예고·과장·빈 동의 금지, PowerShell 문법
│  ├─ memory.md               날짜별 기억 파일의 구조·기록 시점·형식·금지사항
│  └─ learning.md             교훈 승격 기준, 중복 관리, steering 승격 규칙
├─ memory/
│  ├─ index.md                기억 목차 (최신이 위)
│  ├─ lessons.md              누적 교훈. 매 세션 읽힌다
│  └─ YYYY-MM-DD.md           날짜별 작업 기록
├─ hooks/
│  └─ load-memory.json        SessionStart 훅 정의
└─ scripts/
   └─ load-memory.ps1         기억 파일을 세션 컨텍스트로 주입하는 스크립트
```

## 설계 의도

**기억과 교훈의 분리.** `YYYY-MM-DD.md` 는 "무슨 일이 있었나"를, `lessons.md` 는
"다음엔 어떻게 할까"를 담는다. 날짜 기록은 쌓이고 결국 안 읽히지만 `lessons.md` 는
매 세션 주입된다. 그래서 교훈 쪽은 승격 기준을 좁게 잡았다 — 사용자 교정, 반복된
실수, 환경 특이사항, 프로젝트 관례, 헛수고. 일반적인 프로그래밍 상식은 넣지 않는다.
넣으면 그 파일이 소음으로 채워져 쓸모없어진다.

**지침이 아니라 강제.** steering에 "세션 시작 시 기억을 읽는다"고 써도 그건 지침일
뿐이다. `SessionStart` 훅으로 stdout을 세션 컨텍스트에 밀어넣어 확실하게 만들었다.

**컨텍스트 상한.** 훅 스크립트는 `index.md` + `lessons.md` + 최근 날짜 파일 2개만,
총 12000자까지 주입한다. 기억이 쌓여도 매 세션 컨텍스트를 잠식하지 않게 한다.
전체 이력은 `index.md` 가 가리키고 필요할 때 직접 읽는다.

**실패해도 막지 않는다.** 스크립트는 모든 오류를 삼키고 `exit 0` 한다. 기억 로딩
실패가 세션 시작을 막아선 안 된다.

## 다른 환경에서 쓸 때

`.kiro` 디렉터리를 대상 워크스페이스 루트에 복사한 뒤 아래 두 가지를 고쳐야 한다.

**1. 훅의 절대경로**
`.kiro/hooks/load-memory.json` 의 `command` 가 절대경로로 박혀 있다. 훅 실행 시
cwd를 확신할 수 없어서 상대경로를 피한 결과이며, 그래서 머신 종속이다.

```json
"command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<워크스페이스>\\.kiro\\scripts\\load-memory.ps1\""
```

**2. `.ps1` 의 UTF-8 BOM**
`load-memory.ps1` 은 UTF-8 **BOM 포함**으로 저장돼 있다. PowerShell 5.1 은 BOM 없는
`.ps1` 을 ANSI(한국어 Windows = cp949)로 파싱해서 스크립트 안의 한글 리터럴이
깨진다. 편집기나 도구가 BOM을 떼고 저장하면 복원해야 한다.

```powershell
$p = '.\.kiro\scripts\load-memory.ps1'
$c = Get-Content -LiteralPath $p -Raw -Encoding UTF8
[System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($true)))
```

선두 3바이트가 `EF BB BF` 인지로 확인한다.

비(非)Windows 환경에서는 `load-memory.ps1` 을 셸 스크립트로 포팅하고 훅의
`command` 를 그에 맞게 바꿔야 한다.

## 검증 상태

스크립트 동작은 확인됐다 — stdout 바이트를 UTF-8로 디코딩해 exit 0, 한글 정상,
상한 내 출력. 훅 트리거의 실제 발화는 다음 세션 시작 시점에만 확인 가능하다.
