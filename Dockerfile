# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim

# ---- Locale, timezone ----
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=America/Denver

# ---- System packages ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Basics
    ca-certificates curl wget gnupg git openssh-client sudo gosu \
    locales tzdata pipx \
    # Editors
    neovim vim nano \
    # Shell experience
    zsh tmux htop ripgrep fzf fd-find bat jq unzip xz-utils less man-db \
    # Build toolchain
    build-essential pkg-config make autoconf automake libtool cmake \
    # Common runtime build deps
    libssl-dev libreadline-dev libsqlite3-dev libffi-dev libbz2-dev \
    liblzma-dev zlib1g-dev tk-dev libyaml-dev \
    # Erlang/OTP build deps
    libncurses-dev libwxgtk3.2-dev libgl1-mesa-dev libglu1-mesa-dev \
    libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils \
    # Useful at runtime
    postgresql-client inotify-tools \
    && locale-gen en_US.UTF-8 \
    && ln -sf /usr/share/zoneinfo/$TZ /etc/localtime \
    && rm -rf /var/lib/apt/lists/*

# ---- Node.js ----
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---- code-server ----
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ---- GitHub CLI ----
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ---- Tailscale ----
RUN curl -fsSL https://tailscale.com/install.sh | sh

# ---- git-delta ----
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL -o /tmp/delta.deb \
    "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" \
    && dpkg -i /tmp/delta.deb && rm /tmp/delta.deb

# ---- uv (standalone, replaces pipx-based install) ----
RUN curl -LsSf https://astral.sh/uv/install.sh \
    | env UV_INSTALL_DIR=/usr/local/bin sh

# ---- Starship prompt ----
RUN curl -sS https://starship.rs/install.sh \
    | sh -s -- --yes --bin-dir /usr/local/bin

# ---- mise ----
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# ---- Non-root user ----
RUN useradd -m -s /bin/zsh -G sudo dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && chown -R dev:dev /home/dev

# ---- Antidote (zsh plugin manager) baked in ----
RUN git clone --depth=1 https://github.com/mattmc3/antidote.git /opt/antidote \
    && chown -R dev:dev /opt/antidote

# ---- Symlinks: XDG dirs, ssh, and language toolchain homes ----
RUN ln -sf /workspace/state/config         /home/dev/.config \
    && ln -sf /workspace/state/local       /home/dev/.local \
    && ln -sf /workspace/state/cache       /home/dev/.cache \
    && ln -sf /workspace/state/ssh         /home/dev/.ssh \
    && ln -sf /workspace/state/zsh_history /home/dev/.zsh_history \
    && ln -sf /workspace/state/go          /home/dev/go \
    && ln -sf /workspace/state/m2          /home/dev/.m2 \
    && ln -sf /workspace/state/mix         /home/dev/.mix \
    && ln -sf /workspace/state/hex         /home/dev/.hex \
    && ln -sf /workspace/state/gradle      /home/dev/.gradle \
    && ln -sf /workspace/state/vscode-server /home/dev/.vscode-server \
    && chown -h dev:dev /home/dev/.config /home/dev/.local /home/dev/.cache \
    /home/dev/.ssh /home/dev/.zsh_history /home/dev/go /home/dev/.m2 \
    /home/dev/.mix /home/dev/.hex /home/dev/.gradle /home/dev/.vscode-server

# ---- Shell config (baked defaults; runtime overrides via /workspace/dotfiles) ----
RUN cat > /home/dev/.zshrc <<'EOF'
# mise
eval "$(/usr/local/bin/mise activate zsh)"

# History on the volume
export HISTFILE=/home/dev/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE EXTENDED_HISTORY

# Aliases
alias ll='ls -lah'
alias gs='git status'
alias fd='fdfind'
alias bat='batcat'

# Per-machine customization (edit on the volume to persist changes)
[ -f /workspace/dotfiles/zshrc-extras ] && source /workspace/dotfiles/zshrc-extras
EOF
RUN echo 'eval "$(/usr/local/bin/mise activate zsh)"' > /home/dev/.zprofile \
    && chown dev:dev /home/dev/.zshrc /home/dev/.zprofile

# ---- Entrypoint ----
RUN cat > /usr/local/bin/entrypoint.sh <<'EOF'
#!/bin/sh
set -e

# ---- Volume layout ----
mkdir -p \
  /workspace/state/config \
  /workspace/state/local \
  /workspace/state/cache \
  /workspace/state/code-server/extensions \
  /workspace/state/ssh \
  /workspace/state/tailscale \
  /workspace/state/go \
  /workspace/state/m2 \
  /workspace/state/mix \
  /workspace/state/hex \
  /workspace/state/gradle \
  /workspace/state/vscode-server \
  /workspace/projects \
  /workspace/dotfiles
chmod 700 /workspace/state/ssh
chmod 700 /workspace/state/tailscale
[ -f /workspace/state/zsh_history ] || touch /workspace/state/zsh_history
chmod 600 /workspace/state/zsh_history
chown -R dev:dev /workspace
# tailscaled runs as root; keep its state root-owned
chown -R root:root /workspace/state/tailscale

# ---- Tailscale ----
mkdir -p /var/run/tailscale
tailscaled \
  --tun=userspace-networking \
  --state=/workspace/state/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock \
  >/var/log/tailscaled.log 2>&1 &

# Wait for the daemon to be ready (max ~15s)
for i in $(seq 1 15); do
  tailscale status >/dev/null 2>&1 && break
  sleep 1
done

# Bring the node up. --authkey is a no-op if state already has us logged in.
tailscale up \
  --authkey="${TS_AUTHKEY:-}" \
  --hostname="${TS_HOSTNAME:-devbox}" \
  --ssh \
  --accept-dns=false

# ---- Hand off to code-server as dev ----
exec gosu dev "$@"
EOF
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["code-server", \
    "--bind-addr", "0.0.0.0:8080", \
    "--auth", "password", \
    "/workspace/projects"]