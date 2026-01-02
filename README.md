# 🚀 Claude Code VPS Bootstrap

```
curl -fsSL https://raw.githubusercontent.com/m0rg0t/quick-start-claude-code-on-vps/refs/heads/main/start.sh -o bootstrap.sh && chmod +x bootstrap.sh && ./bootstrap.sh
```

One-shot bash script to prepare a **clean VPS** for remote development with **Claude Code**.

This setup is designed so that:
- you can **reconnect to a live development session via SSH**,
- Claude Code **never loses execution context**,
- Git works **via SSH without passwords**,
- everything is reproducible and fast.

Works best on **Ubuntu / Debian-based VPS** (Ubuntu 20.04 / 22.04 / 24.04).

---

## ✨ What This Script Does

After running the script, your VPS will have:

### 🔐 SSH & Git
- Installs `git`
- Configures `git user.name` and `git user.email`
- Generates an **Ed25519 SSH key** (`~/.ssh/id_ed25519`) if none exists
- Configures `~/.ssh/config` for GitHub
- Prints the **public SSH key** for GitHub / GitLab

### 🧠 Persistent Development Session
- Installs **tmux**
- Automatically:
  - attaches to a tmux session on every SSH login
  - creates the session if it doesn’t exist
- (Optional) starts the tmux session **on VPS reboot**

### 🤖 Claude Code
- Installs **Claude Code CLI** using the official installer
- No editors or IDEs are installed — Claude Code operates via shell

### 🧱 Minimal & Flexible
- No unnecessary packages
- Languages, runtimes, Docker, etc. are installed **on demand by Claude Code**

---

## 🖥️ Quick Start

### 1. Connect to your VPS
```bash
ssh user@your-vps-ip
