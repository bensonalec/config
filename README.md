# devbox

Personal development environment, running on Fly.io. A single canonical
artifact spanning image definition, deployment config, and user
configuration — designed so that destroying the running instance and
rebuilding from this repo produces an identical environment in ~30
minutes.

## Architecture

- **Image** (`Dockerfile`) — system tooling, language build deps, baked
  tools (mise, code-server, starship, antidote, Tailscale). Stateless.
- **Deployment** (`fly.toml`) — a single Fly Machine in `phx`, with a
  30GB persistent volume mounted at `/workspace`. Auto-suspends when
  idle.
- **Bootstrap** (`setup.sh`) — first-boot script that clones this repo,
  symlinks configs into place, and kicks off `mise install`.
- **User config** (`dotfiles/`) — shell, prompt, editor extensions,
  language toolchain pins. Source of truth for "how I work."

The separation between image and config is deliberate. The image
defines capabilities; the volume holds identity. Rebuilds replace the
image without touching state; volume wipes test that bootstrap is
truly idempotent.

## Quick start (fresh deploy)

```bash
tailscale ssh dev@devbox    # or: fly ssh console
curl -fsSL https://raw.githubusercontent.com/bensonalec/devbox/main/setup.sh
-o /tmp/setup.sh && chmod +x /tmp/setup.sh && /tmp/setup.sh

```

## Daily access

- **Browser** — `https://alec-devbox.fly.dev`, code-server in any browser
- **Native VS Code** — Remote-SSH to `devbox` (via Tailscale)
- **Terminal** — `tailscale ssh dev@devbox` from any device on the tailnet

## Layout

| Path                                    | Purpose                           |
| --------------------------------------- | --------------------------------- |
| `Dockerfile`                            | Image definition                  |
| `fly.toml`                              | Deployment config                 |
| `setup.sh`                              | First-boot bootstrap              |
| `dotfiles/zshrc-extras`                 | Shell config                      |
| `dotfiles/zsh_plugins.txt`              | Antidote plugin list              |
| `dotfiles/starship.toml`                | Prompt                            |
| `dotfiles/mise/config.toml`             | Language toolchain pins           |
| `dotfiles/vscode-extensions.txt`        | VS Code extension set             |
| `dotfiles/install-vscode-extensions.sh` | Extension installer               |
| `dotfiles/.gitconfig`                   | Git config (included into global) |

## Secrets

`dotfiles/zshrc-local` holds API keys and machine-specific overrides.
Gitignored. Sourced from `zshrc-extras` if present.

## Validation

This repo has been rebuilt-from-scratch successfully. The rebuild
procedure (destroy machine, destroy volume, fly deploy, run setup.sh)
produces a working environment in approximately 30 minutes, dominated
by the Erlang/OTP compile.

See `docs/runbook.md` for the rebuild procedure and `docs/architecture.md`
for design decisions.
