# Kiro 설정 체계

- slug: `kiro-config`
- 생성: 2026-10-13

## 목표

Kiro를 ChatGPT·Claude 채팅처럼 **단일 에이전트 대화형 조수**로 운용하기 위한
`.kiro` 설정을 설계하고 유지한다. 세션 간 기억·학습·주제별 이력을 파일로 남겨
"세션 간 기억이 없다"는 제약을 실용적으로 메운다.

## 범위

포함: `.kiro/steering`, `.kiro/memory`, `.kiro/projects`, `.kiro/hooks`,
`.kiro/scripts`. 이 설정들을 다른 워크스페이스로 옮기기 위한 문서(`README.md`).

제외: 이 레포에는 빌드·테스트 대상 애플리케이션 코드가 없다. 그런 코드를
만들자는 요청은 범위 밖이므로 확인받는다.

## 제약

- 원격: `https://github.com/medialog-AX-TF/gpt2kiro` (private, 기본 브랜치 `main`)
- Windows / PowerShell 5.1. 명령은 PowerShell 문법 (`;`, `$env:VAR`).
- 워크스페이스 경로 `e:\DEV\새 폴더` 에 공백과 한글이 있다. 경로는 항상 큰따옴표로.
- 한글이 든 `.ps1` 은 **UTF-8 BOM 포함**으로 저장한다. BOM이 없으면 5.1 이
  ANSI(cp949)로 파싱해 스크립트 내 한글 리터럴이 깨진다.
- 훅 스크립트가 stdout으로 한글을 내보낼 때는 `Write-Output` 을 쓰지 않고
  UTF-8 바이트를 표준 출력 스트림에 직접 쓴다.
- 훅 JSON의 `command` 는 절대경로다. 훅 실행 시 cwd를 확신할 수 없다.
  그래서 머신 종속이며, 다른 환경으로 옮길 때 반드시 고쳐야 한다.

## 용어

- **steering**: `.kiro/steering/*.md`. front-matter가 없으면 모든 대화에 주입된다.
- **주입(injection)**: `SessionStart` 훅이 exit 0 으로 낸 stdout이 세션 컨텍스트에
  들어가는 것. steering의 "읽어라"는 지침이지만 주입은 강제다.

## 참조

- `README.md` — 구성 전체와 다른 환경으로 옮길 때의 주의사항
- `.kiro/memory/lessons.md` — 이 환경에서 반복해 걸린 함정들
- `.kiro/scripts/load-memory.ps1`, `load-project.ps1` — 두 개의 SessionStart 훅

---

이 파일은 매 세션 시작 시 컨텍스트로 주입된다. 짧게 유지한다.
길어지면 별도 파일로 분리하고 위 "참조"에 경로만 남긴다.
