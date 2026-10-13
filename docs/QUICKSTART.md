# gpt2kiro 1분 시작 가이드

처음 사용하는 사람은 아래 순서만 따라 하면 됩니다.

## 1. 저장소를 준비합니다

```powershell
git clone https://github.com/medialog-AX-TF/gpt2kiro.git
cd gpt2kiro
```

이미 파일을 복사해 둔 경우에는 해당 폴더에서 PowerShell을 열면 됩니다.

## 2. 가장 쉬운 방법: Setup Wizard

```powershell
.\setup.ps1
```

Wizard가 자동으로 다음 작업을 합니다.

1. Kiro SessionStart hook 설치
2. 설정 검증
3. 원하면 첫 프로젝트 생성

## 3. 수동 설치를 원하면

```powershell
.\install.ps1
.\validate.ps1
```

마지막에 `Errors: 0`이 나오면 기본 설치는 정상입니다.

## 4. 첫 프로젝트 만들기

```powershell
.\.kiro\scripts\new-project.ps1 `
  -Name "내 첫 프로젝트" `
  -Goal "이 프로젝트에서 해결하고 싶은 목표"
```

생성된 프로젝트는 자동으로 활성화됩니다.

## 5. Kiro를 열고 대화합니다

이제 같은 workspace에서 Kiro를 시작하면 SessionStart 시 다음 정보가 자동으로 들어갑니다.

- 중요한 교훈
- 최근 기억
- 장기 기억
- 현재 활성 프로젝트

오래된 기억은 필요할 때 관련도 검색으로 찾습니다.

## 자주 쓰는 명령 5개

```powershell
# 전체 상태 확인
.\validate.ps1

# 프로젝트 목록
.\.kiro\scripts\use-project.ps1 -List

# 프로젝트 전환
.\.kiro\scripts\use-project.ps1 -Slug <slug>

# 과거 기억 검색
.\.kiro\scripts\search-memory.ps1 -Query "찾고 싶은 내용" -Top 5

# 오래된 기억 압축
.\.kiro\scripts\consolidate-memory.ps1 -OlderThanDays 7
```

## 문제가 생기면

먼저 아래 두 명령을 다시 실행하세요.

```powershell
.\install.ps1
.\validate.ps1
```

- `ERROR`가 있으면 먼저 해결해야 합니다.
- `WARN`은 동작은 가능하지만 확인이 필요한 항목입니다.

자세한 설명은 루트의 `README.md`를 참고하세요.
