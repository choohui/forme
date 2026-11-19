# orchestrate

<!-- 배포 저장소의 README (PLAN_D-O D-O.47). 원본은 소스 저장소의 scripts/release/repo/README.md이고,
     scripts/release.ps1 -Repo <주인>/<저장소>가 저장소 이름 자리를 채워 배포 저장소용 폴더에 복사한다. -->

오늘 · 캘린더 · 할 일 · 가계부 · 읽을 것을 한 화면에 모은 개인 사이트다. 강의와 논문을 읽는 Javis가 함께 들어 있다. 프로그램은 내 PC 안(127.0.0.1)에서만 돌고, 자료는 설치 폴더 밖으로 나가지 않는다.

## 필요한 것

| 무엇 | 비고 |
|---|---|
| Windows 10(1809 이상) 또는 11, 64비트 | |
| 디스크 약 2 GB | Javis 받아쓰기 모델을 받으면 더 |
| 인터넷 | 설치할 때 Node 패키지와 Python 도구를 받는다 |
| Node.js 24, uv | 없으면 설치가 winget으로 받을지 묻는다 |

## 설치

PowerShell을 열고(시작 단추 오른쪽 클릭 → "터미널" 또는 "Windows PowerShell") 아래 한 줄을 붙여 넣는다.

```powershell
irm https://raw.githubusercontent.com/choohui/forme/main/install.ps1 | iex
```

이 한 줄이 하는 일: 최신 판의 zip을 받고 → SHA-256을 맞춰 보고 → `%LOCALAPPDATA%\orchestrate`에 풀고 → `setup.ps1`을 돌린다. 관리자 권한은 쓰지 않는다. 무엇을 실행하는지 먼저 보고 싶으면 [install.ps1](install.ps1)을 읽는다.

스크립트를 바로 실행하고 싶지 않으면 손으로 한다.

1. [Releases](https://github.com/choohui/forme/releases/latest)에서 `orchestrate-<판>.zip`과 `.sha256`을 받는다.
2. `Get-FileHash -Algorithm SHA256 orchestrate-<판>.zip`의 값이 `.sha256` 파일과 같은지 본다.
3. zip을 오래 둘 폴더에 풀고, 그 폴더에서 `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1`.

설치가 끝나면 브라우저에 **처음 안내**가 열린다.

## 처음 안내에서 고르는 것

### 1. 쓰는 방식

| | 이 컴퓨터에서만 | 이 컴퓨터를 서버로 |
|---|---|---|
| 여는 곳 | 이 PC의 브라우저 | 이 PC + 내 다른 컴퓨터 · 폰 |
| 주소 | `http://127.0.0.1:8800` | 다른 기기는 `https://<PC 이름>.<tailnet>.ts.net` |
| 더 받는 것 | 없음 | [Tailscale](https://tailscale.com/)(이 PC와 쓸 기기마다, 무료 개인 요금제) |
| 설정 | 없음 | Tailscale 로그인, 주소 잇기, 자동 시작. 화면의 "설정 창 열기"가 한다 |
| 필수 키 | 없음 | 다른 기기 로그인 비밀번호(직접 정한다) |
| 인터넷에 열림 | 아니다 | 아니다(같은 Tailscale 계정의 기기끼리만) |

나중에 바꿀 수 있다(설정 › 키 › 안내 다시 보기).

### 2. 키

키마다 **필수**인지 **선택**인지, 무엇에 쓰는지, 넣지 않으면 무엇이 비는지 적혀 있다. 입력칸 옆 **상세 설명**을 누르면 그 값을 받는 순서가 펼쳐진다. 값은 Windows 자격 증명 관리자에 암호화되어 들어가고 화면에 다시 나오지 않는다.

| 키 | 필수/선택 | 쓰는 곳 |
|---|---|---|
| 다른 기기 로그인 비밀번호 | 서버 방식에서 필수 | 내 계정이 아닌 기기가 들어올 때 |
| 공공데이터포털 | 선택 | 오늘 화면의 날씨 · 미세먼지 · 공휴일 · 버스 도착 |
| 서울 열린데이터광장 | 선택 | 지하철 도착 |
| Google | 선택 | Google 캘린더, 가계부(Google 시트). 연결한 뒤 "가계부 시트 만들기"로 내 드라이브에 가계부 시트를 만든다 |
| Kakao, ntfy | 선택 | 알림 |
| eTL | 선택 | 서울대 eTL의 과제 · 마감, 강의 자료 |

### 3. LLM

요약 · 추천 · AI 패널은 이 PC에 로그인한 Claude Code나 Codex CLI를 쓴다. API 키는 받지 않는다. 둘 다 없으면 "LLM 없이 쓰기"를 고른다. 나머지 기능은 그대로 쓴다.

## 매일

| 할 일 | 방법 |
|---|---|
| 열기 | `http://127.0.0.1:8800` |
| 켜기 | 자동 시작을 등록했으면 저절로 켜진다. 손으로는 설치 폴더의 `scripts\start.ps1` |
| 끄기 | `scripts\stop.ps1 -Javis` |

## 업데이트

설치할 때와 같은 한 줄을 다시 돌린다. 새 판이 있으면 프로그램만 바꾸고 자료(`data\`, `apps\javis\workspace\`)는 그대로 둔다.

```powershell
irm https://raw.githubusercontent.com/choohui/forme/main/install.ps1 | iex
```

## 지우기

설치 폴더(`%LOCALAPPDATA%\orchestrate`)에서:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

끄고, 자동 시작 작업을 지우고, 프로그램을 지운다. 자료와 키는 지울지 따로 묻는다(기본은 남김). 서버 방식이었다면 먼저 `scripts\mode.ps1 -Mode local`로 다른 기기에서 여는 주소를 끈다.

## 안 될 때

설치 폴더의 `INSTALL.md`에 증상별 확인 방법이 있다. 먼저 볼 것:

- 화면이 안 뜬다: `data\logs\hub-*.err.log`의 끝부분.
- "스크립트를 실행할 수 없습니다": 위 명령처럼 `-ExecutionPolicy Bypass`를 붙여 돌린다(시스템 설정은 바꾸지 않는다).
- 다른 기기에서 안 열린다(서버 방식): 그 기기의 Tailscale이 같은 계정으로 켜져 있는지, 이 PC가 깨어 있는지 본다.

## 자료가 있는 곳

- `data\`: DB, 로그, 매일 03:30의 백업(14개 유지).
- `apps\javis\workspace\`: 강의 · 논문 · 탐구 파일.
- 키: Windows 자격 증명 관리자(이 Windows 사용자 계정으로 암호화).

이 저장소에는 빌드한 프로그램만 있다. 판마다 `orchestrate-<판>.zip`, 그 `.sha256`, `latest.json`(판과 해시)이 Releases에 올라온다.

## 라이선스

MIT. 전문은 [LICENSE](LICENSE)에 있다(Javis의 바탕인 easy-study의 저작권 고지를 함께 담았다). 함께 들어 있는 다른 것들의 고지는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
