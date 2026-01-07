# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

One-shot bash script to bootstrap a clean VPS for remote AI-assisted development with Claude Code, OpenAI Codex, and optional VS Code in browser. Supports installation profiles for flexible setup.

## Bootstrap Command

```bash
# Standard profile (Claude + Codex + dev tools)
curl -fsSL https://raw.githubusercontent.com/m0rg0t/quick-start-claude-code-on-vps/refs/heads/main/start.sh -o bootstrap.sh && chmod +x bootstrap.sh && ./bootstrap.sh

# With specific profile
PROFILE=full ./bootstrap.sh
```

## Architecture

**Single-file design**: `start.sh` is a self-contained, idempotent bash script (safe to run multiple times).

**Target systems**: Debian/Ubuntu (apt-based) - Ubuntu 20.04, 22.04, 24.04

**Error handling**: Uses `set -euo pipefail` with best-effort fallbacks (`|| true`) for non-critical operations.

## Profile System

| Profile | Components |
|---------|------------|
| `minimal` | Git, SSH, tmux, Claude Code |
| `standard` | + zsh, Codex, Node.js, dev tools (jq, htop, tree) |
| `full` | + extended tools (rg, fzf, bat, fd), code-server |

Profile is resolved via `resolve_profile()` function which sets `auto` values based on selected profile.

## Configuration

All settings use `auto` default (determined by profile) and can be overridden:

| Variable | Default | Description |
|----------|---------|-------------|
| `PROFILE` | `standard` | Profile: minimal, standard, full |
| `INSTALL_CLAUDE` | `auto` | Claude Code CLI |
| `INSTALL_CODEX` | `auto` | OpenAI Codex CLI |
| `INSTALL_NODEJS` | `auto` | Node.js LTS (required for Codex) |
| `INSTALL_DEV_TOOLS` | `auto` | jq, htop, tree |
| `INSTALL_EXTENDED_TOOLS` | `auto` | ripgrep, fzf, bat, fd-find |
| `INSTALL_CODE_SERVER` | `auto` | VS Code in browser |
| `USE_ZSH` | `auto` | zsh as default shell |
| `TMUX_SESSION` | `main` | tmux session name |
| `ENABLE_REBOOT_TMUX` | `1` | @reboot cron for tmux |
| `MIN_RAM_MB_FOR_NO_SWAP` | `2048` | RAM threshold for swap |
| `SWAP_SIZE_GB` | `3` | Swap size when needed |

Example with custom settings:
```bash
PROFILE=minimal INSTALL_CODEX=1 INSTALL_NODEJS=1 ./start.sh
```

## Script Flow

1. Resolve profile settings (`resolve_profile()`)
2. System check (apt required)
3. Base packages: git, tmux, curl, openssh-server, ca-certificates
4. Dev tools installation (if enabled)
5. Optional zsh installation
6. Memory/swap guard (creates swap if RAM < 2048MB)
7. Git identity configuration (interactive prompts)
8. SSH key generation (Ed25519)
9. tmux auto-attach on SSH login
10. Optional @reboot cron for tmux
11. Node.js installation (if enabled)
12. Claude Code CLI installation
13. OpenAI Codex CLI installation (if enabled)
14. code-server installation (if enabled)

## Testing

Manual testing on fresh VPS instances. Script is idempotent - operations check for existing state before modifying.

## Key Implementation Details

- **batcat workaround**: Ubuntu names `bat` as `batcat`. Script creates symlink in `~/.local/bin/bat`.
- **Codex requires Node.js**: Script checks for npm before installing Codex, warns if missing.
- **code-server**: Enabled as systemd service but not started automatically.
