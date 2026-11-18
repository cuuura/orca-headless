# orca-headless

`orca serve`(Orca 헤드리스 런타임) + Claude Code + Ouroboros를 한 이미지로 묶어
TrueNAS 커스텀 앱으로 돌리기 위한 저장소입니다. Stably(Orca)와 무관한 개인용 비공식 빌드입니다.

> 이 구성은 실제 빌드/실행 검증을 거치지 않은 초안입니다. 첫 빌드에서 패키지 누락 등이 나올 수 있습니다.

## 자동 빌드

- `main`에 푸시하면 빌드
- 매일 03:17(KST)에 Orca 최신 릴리스를 확인해서, 그 버전 이미지가 없을 때만 빌드
- 태그: `<Orca 버전>`(예: `v1.4.239`)과 `latest`

### GitHub에서 쓸 때
저장소를 만들어 푸시하면 끝입니다. 이미지는 `ghcr.io/<계정>/orca-headless`에 올라갑니다.
(비공개 패키지라면 TrueNAS에 ghcr 로그인 정보를 등록해야 합니다.)
`.forgejo/` 폴더는 지워도 됩니다.

### Forgejo에서 쓸 때
1. Docker 빌드가 가능한 Forgejo 러너 등록 (라벨 `docker`)
2. 저장소 Variables에 `REGISTRY` = Forgejo 호스트명 (`https://` 없이)
3. 저장소 Secrets에 `REGISTRY_TOKEN` = package 쓰기 권한 토큰
4. `.github/` 폴더는 지워도 됩니다.

## 배포 (TrueNAS)

1. 데이터셋 생성 후 소유자를 `568:568`(apps)로 설정
2. `compose.yaml`의 `CHANGE_ME` 세 곳을 채워 Apps → Install via YAML
3. 앱 Shell에서 한 번만 실행:
   ```bash
   claude                             # 로그인
   orca-app account add --agent claude
   ouroboros setup
   ```
4. 앱 로그의 페어링 URL을 PC Orca 앱 → Settings → Remote Orca Servers → Add Server 에 붙여넣기

## 버전 맞추기

Orca는 클라이언트와 서버 버전이 맞아야 합니다. PC 앱을 업데이트했으면 TrueNAS 앱도 새 이미지로 갱신하세요.
자동 갱신이 불안하면 compose의 이미지 태그를 `latest` 대신 특정 버전으로 고정하세요.

## 보안

6768 포트는 리버스 프록시로 외부에 공개하지 말고 내부망/VPN(Tailscale 등)으로만 접근하세요.
