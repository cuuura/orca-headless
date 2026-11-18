# orca-headless

`orca serve`(Orca 헤드리스 런타임) + Claude Code + Ouroboros를 한 이미지로 묶은 개인용 비공식 빌드입니다.
Stably(Orca), Ouroboros 프로젝트와 무관합니다.

목표: **데이터셋 하나 만들고 compose를 올리면 나머지는 자동.**

## 이미지에 들어 있는 것

| 구성 | 설치 방식 |
|---|---|
| Orca | GitHub 최신 릴리스 AppImage를 풀어서 포함 (`orca-app` 명령) |
| Claude Code | npm 전역 설치 |
| Ouroboros | pipx (`ouroboros`, `ooo` 명령) |
| uv / uvx | pipx — Ouroboros 플러그인이 MCP 서버를 띄울 때 필요 |

## 컨테이너가 시작할 때 자동으로 하는 일

`entrypoint.sh`가 매번 실행하며, 이미 되어 있으면 건너뜁니다.

1. git 기본 설정 (`GIT_USER_NAME`, `GIT_USER_EMAIL`, credential helper)
2. Ouroboros Claude Code 플러그인 설치 (`claude plugin install ouroboros@ouroboros`)
3. `ouroboros setup` (런타임 등록, `~/.ouroboros/config.yaml`)
4. 가상 디스플레이(Xvfb) 기동 후 `orca serve` 실행

결과는 모두 홈 볼륨(`/home/orca`)에 남아 재배포 후에도 유지됩니다.

## 설치

### 1. 데이터셋 (TrueNAS 셸, 한 번만)

```bash
zfs create -p fast/appdata/orca/home
chown -R 568:568 /mnt/fast/appdata/orca/home
```

### 2. 스택 배포

`compose.yaml`을 Portainer 스택(또는 TrueNAS Install via YAML)에 붙여넣고 `CHANGE_ME` 두 곳을 채웁니다.

- `PAIRING_ADDRESS` — 클라이언트가 접속할 주소
- 볼륨 경로의 풀 이름

### 3. 연결

```bash
docker logs orca-orca-1 2>&1 | grep -A8 "Orca server ready"
```

`Pairing URL` 전체를 PC Orca 앱 → Settings → Remote Orca Servers → Add Server 에 붙여넣습니다.
이 링크는 비밀번호와 같습니다.

### 4. Claude 로그인 (자동화하지 않은 유일한 단계)

둘 중 하나:

- **토큰 방식(무인)**: PC에서 `claude setup-token`으로 발급한 값을 `CLAUDE_CODE_OAUTH_TOKEN`에 넣기
- **수동 방식**: `docker exec -it orca-orca-1 claude` 로 한 번 로그인 (홈 볼륨에 저장됨)

### 5. 확인

Orca에서 Claude Code 세션을 열고:

```
/mcp                      → plugin:ouroboros:ouroboros 가 ✓ 인지
ooo interview "만들 것"    → 질문이 바로 시작되는지
```

## 환경 변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `PAIRING_ADDRESS` | (없음) | 필수. 프록시면 `https://도메인` 전체 URL, 직접 연결이면 IP |
| `ORCA_PORT` | `6768` | 컨테이너 안에서 듣는 포트. 직접 연결 시 호스트 포트와 같게 |
| `ORCA_EXTRA_ARGS` | (없음) | `orca serve`에 추가할 옵션 (예: `--mobile-pairing`) |
| `CLAUDE_CODE_OAUTH_TOKEN` | (없음) | Claude 로그인 토큰 |
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | (없음) | 커밋 작성자 |
| `OUROBOROS_AUTO_SETUP` | `1` | `0`이면 플러그인/setup 자동 실행 안 함 |

## 자동 빌드

- `main`에 푸시하면 빌드
- 매일 03:17(KST)에 Orca 최신 릴리스를 확인해, 그 버전 이미지가 없을 때만 빌드
- 태그: `<Orca 버전>`(예: `v1.4.263`)과 `latest`

Orca는 클라이언트와 서버 버전이 맞아야 합니다. PC 앱을 업데이트한 날에는 스택도 다시 올리세요
(`pull_policy: always`라 Update만 누르면 새 이미지를 받습니다).
버전을 고정하려면 이미지 태그를 `latest` 대신 특정 버전으로 바꿉니다.

Forgejo Actions로 빌드하려면 `.forgejo/workflows/build.yml` 상단 주석을 참고하세요.

## 문제 해결

| 증상 | 원인 / 조치 |
|---|---|
| 로그가 한 줄도 없음 | 예전 이미지(xvfb-run). `docker pull` 후 재생성 |
| `[entrypoint] PAIRING_ADDRESS가 설정되지 않았습니다` | compose의 `CHANGE_ME`를 안 바꿈 |
| Advertised endpoint에 엉뚱한 포트 | 프록시를 쓰면 `https://`를 포함한 전체 URL로 지정 |
| `/mcp`에서 ouroboros `ENOENT` | `uvx` 없음 → 최신 이미지로 갱신 |
| `ooo`가 셸 명령으로 실행됨 | 플러그인 미설치. `/tmp/ouroboros-plugin.log` 확인 후 새 세션 |
| 브라우저로 포트를 열어도 아무것도 안 뜸 | 정상. WebSocket 접속점이며 테스트는 Orca 앱으로 |

## 보안

- 연결된 클라이언트는 서버에서 명령을 실행할 수 있습니다. 방어선은 페어링 코드입니다.
- 인터넷에 공개하는 것보다 Tailscale/WireGuard 주소로 직접 붙이는 구성을 권장합니다.
- 프록시로 공개한다면 접근 IP 제한이나 사전 인증을 반드시 추가하세요.
- 실제 주소, 토큰, 경로는 이 저장소에 커밋하지 말고 배포할 때만 채우세요.
