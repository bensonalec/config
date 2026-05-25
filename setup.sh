#!/usr/bin/env bash
# devbox-setup.sh — bootstrap a freshly-deployed Fly dev box.
# Idempotent; safe to re-run.

set -euo pipefail

DOTFILES_REPO="bensonalec/dotfiles"
DOTFILES_HTTPS="https://github.com/${DOTFILES_REPO}.git"
DOTFILES_DIR="/workspace/dotfiles"

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

# --- Clone or update dotfiles ---
if [ -d "$DOTFILES_DIR/.git" ]; then
    info "Updating existing dotfiles..."
    git -C "$DOTFILES_DIR" pull --rebase --autostash || warn "Pull failed"
elif [ -d "$DOTFILES_DIR" ] && [ -n "$(ls -A "$DOTFILES_DIR" 2>/dev/null)" ]; then
    BACKUP="${DOTFILES_DIR}.bak.$(date +%s)"
    warn "$DOTFILES_DIR exists and isn't a git repo; backing up to $BACKUP"
    mv "$DOTFILES_DIR" "$BACKUP"
    gh repo clone "$DOTFILES_REPO" "$DOTFILES_DIR" 2>/dev/null \
        || git clone "$DOTFILES_HTTPS" "$DOTFILES_DIR"
else
    [ -d "$DOTFILES_DIR" ] && rmdir "$DOTFILES_DIR" 2>/dev/null || true
    info "Cloning dotfiles..."
    gh repo clone "$DOTFILES_REPO" "$DOTFILES_DIR" 2>/dev/null \
        || git clone "$DOTFILES_HTTPS" "$DOTFILES_DIR"
fi
ok "Dotfiles ready at $DOTFILES_DIR"

# --- Link configs ---
info "Linking configs..."
mkdir -p ~/.config/mise ~/.config

[ -f "$DOTFILES_DIR/mise/config.toml" ] && \
    ln -sf "$DOTFILES_DIR/mise/config.toml" ~/.config/mise/config.toml

[ -f "$DOTFILES_DIR/starship.toml" ] && \
    ln -sf "$DOTFILES_DIR/starship.toml" ~/.config/starship.toml

[ -f "$DOTFILES_DIR/.gitconfig" ] && \
    git config --global include.path "$DOTFILES_DIR/.gitconfig"

mise trust ~/.config/mise/config.toml >/dev/null 2>&1 || true
ok "Configs linked"

# --- VS Code extensions ---
if [ -x "$DOTFILES_DIR/install-vscode-extensions.sh" ]; then
    info "Installing VS Code extensions..."
    "$DOTFILES_DIR/install-vscode-extensions.sh"
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
  1. Watch mise install (~20 min on first run):
       tmux a -t setup
  2. Reload shell:
       exec zsh
  3. Drop secrets in /workspace/dotfiles/zshrc-local:
       echo 'export ANTHROPIC_API_KEY="sk-ant-..."' \\
            > /workspace/dotfiles/zshrc-local
  4. Clone projects into /workspace/projects/

EOF