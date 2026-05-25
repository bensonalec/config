#!/usr/bin/env bash
# Install VS Code extensions for both code-server (browser) and
# VS Code Server (Remote-SSH). Devbox is the source of truth.

set -euo pipefail

EXT_FILE="${EXT_FILE:-/workspace/dotfiles/vscode-extensions.txt}"
[ -f "$EXT_FILE" ] || { echo "Missing $EXT_FILE"; exit 1; }

install_to() {
    local dir="$1" label="$2"
    mkdir -p "$dir"
    echo "=== $label ==="
    while IFS= read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        if code-server --extensions-dir "$dir" --list-extensions 2>/dev/null \
                | grep -qi "^${ext}$"; then
            echo "  · $ext (already installed)"
            continue
        fi
        if code-server --extensions-dir "$dir" --install-extension "$ext" \
                >/dev/null 2>&1; then
            echo "  ✓ $ext"
        else
            echo "  ✗ $ext (failed; may not be on Open VSX)"
        fi
    done < "$EXT_FILE"
}

install_to "$HOME/.local/share/code-server/extensions" "code-server (browser)"
install_to "$HOME/.vscode-server/extensions"           "VS Code Server (Remote-SSH)"

echo
echo "Done. Reconnect VS Code Remote-SSH for changes to take effect."