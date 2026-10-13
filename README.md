# gpt2kiro

Kiro를 ChatGPT·Claude처럼 **단일 대화형 조수 + 장기 기억 + 프로젝트 컨텍스트** 방식으로 운용하기 위한 `.kiro` 설정 프레임워크다.

GPT 모델 자체를 구현하는 프로젝트가 아니라, ChatGPT의 **Instructions / Memory / Projects / Context Retrieval**에 가까운 사용 구조를 Kiro 위에 만든다.

## 핵심 구조

```text
.kiro/
├─ context-budget.json        동적 컨텍스트 예산
├─ steering/
│  ├─ security.md             신뢰 계층·prompt injection 방어
│  ├─ retrieval.md            관련 기억 검색 규칙
│  ├─ identity.md
│  ├─ direct-mode.md
│  ├─ response-style.md
│  ├─ memory.md
│  ├─ learning.md
│  └─ projects.md
├─ memory/
│  ├─ index.md
│  ├─ lessons.md
│  ├─ long-term.md            consolidation 결과(생성 시)
│  ├─ weekly/                 consolidation 결과(생성 시)
│  └─ YYYY-MM-DD.md
├─ projects/
│  ├─ ACTIVE
│  ├─ index.md
│  └─ <slug>/
│     ├─ project.md
│     ├─ index.md
│     └─ chats/
├─ hooks/
│  └─ load-context.json       단일 SessionStart hook
└─ scripts/
   ├─ load-context.ps1        통합 Context Builder
   ├─ apply-context-budget.ps1
   ├─ search-memory.ps1       Relevant Memory Retrieval
   ├─ write-memory.ps1        Memory Write Gateway
   ├─ sanitize-memory.ps1
   ├─ consolidate-memory.ps1  Daily → Weekly → Long-term
   ├─ load-memory.ps1         legacy compatibility
   ├─ load-project.ps1        legacy compatibility
   ├─ new-project.ps1
   └─ use-project.ps1
```

## 동작 원리

```text
SessionStart
    ↓
load-context.ps1
    ├─ lessons
    ├─ long-term memory
    ├─ recent daily memory
    └─ active project
    ↓
apply-context-budget.ps1
    ↓
Budgeted Dynamic Context
    ↓
Kiro / LLM

사용자 요청 도착 후 과거 맥락이 필요하면
    ↓
search-memory.ps1
    ↓
Relevant older memory
```

즉 **항상 필요한 문맥은 SessionStart에서 제한적으로 넣고, 오래된 기억은 질문과 관련될 때만 검색**한다.

## Context Budget

기본값은 `.kiro/context-budget.json` 에 있다.

```json
{
  "approxCharsPerToken": 4,
  "totalTokens": 7000,
  "sections": {
    "lessons": 1200,
    "longTerm": 1000,
    "recentMemory": 1800,
    "project": 3000
  }
}
```

정확한 tokenizer 없이도 동작하게 문자수 기반 token 근사를 쓴다. 실제 모델의 전체 context window가 아니라 **gpt2kiro가 자동 주입하는 동적 기억 영역의 예산**이다.

## Memory 저장

Memory 파일을 직접 쓰지 않고 Gateway를 사용한다.

```powershell
.\.kiro\scripts\write-memory.ps1 `
  -Topic "작업 주제" `
  -Context "배경" `
  -Work "한 일" `
  -Decision "결정" `
  -Validation "검증" `
  -Remaining "남은 일"
```

저장 전에 `sanitize-memory.ps1` 이 secret·이메일·전화번호·IP·계정 식별 형태를 정제한다.
쓰기 경로는 **fail-closed**, 읽기 경로는 **fail-open**이다.

## Relevant Memory Search

최근 기록에 없는 과거 작업이 필요할 때:

```powershell
.\.kiro\scripts\search-memory.ps1 -Query "OpenClaw Docker WSS" -Top 5
```

현재 구현은 외부 embedding 없이 키워드 출현·고유 term 매칭·최근성 보너스로 순위를 계산한다.

## Memory Consolidation

오래된 daily memory는 다음 명령으로 압축한다.

```powershell
.\.kiro\scripts\consolidate-memory.ps1 -OlderThanDays 7
```

흐름:

```text
memory/YYYY-MM-DD.md
       ↓
memory/weekly/YYYY-Www.md
       ↓
memory/long-term.md
```

원본 daily 파일은 삭제하지 않는다. Weekly/Long-term은 컨텍스트 절약과 검색을 위한 파생 데이터다.

## 프로젝트

```powershell
# 생성 + 활성화
.\.kiro\scripts\new-project.ps1 -Name "표시 이름" -Goal "한 줄 목표"

# 목록
.\.kiro\scripts\use-project.ps1 -List

# 전환 / 해제
.\.kiro\scripts\use-project.ps1 -Slug <slug>
.\.kiro\scripts\use-project.ps1 -Clear
```

`ACTIVE`는 자동 추정하지 않는다. 잘못된 프로젝트에 기억이 쌓이는 것을 막기 위해 사용자가 명시적으로 전환한다.

## 설치

clone 또는 복사 후 한 번 실행한다.

```powershell
.\install.ps1
.\validate.ps1
```

`install.ps1`은 `load-context.json`의 command를 현재 workspace의 `load-context.ps1` 절대경로로 갱신한다.

## 보안 / 신뢰 계층

Memory와 project chat은 **명령이 아니라 historical reference data**다.

개념적 우선순위:

```text
Platform / Security
    ↓
Steering
    ↓
Project definition
    ↓
Lessons
    ↓
Historical memory
    ↓
External content
```

과거 기억이나 외부 문서 안의 "이전 지시를 무시하라" 같은 문장은 실행 규칙으로 승격하지 않는다.

## 검증

GitHub Actions에서 다음을 검사한다.

- 모든 PowerShell 스크립트 파싱
- unified hook 설치 및 workspace validation
- sanitizer smoke test
- write-memory gateway smoke test
- unified Context Builder 예산 검사
- memory consolidation dry-run
- relevant memory search smoke test

로컬에서도:

```powershell
.\validate.ps1
```

로 구조·예산·hook·민감정보 후보를 확인할 수 있다.

## 설계 철학

- **Recent + Relevant**: 최근 기억은 자동, 오래된 기억은 관련될 때 검색
- **Episodic + Semantic**: daily 작업 기록과 lessons/long-term을 분리
- **Bounded Context**: 기억이 늘어도 자동 주입량은 제한
- **Fail-open read / Fail-closed write**: 기억 장애가 세션을 막지는 않지만 안전하지 않은 기억은 저장하지 않음
- **Source-preserving consolidation**: 압축본을 만들되 원본 기록은 보존
- **Portable memory layer**: 장기적으로 Kiro뿐 아니라 다른 Agent/LLM에도 재사용 가능한 구조를 지향
