# 🚀 Claude Code VPS Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/m0rg0t/quick-start-claude-code-on-vps/refs/heads/main/start.sh -o bootstrap.sh && chmod +x bootstrap.sh && ./bootstrap.sh
```

One-shot bash script to prepare a **clean VPS** for remote AI-assisted development with **Claude Code**, **OpenAI Codex**, and optional **VS Code** in browser.

This setup is designed so that:
- you can **reconnect to a live development session via SSH**
- Claude Code **never loses execution context**
- Git works **via SSH without passwords**
- everything is reproducible and fast

Works best on **Ubuntu / Debian-based VPS** (Ubuntu 20.04 / 22.04 / 24.04).

---

## 📦 Installation Profiles

The script supports three profiles with different tool sets:

| Component | `minimal` | `standard` | `full` |
|-----------|:---------:|:----------:|:------:|
| Git + SSH + tmux | ✅ | ✅ | ✅ |
| zsh shell | ❌ | ✅ | ✅ |
| Claude Code CLI | ✅ | ✅ | ✅ |
| OpenAI Codex CLI | ❌ | ✅ | ✅ |
| Node.js LTS | ❌ | ✅ | ✅ |
| Dev tools (jq, htop, tree) | ❌ | ✅ | ✅ |
| Extended tools (rg, fzf, bat, fd) | ❌ | ❌ | ✅ |
| code-server (VS Code in browser) | ❌ | ❌ | ✅ |

### Usage

```bash
# Standard profile (default)
./bootstrap.sh

# Minimal profile (only Claude Code + essentials)
PROFILE=minimal ./bootstrap.sh

# Full profile (everything included)
PROFILE=full ./bootstrap.sh

# Custom: minimal + Codex
PROFILE=minimal INSTALL_CODEX=1 INSTALL_NODEJS=1 ./bootstrap.sh
```

---

## ✨ What This Script Does

### 🔐 SSH & Git
- Installs `git`
- Configures `git user.name` and `git user.email`
- Generates an **Ed25519 SSH key** (`~/.ssh/id_ed25519`) if none exists
- Configures `~/.ssh/config` for GitHub
- Prints the **public SSH key** for GitHub / GitLab

### 🧠 Persistent Development Session
- Installs **tmux**
- Automatically attaches to tmux session on every SSH login
- (Optional) starts the tmux session on VPS reboot

### 🤖 AI Coding Tools
- **Claude Code CLI** — Anthropic's AI coding assistant
- **OpenAI Codex CLI** — OpenAI's coding assistant (standard/full profiles)

### 🖥️ Remote IDE (full profile)
- **code-server** — VS Code running in your browser
- Access via `http://your-vps-ip:8080`

### 🛠️ Developer Tools
- **Dev tools**: jq, htop, tree (standard/full profiles)
- **Extended tools**: ripgrep, fzf, bat, fd-find (full profile)

---

## ⚙️ Configuration Variables

All settings can be overridden via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PROFILE` | `standard` | Profile: `minimal`, `standard`, or `full` |
| `INSTALL_CLAUDE` | `auto` | Install Claude Code CLI |
| `INSTALL_CODEX` | `auto` | Install OpenAI Codex CLI |
| `INSTALL_NODEJS` | `auto` | Install Node.js LTS |
| `INSTALL_DEV_TOOLS` | `auto` | Install jq, htop, tree |
| `INSTALL_EXTENDED_TOOLS` | `auto` | Install rg, fzf, bat, fd |
| `INSTALL_CODE_SERVER` | `auto` | Install code-server |
| `USE_ZSH` | `auto` | Install and set zsh as default shell |
| `TMUX_SESSION` | `main` | tmux session name |
| `ENABLE_REBOOT_TMUX` | `1` | Enable @reboot cron for tmux |
| `MIN_RAM_MB_FOR_NO_SWAP` | `2048` | RAM threshold before creating swap |
| `SWAP_SIZE_GB` | `3` | Swap size when needed |

**Note**: `auto` means the value is determined by the selected profile. Use `1` or `0` to override.

---

## 🖥️ Quick Start

### 1. Connect to your VPS
```bash
ssh user@your-vps-ip
```

### 2. Run the bootstrap script
```bash
curl -fsSL https://raw.githubusercontent.com/m0rg0t/quick-start-claude-code-on-vps/refs/heads/main/start.sh -o bootstrap.sh && chmod +x bootstrap.sh && ./bootstrap.sh
```

### 3. Add SSH key to GitHub
Copy the displayed SSH public key and add it to your GitHub/GitLab account.

### 4. Reconnect via SSH
Your tmux session will start automatically.

### 5. Authenticate AI tools
```bash
# Claude Code
claude

# OpenAI Codex (set your API key first)
export OPENAI_API_KEY=your-key
codex
```

---

## 🔌 Remote IDE Access

### VS Code Remote SSH (any profile)
Your VPS is ready for VS Code Remote SSH extension out of the box.

### code-server (full profile)
```bash
# Start code-server
sudo systemctl start code-server@$USER

# Access in browser
http://your-vps-ip:8080

# Find password
cat ~/.config/code-server/config.yaml
```

---

## 📝 License

MIT
