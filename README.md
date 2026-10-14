# gpt2kiro

GPT를 사용할 수 없는 환경에서 **Kiro를 GPT처럼 편하게 사용하기 위한 Memory/Context 설정**입니다.

핵심 목표는 하나입니다.

> **설치한 뒤 Kiro를 열고 그냥 대화하면, 이전 작업의 중요한 맥락을 이어서 사용할 수 있게 한다.**

GPT의 모든 제품 기능을 복제하지 않습니다. 복잡한 프로젝트 관리 대신 **Instructions + Memory + Relevant Retrieval + Security**에 집중합니다.

## 시작하기

```powershell
git clone https://github.com/medialog-AX-TF/gpt2kiro.git
cd gpt2kiro
.\setup.ps1
```

`Errors: 0`이 나오면 설치가 끝났습니다.

이후 같은 workspace에서 **Kiro를 열고 평소처럼 대화하면 됩니다.**

별도의 프로젝트 생성, ACTIVE 선택, 기억 관리 명령은 필요하지 않습니다.

## 무엇을 해주나요?

| 기능 | 설명 |
|---|---|
| Instructions | Kiro가 항상 따라야 할 기본 행동·보안 규칙 유지 |
| Recent Memory | 최근 작업 내용을 세션 시작 시 자동으로 불러옴 |
| Long-term Memory | 오래된 중요한 맥락을 압축해 유지 |
| Relevant Retrieval | 과거 내용이 필요하면 관련 기억을 찾아 참고 |
| Lessons | 반복하지 말아야 할 실수와 환경 특이사항 유지 |
| Context Budget | 기억이 늘어도 자동 주입량을 제한 |
| Sanitizer | Token, 이메일, 전화번호, IP 등 민감정보를 저장 전에 정제 |

## 동작 방식

```text
Kiro 시작
   ↓
SessionStart Hook
   ↓
load-context.ps1
   ├─ Lessons
   ├─ Recent Memory
   └─ Long-term Memory
   ↓
Context Budget
   ↓
Kiro / LLM

과거 맥락이 더 필요할 때
   ↓
search-memory.ps1
   ↓
관련 Memory만 참고

중요한 작업이 끝났을 때
   ↓
write-memory.ps1
   ↓
sanitize-memory.ps1
   ↓
memory/YYYY-MM-DD.md
```

> **최근 기억은 자동으로 넣고, 오래된 기억은 필요할 때 찾고, 새 기억은 안전하게 저장합니다.**

## 사용 예

어제 Kiro와 OpenClaw WSS 오류를 해결했다면 중요한 결과가 Memory에 남습니다.

다음 날 새 세션에서:

```text
사용자: 어제 WSS 오류 해결한 내용 이어서 보자.
```

Kiro는 최근 Memory 또는 관련 과거 Memory를 참고해 작업을 이어갑니다.
사용자가 Memory 파일이나 검색 명령을 직접 관리할 필요는 없습니다.

## 내부 구조

```text
.kiro/
├─ context-budget.json
├─ steering/                  Kiro 기본 규칙
├─ memory/
│  ├─ lessons.md              반복 적용할 교훈
│  ├─ long-term.md            장기 기억
│  ├─ weekly/                 오래된 기억의 주간 요약
│  └─ YYYY-MM-DD.md           작업 기억
├─ hooks/
│  └─ load-context.json       SessionStart 자동 실행
└─ scripts/
   ├─ load-context.ps1        Context 구성
   ├─ search-memory.ps1       과거 관련 기억 검색
   ├─ write-memory.ps1        기억 저장
   ├─ sanitize-memory.ps1     민감정보 정제
   ├─ apply-context-budget.ps1
   └─ consolidate-memory.ps1
```

이 구조는 내부 구현입니다. 일반 사용자는 `setup.ps1`만 실행하면 됩니다.

## 보안 원칙

Memory는 **과거 참고 데이터**이지 실행 명령이 아닙니다.

```text
Platform / Security
        ↓
Steering
        ↓
Lessons
        ↓
Historical Memory
        ↓
External Content
```

과거 Memory나 외부 문서에 `이전 지시를 무시하라` 같은 문장이 있어도 현재 행동 규칙으로 사용하지 않습니다.
Memory 저장 시 민감정보는 `sanitize-memory.ps1`을 거칩니다.

```text
Memory Read  → Fail Open
Memory Write → Fail Closed
```

기억을 읽지 못해도 Kiro 사용은 계속되지만, 안전하게 정제하지 못한 기억은 저장하지 않습니다.

## 점검

필요할 때만 다음 명령으로 상태를 확인할 수 있습니다.

```powershell
.\validate.ps1
```

정상 예:

```text
[OK] required files, budget, and unified hook checks passed.
Errors: 0, Warnings: 0
```

## 설계 철학

`gpt2kiro`는 ChatGPT 내부 구현을 복제하는 프로젝트가 아닙니다.

**GPT를 사용할 수 없는 환경에서도 Kiro를 열고 그냥 대화하면 이전 작업의 중요한 맥락을 자연스럽게 이어가는 경험**을 만드는 것이 목표입니다.
