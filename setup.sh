#!/usr/bin/env bash
# setup.sh — bootstrap a freshly-deployed Fly dev box.
# Idempotent; safe to re-run.

set -euo pipefail

DEVBOX_REPO="bensonalec/config"
DEVBOX_HTTPS="https://github.com/${DEVBOX_REPO}.git"
DEVBOX_DIR="/workspace/devbox"
DOTFILES_LINK="/workspace/dotfiles"     # symlinked → $DEVBOX_DIR/dotfiles

info() { printf "\033[1;34m[*]\033[0m %s\n" "$1"; }
ok()   { printf "\033[1;32m[+]\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$1"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$1" >&2; }

# --- Preflight ---
[ "$(whoami)" = "dev" ] || { err "Run as the 'dev' user"; exit 1; }
[ -d /workspace ]       || { err "/workspace not mounted"; exit 1; }

# --- GitHub auth ---
if ! gh auth status >/dev/null 2>&1; then
    warn "gh is not authenticated."
    read -rp "Run 'gh auth login' now? [Y/n] " yn
    [[ ! "${yn:-y}" =~ ^[Nn] ]] && gh auth login
fi

# --- Clone or update devbox repo ---
if [ -d "$DEVBOX_DIR/.git" ]; then
    info "Updating existing devbox checkout..."
    git -C "$DEVBOX_DIR" pull --rebase --autostash || warn "Pull failed"
elif [ -d "$DEVBOX_DIR" ] && [ -n "$(ls -A "$DEVBOX_DIR" 2>/dev/null)" ]; then
    BACKUP="${DEVBOX_DIR}.bak.$(date +%s)"
    warn "$DEVBOX_DIR is non-empty and not a git repo; backing up to $BACKUP"
    mv "$DEVBOX_DIR" "$BACKUP"
    gh repo clone "$DEVBOX_REPO" "$DEVBOX_DIR" 2>/dev/null \
        || git clone "$DEVBOX_HTTPS" "$DEVBOX_DIR"
else
    [ -d "$DEVBOX_DIR" ] && rmdir "$DEVBOX_DIR" 2>/dev/null || true
    info "Cloning devbox repo..."
    gh repo clone "$DEVBOX_REPO" "$DEVBOX_DIR" 2>/dev/null \
        || git clone "$DEVBOX_HTTPS" "$DEVBOX_DIR"
fi
ok "Devbox repo ready at $DEVBOX_DIR"

# --- Symlink /workspace/dotfiles → $DEVBOX_DIR/dotfiles ---
# Keeps the canonical /workspace/dotfiles/ paths working in zshrc-extras,
# antidote, install-vscode-extensions.sh, and the Dockerfile-baked ~/.zshrc.
if [ -L "$DOTFILES_LINK" ] || [ ! -e "$DOTFILES_LINK" ]; then
    ln -sfn "$DEVBOX_DIR/dotfiles" "$DOTFILES_LINK"
    ok "Symlinked $DOTFILES_LINK → $DEVBOX_DIR/dotfiles"
elif [ -d "$DOTFILES_LINK" ]; then
    BACKUP="${DOTFILES_LINK}.bak.$(date +%s)"
    warn "$DOTFILES_LINK is a real directory (legacy clone?); backing up to $BACKUP"
    mv "$DOTFILES_LINK" "$BACKUP"
    ln -s "$DEVBOX_DIR/dotfiles" "$DOTFILES_LINK"
    ok "Symlinked $DOTFILES_LINK → $DEVBOX_DIR/dotfiles"
fi

# --- Link configs ---
info "Linking configs..."
mkdir -p ~/.config/mise ~/.config

[ -f "$DEVBOX_DIR/dotfiles/mise/config.toml" ] && \
    ln -sf "$DEVBOX_DIR/dotfiles/mise/config.toml" ~/.config/mise/config.toml

[ -f "$DEVBOX_DIR/dotfiles/starship.toml" ] && \
    ln -sf "$DEVBOX_DIR/dotfiles/starship.toml" ~/.config/starship.toml

[ -f "$DEVBOX_DIR/dotfiles/.gitconfig" ] && \
    git config --global include.path "$DEVBOX_DIR/dotfiles/.gitconfig"

mise trust ~/.config/mise/config.toml >/dev/null 2>&1 || true
ok "Configs linked"

# --- VS Code extensions ---
if [ -x "$DEVBOX_DIR/dotfiles/install-vscode-extensions.sh" ]; then
    info "Installing VS Code extensions..."
    "$DEVBOX_DIR/dotfiles/install-vscode-extensions.sh"
fi

# --- Mise install (background) ---
if tmux has-session -t setup 2>/dev/null; then
    warn "tmux session 'setup' already exists"
else
    info "Starting mise install in tmux session 'setup'..."
    tmux new-session -d -s setup \
        'mise install 2>&1 | tee /tmp/mise-install.log; echo; echo "Done."; exec bash'
    ok "mise install running. Attach with: tmux a -t setup"
fi

mkdir -p /workspace/projects

# --- Summary ---
echo
ok "Bootstrap complete"
cat <<EOF

Manual steps remaining:
  1. Watch mise install:    tmux a -t setup
  2. Reload shell:          exec zsh
  3. Drop secrets in /workspace/dotfiles/zshrc-local:
       echo 'export ANTHROPIC_API_KEY="sk-ant-..."' \\
            > /workspace/dotfiles/zshrc-local
  4. Clone projects into /workspace/projects/

EOF#!/usr/bin/env bash
# setup.sh — bootstrap a freshly-deployed Fly dev box.
# Idempotent; safe to re-run.

set -euo pipefail

DEVBOX_REPO="bensonalec/config"
DEVBOX_HTTPS="https://github.com/${DEVBOX_REPO}.git"
DEVBOX_DIR="/workspace/devbox"
DOTFILES_LINK="/workspace/dotfiles"     # symlinked → $DEVBOX_DIR/dotfiles

info() { printf "\033[1;34m[*]\033[0m %s\n" "$1"; }
ok()   { printf "\033[1;32m[+]\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$1"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$1" >&2; }

# --- Preflight ---
[ "$(whoami)" = "dev" ] || { err "Run as the 'dev' user"; exit 1; }
[ -d /workspace ]       || { err "/workspace not mounted"; exit 1; }

# --- GitHub auth ---
if ! gh auth status >/dev/null 2>&1; then
    warn "gh is not authenticated."
    read -rp "Run 'gh auth login' now? [Y/n] " yn
    [[ ! "${yn:-y}" =~ ^[Nn] ]] && gh auth login
fi

# --- Clone or update devbox repo ---
if [ -d "$DEVBOX_DIR/.git" ]; then
    info "Updating existing devbox checkout..."
    git -C "$DEVBOX_DIR" pull --rebase --autostash || warn "Pull failed"
elif [ -d "$DEVBOX_DIR" ] && [ -n "$(ls -A "$DEVBOX_DIR" 2>/dev/null)" ]; then
    BACKUP="${DEVBOX_DIR}.bak.$(date +%s)"
    warn "$DEVBOX_DIR is non-empty and not a git repo; backing up to $BACKUP"
    mv "$DEVBOX_DIR" "$BACKUP"
    gh repo clone "$DEVBOX_REPO" "$DEVBOX_DIR" 2>/dev/null \
        || git clone "$DEVBOX_HTTPS" "$DEVBOX_DIR"
else
    [ -d "$DEVBOX_DIR" ] && rmdir "$DEVBOX_DIR" 2>/dev/null || true
    info "Cloning devbox repo..."
    gh repo clone "$DEVBOX_REPO" "$DEVBOX_DIR" 2>/dev/null \
        || git clone "$DEVBOX_HTTPS" "$DEVBOX_DIR"
fi
ok "Devbox repo ready at $DEVBOX_DIR"

# --- Symlink /workspace/dotfiles → $DEVBOX_DIR/dotfiles ---
# Keeps the canonical /workspace/dotfiles/ paths working in zshrc-extras,
# antidote, install-vscode-extensions.sh, and the Dockerfile-baked ~/.zshrc.
if [ -L "$DOTFILES_LINK" ] || [ ! -e "$DOTFILES_LINK" ]; then
    ln -sfn "$DEVBOX_DIR/dotfiles" "$DOTFILES_LINK"
    ok "Symlinked $DOTFILES_LINK → $DEVBOX_DIR/dotfiles"
elif [ -d "$DOTFILES_LINK" ]; then
    BACKUP="${DOTFILES_LINK}.bak.$(date +%s)"
    warn "$DOTFILES_LINK is a real directory (legacy clone?); backing up to $BACKUP"
    mv "$DOTFILES_LINK" "$BACKUP"
    ln -s "$DEVBOX_DIR/dotfiles" "$DOTFILES_LINK"
    ok "Symlinked $DOTFILES_LINK → $DEVBOX_DIR/dotfiles"
fi

# --- Link configs ---
info "Linking configs..."
mkdir -p ~/.config/mise ~/.config

[ -f "$DEVBOX_DIR/dotfiles/mise/config.toml" ] && \
    ln -sf "$DEVBOX_DIR/dotfiles/mise/config.toml" ~/.config/mise/config.toml

[ -f "$DEVBOX_DIR/dotfiles/starship.toml" ] && \
    ln -sf "$DEVBOX_DIR/dotfiles/starship.toml" ~/.config/starship.toml

[ -f "$DEVBOX_DIR/dotfiles/.gitconfig" ] && \
    git config --global include.path "$DEVBOX_DIR/dotfiles/.gitconfig"

mise trust ~/.config/mise/config.toml >/dev/null 2>&1 || true
ok "Configs linked"

# --- VS Code extensions ---
if [ -x "$DEVBOX_DIR/dotfiles/install-vscode-extensions.sh" ]; then
    info "Installing VS Code extensions..."
    "$DEVBOX_DIR/dotfiles/install-vscode-extensions.sh"
fi

# --- Mise install (background) ---
if tmux has-session -t setup 2>/dev/null; then
    warn "tmux session 'setup' already exists"
else
    info "Starting mise install in tmux session 'setup'..."
    tmux new-session -d -s setup \
        'mise install 2>&1 | tee /tmp/mise-install.log; echo; echo "Done."; exec bash'
    ok "mise install running. Attach with: tmux a -t setup"
fi

mkdir -p /workspace/projects

# --- Summary ---
echo
ok "Bootstrap complete"
cat <<EOF

Manual steps remaining:
  1. Watch mise install:    tmux a -t setup
  2. Reload shell:          exec zsh
  3. Drop secrets in /workspace/dotfiles/zshrc-local:
       echo 'export ANTHROPIC_API_KEY="sk-ant-..."' \\
            > /workspace/dotfiles/zshrc-local
  4. Clone projects into /workspace/projects/

EOF