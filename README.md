# gpt2kiro

GPT를 사용할 수 없는 환경에서 **Kiro를 GPT처럼 편하게 사용하기 위한 Memory/Context 설정**입니다.

> **설치한 뒤 Kiro를 열고 그냥 대화하면 됩니다.**

## 30초 시작

```powershell
git clone https://github.com/medialog-AX-TF/gpt2kiro.git
cd gpt2kiro
.\setup.ps1
```

`Errors: 0`이 나오면 설치 완료입니다.

그다음 같은 workspace에서 **Kiro를 열고 평소처럼 대화하세요.**

별도의 Project 생성, ACTIVE 선택, Memory 관리 명령은 필요하지 않습니다.

## 무엇이 달라지나요?

| 기능 | 동작 |
|---|---|
| 최근 기억 | 최근 작업을 세션 시작 시 자동으로 불러옴 |
| 과거 기억 | 필요할 때 관련 Memory만 검색 |
| 중요한 결정 | 다음 세션에서 쓸 가치가 있으면 자동 기록 |
| Lessons | 반복하지 말아야 할 실수와 환경 특이사항 유지 |
| 보안 | Token·이메일·전화번호·IP 등 민감정보를 저장 전에 정제 |
| Context 관리 | 기억이 늘어도 자동 주입량을 제한 |

## 사용 예

어제 Kiro와 WSS 오류를 해결했다면 다음 날 이렇게 말하면 됩니다.

```text
어제 WSS 오류 해결한 내용 이어서 보자.
```

Kiro가 최근 Memory 또는 관련 과거 기록을 참고해 이어서 작업합니다.

## 내부 동작

```text
Kiro 시작
   ↓
Lessons + Recent Memory + Long-term Memory
   ↓
Context Budget
   ↓
대화
   ↓
필요하면 과거 Memory 검색
   ↓
중요한 작업은 안전하게 Memory 저장
```

핵심 원칙은 하나입니다.

> **사용자는 대화만 하고, Memory 관리는 Kiro가 맡습니다.**

## 문제가 있을 때

```powershell
.\validate.ps1
```

정상 예:

```text
[OK] required files, budget, and unified hook checks passed.
Errors: 0, Warnings: 0
```

## 프로젝트 목적

`gpt2kiro`는 ChatGPT의 모든 제품 기능을 복제하지 않습니다.

목표는 **GPT를 사용할 수 없는 환경에서도 Kiro를 열고 그냥 대화하면 이전 작업의 중요한 맥락을 자연스럽게 이어가는 경험**을 만드는 것입니다.

기술 구조가 궁금한 경우 `.kiro/steering/`과 `.kiro/scripts/`를 참고하세요.
