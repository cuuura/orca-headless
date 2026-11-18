#!/bin/sh
# xvfb-run은 컨테이너의 PID 1로 돌면 Xvfb 준비 신호를 못 받아 멈추는 경우가 있어
# Xvfb를 직접 띄우고 Orca를 실행합니다.
set -e

DISPLAY_NUM="${DISPLAY_NUM:-99}"
export DISPLAY=":${DISPLAY_NUM}"

rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}" 2>/dev/null || true
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &

# Xvfb 소켓이 생길 때까지 최대 10초 대기
i=0
while [ ! -S "/tmp/.X11-unix/X${DISPLAY_NUM}" ] && [ "$i" -lt 50 ]; do
  sleep 0.2
  i=$((i + 1))
done

if [ -z "$PAIRING_ADDRESS" ] || [ "$PAIRING_ADDRESS" = "CHANGE_ME" ]; then
  echo "[entrypoint] PAIRING_ADDRESS가 설정되지 않았습니다. 로컬 전용으로 시작합니다." >&2
  # shellcheck disable=SC2086
  exec orca-app serve --port "${ORCA_PORT:-6768}" ${ORCA_EXTRA_ARGS}
fi

echo "[entrypoint] orca serve 시작: port=${ORCA_PORT:-6768} pairing-address=${PAIRING_ADDRESS}" >&2
# shellcheck disable=SC2086
exec orca-app serve --port "${ORCA_PORT:-6768}" --pairing-address "$PAIRING_ADDRESS" ${ORCA_EXTRA_ARGS}
