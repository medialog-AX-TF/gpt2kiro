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
│  ├─ learning.md             교훈 승격 기준, 중복 관리, steering 승격 규칙
│  └─ projects.md             주제별 프로젝트의 구조·기록 위치·전환 규칙
├─ memory/                    시간 축
│  ├─ index.md                기억 목차 (최신이 위). 프로젝트 기록은 포인터만
│  ├─ lessons.md              누적 교훈. 매 세션 읽힌다. 항상 전역
│  └─ YYYY-MM-DD.md           활성 프로젝트가 없을 때의 작업 기록
├─ projects/                  주제 축
│  ├─ ACTIVE                  활성 프로젝트 slug 한 줄. 비면 활성 없음
│  ├─ index.md                프로젝트 목록
│  └─ <slug>/
│     ├─ project.md           목표·범위·제약·용어·참조. 매 세션 주입된다
│     ├─ index.md             이 프로젝트의 채팅 목차
│     └─ chats/
│        └─ YYYY-MM-DD-*.md   세션 기록
├─ hooks/
│  ├─ load-memory.json        SessionStart 훅 정의
│  └─ load-project.json       SessionStart 훅 정의
└─ scripts/
   ├─ load-memory.ps1         기억 파일을 세션 컨텍스트로 주입
   ├─ load-project.ps1        활성 프로젝트를 세션 컨텍스트로 주입
   ├─ new-project.ps1         프로젝트 스캐폴딩
   └─ use-project.ps1         활성 프로젝트 전환 / 목록 / 해제
```

## 프로젝트 사용법

ChatGPT 의 Projects 에 대응한다. 한 주제의 정의와 채팅 이력을 한 디렉터리에
모아두고, 활성인 동안 매 세션 시작 시 주입한다.

```powershell
# 생성 (생성과 동시에 활성화됨)
.\.kiro\scripts\new-project.ps1 -Name "표시 이름" -Goal "한 줄 목표"

# 목록 — 활성 프로젝트에 * 표시, 채팅 건수 표시
.\.kiro\scripts\use-project.ps1 -List

# 전환 / 해제
.\.kiro\scripts\use-project.ps1 -Slug <slug>
.\.kiro\scripts\use-project.ps1 -Clear
```

`-Slug` 를 주지 않으면 `-Name` 에서 파생한다. 한글 slug 를 허용하고,
파일시스템 금지 문자와 공백만 치환한다 (`"테스트 프로젝트 (임시)"` →
`테스트-프로젝트-임시`).

전환은 `ACTIVE` 파일 한 줄을 바꾸는 것이 전부다. **현재 진행 중인 세션의
컨텍스트는 바뀌지 않는다** — 다음 세션 시작 시 적용된다.

## 설계 의도

**두 개의 축, 하나의 기록.** `memory/` 는 시간 축, `projects/` 는 주제 축이다.
날짜 축만으로는 "그 주제에 대해 지금까지 뭘 했나"를 모아 읽을 수 없고, 주제 축만
두면 프로젝트에 속하지 않는 일회성 작업이 떠돌게 된다. 그래서 둘 다 두되 기록은
한 곳에만 쓴다 — 활성 프로젝트가 있으면 `projects/<slug>/chats/`, 없으면
`memory/YYYY-MM-DD.md`. `memory/index.md` 에는 포인터 한 줄만 남긴다.
양쪽에 전문을 쓰는 안은 버렸다. 반드시 어긋나고, 어긋난 기록은 없는 기록보다 나쁘다.

**자동 전환 없음.** 활성 프로젝트가 없으면 `load-project.ps1` 은 프로젝트 "목록"만
주입하고 전환 여부는 사용자에게 묻게 한다. 요청 내용으로 추측해 전환하면 엉뚱한
프로젝트에 기록이 쌓이고, 그걸 나중에 발견해도 되돌리기 번거롭다.

**전사(transcript)를 자동 수집하지 않는다.** ChatGPT 와 달리 대화 원문을 쌓지 않고
내가 쓰는 요약 기록만 남긴다. `Stop` 훅 stdin JSON 에 대화 원문이 들어 있는지
확인하지 못했고, 확인되지 않은 것에 기능을 걸지 않았다. 채팅 기록 형식의
`요청`·`진행` 항목이 그 성격을 대신한다 — 결과만 남기면 "왜 이렇게 됐는지"를
다음 세션의 내가 복원할 수 없다.

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
`.kiro/hooks/load-memory.json` 과 `load-project.json` 의 `command` 가 절대경로로
박혀 있다. 훅 실행 시 cwd를 확신할 수 없어서 상대경로를 피한 결과이며, 그래서
머신 종속이다. 두 파일 모두 고쳐야 한다.

```json
"command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<워크스페이스>\\.kiro\\scripts\\load-memory.ps1\""
```

**2. `.ps1` 의 UTF-8 BOM**
`scripts/` 의 `.ps1` 은 모두 UTF-8 **BOM 포함**으로 저장돼 있다. PowerShell 5.1 은
BOM 없는 `.ps1` 을 ANSI(한국어 Windows = cp949)로 파싱해서 스크립트 안의 한글
리터럴이 깨진다. 편집기나 도구가 BOM을 떼고 저장하면 복원해야 한다.

```powershell
Get-ChildItem .\.kiro\scripts\*.ps1 | ForEach-Object {
    $c = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    [System.IO.File]::WriteAllText($_.FullName, $c, (New-Object System.Text.UTF8Encoding($true)))
}
```

선두 3바이트가 `EF BB BF` 인지로 확인한다.

비(非)Windows 환경에서는 `load-memory.ps1` 을 셸 스크립트로 포팅하고 훅의
`command` 를 그에 맞게 바꿔야 한다.

## 검증 상태

스크립트 동작은 확인됐다 — stdout 바이트를 UTF-8로 디코딩해 exit 0, 한글 정상,
상한 내 출력. `new-project.ps1` 은 `index.md` 생성 경로와 마커 삽입 경로 둘 다,
`load-project.ps1` 은 활성 프로젝트가 있을 때와 없을 때 두 분기 모두 확인했다.
`use-project.ps1` 의 `-List` / `-Slug` / `-Clear` 도 확인.

훅 트리거의 실제 발화는 다음 세션 시작 시점에만 확인 가능하다. `SessionStart`
훅이 두 개(`load-memory`, `load-project`)이므로 **둘 다 주입되는지**가 아직
미검증이다. 하나만 발화하면 두 스크립트를 하나로 합치는 쪽으로 간다.
