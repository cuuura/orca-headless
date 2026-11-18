#!/bin/sh
# 컨테이너 시작 스크립트
#  1) 최초 1회 필요한 설정(git, Ouroboros 플러그인/런타임)을 자동으로 수행 — 여러 번 실행해도 안전
#  2) 가상 디스플레이(Xvfb)를 직접 띄움 (xvfb-run은 PID 1에서 멈추는 문제가 있음)
#  3) orca serve 실행

log() { echo "[entrypoint] $*" >&2; }

auto_setup() {
  mkdir -p "$HOME/workspace"

  # --- git 기본 설정 -------------------------------------------------------
  if [ -n "$GIT_USER_NAME" ]; then git config --global user.name "$GIT_USER_NAME"; fi
  if [ -n "$GIT_USER_EMAIL" ]; then git config --global user.email "$GIT_USER_EMAIL"; fi
  if ! git config --global credential.helper >/dev/null 2>&1; then
    git config --global credential.helper store
  fi

  # --- git 인증 정보 (환경 변수 → ~/.git-credentials) -----------------------
  cred_file="$HOME/.git-credentials"
  add_credential() {
    # $1 = https://사용자:토큰@호스트  (같은 호스트의 기존 항목은 교체)
    entry="$1"
    host_part="${entry##*@}"
    touch "$cred_file" && chmod 600 "$cred_file"
    grep -v "@${host_part}\$" "$cred_file" > "${cred_file}.tmp" 2>/dev/null || true
    printf '%s\n' "$entry" >> "${cred_file}.tmp"
    mv "${cred_file}.tmp" "$cred_file" && chmod 600 "$cred_file"
    log "git 인증: ${host_part} 등록"
  }
  if [ -n "$GIT_HOST" ] && [ -n "$GIT_TOKEN" ]; then
    h="${GIT_HOST#https://}"; h="${h#http://}"; h="${h%/}"
    add_credential "https://${GIT_USERNAME:-git}:${GIT_TOKEN}@${h}"
  fi
  # 추가 호스트: 공백/줄바꿈으로 구분한 https://사용자:토큰@호스트 목록
  for extra in $GIT_CREDENTIALS; do
    case "$extra" in
      https://*@*) add_credential "${extra%/}" ;;
      *) log "git 인증: GIT_CREDENTIALS 항목 형식이 잘못되어 건너뜀" ;;
    esac
  done

  if [ "${OUROBOROS_AUTO_SETUP:-1}" != "1" ]; then
    log "OUROBOROS_AUTO_SETUP=0 — Ouroboros 자동 설정을 건너뜁니다."
    return 0
  fi

  # --- Ouroboros Claude Code 플러그인 --------------------------------------
  if timeout 30 claude plugin list </dev/null 2>/dev/null | grep -q "ouroboros"; then
    log "Ouroboros 플러그인: 이미 설치됨"
  else
    log "Ouroboros 플러그인 설치 중..."
    if timeout 180 claude plugin marketplace add Q00/ouroboros </dev/null >/tmp/ouroboros-plugin.log 2>&1 \
       && timeout 180 claude plugin install ouroboros@ouroboros </dev/null >>/tmp/ouroboros-plugin.log 2>&1; then
      log "Ouroboros 플러그인: 설치 완료"
    else
      log "Ouroboros 플러그인 설치 실패 (계속 진행). 로그: /tmp/ouroboros-plugin.log"
      tail -5 /tmp/ouroboros-plugin.log >&2 2>/dev/null || true
    fi
  fi

  # --- Ouroboros 런타임 설정 -----------------------------------------------
  if [ -f "$HOME/.ouroboros/config.yaml" ]; then
    log "Ouroboros 설정: 이미 있음"
  else
    log "ouroboros setup 실행 중..."
    if timeout 120 ouroboros setup </dev/null >/tmp/ouroboros-setup.log 2>&1; then
      log "Ouroboros 설정: 완료"
    else
      log "ouroboros setup 실패 (계속 진행). 로그: /tmp/ouroboros-setup.log"
      tail -5 /tmp/ouroboros-setup.log >&2 2>/dev/null || true
    fi
  fi

  # --- Claude 로그인 상태 안내 ---------------------------------------------
  if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    log "Claude 인증: CLAUDE_CODE_OAUTH_TOKEN 사용"
  elif [ -f "$HOME/.claude/.credentials.json" ]; then
    log "Claude 인증: 저장된 로그인 사용"
  else
    log "Claude 인증: 없음 — 컨테이너 셸에서 'claude'를 한 번 실행해 로그인하거나"
    log "             CLAUDE_CODE_OAUTH_TOKEN 환경 변수를 설정하세요."
  fi
}

auto_setup || log "자동 설정 중 오류가 있었지만 계속 진행합니다."

# --- 가상 디스플레이 --------------------------------------------------------
DISPLAY_NUM="${DISPLAY_NUM:-99}"
export DISPLAY=":${DISPLAY_NUM}"
rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}" 2>/dev/null || true
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &

i=0
while [ ! -S "/tmp/.X11-unix/X${DISPLAY_NUM}" ] && [ "$i" -lt 50 ]; do
  sleep 0.2
  i=$((i + 1))
done

# --- Orca -------------------------------------------------------------------
PORT="${ORCA_PORT:-6768}"

if [ -z "$PAIRING_ADDRESS" ] || [ "$PAIRING_ADDRESS" = "CHANGE_ME" ]; then
  log "PAIRING_ADDRESS가 설정되지 않았습니다. 원격 클라이언트는 접속할 수 없습니다."
  # shellcheck disable=SC2086
  exec orca-app serve --port "$PORT" ${ORCA_EXTRA_ARGS}
fi

log "orca serve 시작: port=${PORT} pairing-address=${PAIRING_ADDRESS}"
# shellcheck disable=SC2086
exec orca-app serve --port "$PORT" --pairing-address "$PAIRING_ADDRESS" ${ORCA_EXTRA_ARGS}
