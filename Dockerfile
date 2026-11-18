FROM ubuntu:24.04

# 빌드 시 워크플로가 최신 Orca 릴리스 태그를 넣어 줍니다 (예: v1.4.239)
ARG ORCA_VERSION=latest
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb xauth git curl ca-certificates openssh-client jq \
    build-essential python3 python3-pip python3-venv pipx \
    nodejs npm \
    libgtk-3-0t64 libnss3 libasound2t64 libgbm1 libxss1 libxtst6 libnotify4 libsecret-1-0 \
 && rm -rf /var/lib/apt/lists/*

# Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Ouroboros (Python 3.12 이상 필요)
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin \
    pipx install 'ouroboros-ai[claude]'

# Orca: 컨테이너에는 FUSE가 없으므로 AppImage를 풀어서 실행
RUN mkdir -p /opt/orca && cd /opt/orca \
 && if [ "$ORCA_VERSION" = "latest" ]; then \
      url="https://github.com/stablyai/orca/releases/latest/download/orca-linux.AppImage"; \
    else \
      url="https://github.com/stablyai/orca/releases/download/${ORCA_VERSION}/orca-linux.AppImage"; \
    fi \
 && curl -fL -o orca.AppImage "$url" \
 && chmod +x orca.AppImage \
 && ./orca.AppImage --appimage-extract >/dev/null \
 && rm orca.AppImage \
 && ln -s /opt/orca/squashfs-root/AppRun /usr/local/bin/orca-app \
 && echo "$ORCA_VERSION" > /opt/orca/VERSION

# TrueNAS apps 사용자(UID/GID 568)와 맞춤
RUN groupadd -g 568 orca && useradd -m -u 568 -g 568 -s /bin/bash orca
USER orca
WORKDIR /home/orca

ENV LIBGL_ALWAYS_SOFTWARE=1 \
    ORCA_PORT=6768 \
    PAIRING_ADDRESS="" \
    ORCA_EXTRA_ARGS=""

EXPOSE 6768

CMD ["sh", "-c", "exec xvfb-run --auto-servernum orca-app serve --port ${ORCA_PORT} --pairing-address ${PAIRING_ADDRESS} ${ORCA_EXTRA_ARGS}"]
