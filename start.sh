#!/usr/bin/env bash
set -euo pipefail

# ====== settings (override via env) ======
# Profile: minimal | standard | full
PROFILE="${PROFILE:-standard}"

# Individual overrides (1=install, 0=skip, auto=depends on profile)
INSTALL_CLAUDE="${INSTALL_CLAUDE:-auto}"
INSTALL_CODEX="${INSTALL_CODEX:-auto}"
INSTALL_NODEJS="${INSTALL_NODEJS:-auto}"
INSTALL_DEV_TOOLS="${INSTALL_DEV_TOOLS:-auto}"
INSTALL_EXTENDED_TOOLS="${INSTALL_EXTENDED_TOOLS:-auto}"
INSTALL_CODE_SERVER="${INSTALL_CODE_SERVER:-auto}"

# Other settings
TMUX_SESSION="${TMUX_SESSION:-main}"
ENABLE_REBOOT_TMUX="${ENABLE_REBOOT_TMUX:-1}"
USE_ZSH="${USE_ZSH:-auto}"
MIN_RAM_MB_FOR_NO_SWAP="${MIN_RAM_MB_FOR_NO_SWAP:-2048}"
SWAP_SIZE_GB="${SWAP_SIZE_GB:-3}"
# =========================================

# ====== profile resolution ======
resolve_profile() {
  case "$PROFILE" in
    minimal)
      [[ "$USE_ZSH" == "auto" ]] && USE_ZSH=0
      [[ "$INSTALL_CLAUDE" == "auto" ]] && INSTALL_CLAUDE=1
      [[ "$INSTALL_CODEX" == "auto" ]] && INSTALL_CODEX=0
      [[ "$INSTALL_NODEJS" == "auto" ]] && INSTALL_NODEJS=0
      [[ "$INSTALL_DEV_TOOLS" == "auto" ]] && INSTALL_DEV_TOOLS=0
      [[ "$INSTALL_EXTENDED_TOOLS" == "auto" ]] && INSTALL_EXTENDED_TOOLS=0
      [[ "$INSTALL_CODE_SERVER" == "auto" ]] && INSTALL_CODE_SERVER=0
      ;;
    standard)
      [[ "$USE_ZSH" == "auto" ]] && USE_ZSH=1
      [[ "$INSTALL_CLAUDE" == "auto" ]] && INSTALL_CLAUDE=1
      [[ "$INSTALL_CODEX" == "auto" ]] && INSTALL_CODEX=1
      [[ "$INSTALL_NODEJS" == "auto" ]] && INSTALL_NODEJS=1
      [[ "$INSTALL_DEV_TOOLS" == "auto" ]] && INSTALL_DEV_TOOLS=1
      [[ "$INSTALL_EXTENDED_TOOLS" == "auto" ]] && INSTALL_EXTENDED_TOOLS=0
      [[ "$INSTALL_CODE_SERVER" == "auto" ]] && INSTALL_CODE_SERVER=0
      ;;
    full)
      [[ "$USE_ZSH" == "auto" ]] && USE_ZSH=1
      [[ "$INSTALL_CLAUDE" == "auto" ]] && INSTALL_CLAUDE=1
      [[ "$INSTALL_CODEX" == "auto" ]] && INSTALL_CODEX=1
      [[ "$INSTALL_NODEJS" == "auto" ]] && INSTALL_NODEJS=1
      [[ "$INSTALL_DEV_TOOLS" == "auto" ]] && INSTALL_DEV_TOOLS=1
      [[ "$INSTALL_EXTENDED_TOOLS" == "auto" ]] && INSTALL_EXTENDED_TOOLS=1
      [[ "$INSTALL_CODE_SERVER" == "auto" ]] && INSTALL_CODE_SERVER=1
      ;;
    *)
      warn "Unknown profile: $PROFILE. Using 'standard'."
      PROFILE="standard"
      resolve_profile
      ;;
  esac
}

log() { echo -e "==> $*"; }
warn() { echo -e "!!  $*" >&2; }

resolve_profile
log "Using profile: $PROFILE"
# ================================

# --- ensure apt exists (Debian/Ubuntu) ---
if ! command -v apt >/dev/null 2>&1; then
  warn "This script currently supports Debian/Ubuntu (apt-based) systems."
  warn "apt not found. Exiting."
  exit 1
fi

log "Updating apt and installing base packages..."
sudo apt update
sudo apt install -y git tmux curl openssh-server ca-certificates

log "Enabling SSH service..."
sudo systemctl enable --now ssh 2>/dev/null || sudo systemctl enable --now sshd 2>/dev/null || true

# --- dev tools ---
if [[ "$INSTALL_DEV_TOOLS" == "1" ]]; then
  log "Installing dev tools (jq, htop, tree)..."
  sudo apt install -y jq htop tree
fi

if [[ "$INSTALL_EXTENDED_TOOLS" == "1" ]]; then
  log "Installing extended tools (ripgrep, fzf, bat, fd-find)..."
  sudo apt install -y ripgrep fzf fd-find
  # bat may be named 'batcat' on Ubuntu/Debian
  sudo apt install -y bat 2>/dev/null || sudo apt install -y batcat 2>/dev/null || true
  # Create 'bat' alias if batcat was installed
  if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    mkdir -p ~/.local/bin
    ln -sf "$(command -v batcat)" ~/.local/bin/bat
  fi
fi

# --- optionally install and set zsh as default shell ---
if [[ "$USE_ZSH" == "1" ]]; then
  log "Installing zsh..."
  sudo apt install -y zsh

  # Set zsh as default shell for current user (best effort)
  if command -v zsh >/dev/null 2>&1; then
    ZSH_PATH="$(command -v zsh)"
    log "Setting default shell to zsh for user: $USER"
    if [[ "$USER" == "root" ]]; then
      sudo chsh -s "$ZSH_PATH" root || true
    else
      sudo chsh -s "$ZSH_PATH" "$USER" || true
    fi
  fi
fi

# --- memory/swap guard (prevents OOM during Claude install on small VPS) ---
mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
mem_mb="$((mem_kb / 1024))"

has_swap="0"
if swapon --show 2>/dev/null | awk 'NR>1{exit 1} END{exit 0}'; then
  has_swap="0"
else
  has_swap="1"
fi

if [[ "$has_swap" == "0" && "$mem_mb" -lt "$MIN_RAM_MB_FOR_NO_SWAP" ]]; then
  log "Low RAM detected (${mem_mb}MB) and no swap found. Creating ${SWAP_SIZE_GB}G swapfile to avoid OOM..."
  sudo fallocate -l "${SWAP_SIZE_GB}G" /swapfile 2>/dev/null || \
    sudo dd if=/dev/zero of=/swapfile bs=1M "count=$((SWAP_SIZE_GB * 1024))"
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  grep -qE '^/swapfile\s' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
  echo 'vm.swappiness=20' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
  sudo sysctl -p /etc/sysctl.d/99-swappiness.conf >/dev/null || true
  log "Swap created and enabled."
else
  log "Memory/swap check: RAM=${mem_mb}MB, swap_present=${has_swap}. No swap changes needed."
fi

log "Current memory/swap status:"
free -h || true
swapon --show || true

# ---- git identity ----
if ! git config --global user.name >/dev/null 2>&1; then
  read -r -p "Git user.name (e.g. Anton Lenev): " GIT_NAME
  git config --global user.name "$GIT_NAME"
fi

if ! git config --global user.email >/dev/null 2>&1; then
  read -r -p "Git user.email (e.g. anton@example.com): " GIT_EMAIL
  git config --global user.email "$GIT_EMAIL"
fi

GIT_EMAIL="$(git config --global user.email)"

# ---- ssh key for git ----
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  log "Generating SSH key (~/.ssh/id_ed25519)..."
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519 -N ""
else
  log "SSH key already exists: ~/.ssh/id_ed25519"
fi

# ---- ssh config (helpful but optional) ----
SSH_CONFIG=~/.ssh/config
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if ! grep -q "Host github.com" "$SSH_CONFIG"; then
cat >> "$SSH_CONFIG" <<'EOF'

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF
fi

# ---- tmux auto-attach on SSH login (bash + zsh) ----
add_tmux_autoattach() {
  local rcfile="$1"
  [[ -f "$rcfile" ]] || touch "$rcfile"

  if ! grep -q "tmux new-session -A -s ${TMUX_SESSION}" "$rcfile"; then
cat >> "$rcfile" <<EOF

# Auto-attach tmux on interactive SSH login
if [ -n "\$PS1" ] && [ -z "\$TMUX" ] && [ -n "\$SSH_CONNECTION" ]; then
  tmux new-session -A -s ${TMUX_SESSION}
fi
EOF
  fi
}

add_tmux_autoattach "$HOME/.bashrc"
add_tmux_autoattach "$HOME/.zshrc"

# ---- optional: tmux session at reboot ----
if [[ "$ENABLE_REBOOT_TMUX" == "1" ]]; then
  log "Setting up crontab @reboot for tmux session..."
  ( crontab -l 2>/dev/null | grep -v "@reboot tmux new-session -d -s ${TMUX_SESSION}" || true
    echo "@reboot tmux new-session -d -s ${TMUX_SESSION} || true"
  ) | crontab -
fi

# ---- install Node.js (required for Codex) ----
if [[ "$INSTALL_NODEJS" == "1" ]]; then
  if command -v node >/dev/null 2>&1; then
    log "Node.js already installed: $(node --version)"
  else
    log "Installing Node.js LTS via NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
  fi
fi

# ---- install Claude Code ----
if [[ "$INSTALL_CLAUDE" == "1" ]]; then
  if command -v claude >/dev/null 2>&1; then
    log "Claude Code already installed: $(claude --version || true)"
  else
    log "Installing Claude Code via official installer..."
    curl -fsSL https://claude.ai/install.sh | bash
  fi
fi

# ---- install OpenAI Codex CLI ----
if [[ "$INSTALL_CODEX" == "1" ]]; then
  if command -v codex >/dev/null 2>&1; then
    log "OpenAI Codex already installed: $(codex --version 2>/dev/null || echo 'installed')"
  else
    if ! command -v npm >/dev/null 2>&1; then
      warn "npm not found. Skipping Codex installation. Install Node.js first."
    else
      log "Installing OpenAI Codex CLI via npm..."
      sudo npm install -g @openai/codex
    fi
  fi
fi

# ---- install code-server (VS Code in browser) ----
if [[ "$INSTALL_CODE_SERVER" == "1" ]]; then
  if command -v code-server >/dev/null 2>&1; then
    log "code-server already installed: $(code-server --version | head -1)"
  else
    log "Installing code-server..."
    curl -fsSL https://code-server.dev/install.sh | sh
    # Enable code-server service (but don't start it)
    sudo systemctl enable code-server@$USER 2>/dev/null || true
  fi
fi

echo
log "DONE. Profile: $PROFILE"
echo
echo "============================================================"
echo "                      NEXT STEPS"
echo "============================================================"
echo
echo "1) Add this SSH public key to GitHub/GitLab:"
echo "------------------------------------------------------------"
cat ~/.ssh/id_ed25519.pub
echo "------------------------------------------------------------"
echo
echo "2) Reconnect via SSH to auto-enter tmux, or run:"
echo "   tmux new -A -s ${TMUX_SESSION}"
echo
echo "3) Test GitHub SSH (after adding key):"
echo "   ssh -T git@github.com"

if [[ "$INSTALL_CLAUDE" == "1" ]]; then
  echo
  echo "4) Authenticate Claude Code:"
  echo "   claude --version && claude"
fi

if [[ "$INSTALL_CODEX" == "1" ]]; then
  echo
  echo "5) Configure OpenAI Codex:"
  echo "   export OPENAI_API_KEY=your-api-key"
  echo "   codex --help"
fi

if [[ "$INSTALL_CODE_SERVER" == "1" ]]; then
  echo
  echo "6) Start code-server (VS Code in browser):"
  echo "   sudo systemctl start code-server@$USER"
  echo "   # Access via: http://your-vps-ip:8080"
  echo "   # Password in: ~/.config/code-server/config.yaml"
fi

if [[ "$USE_ZSH" == "1" ]]; then
  echo
  echo "7) Re-login to apply zsh as default shell (or run: exec zsh)"
fi

echo
echo "============================================================"
echo "Installed tools summary:"
echo "  Profile: $PROFILE"
[[ "$INSTALL_CLAUDE" == "1" ]] && echo "  - Claude Code CLI"
[[ "$INSTALL_CODEX" == "1" ]] && echo "  - OpenAI Codex CLI"
[[ "$INSTALL_CODE_SERVER" == "1" ]] && echo "  - code-server (VS Code)"
[[ "$INSTALL_DEV_TOOLS" == "1" ]] && echo "  - Dev tools (jq, htop, tree)"
[[ "$INSTALL_EXTENDED_TOOLS" == "1" ]] && echo "  - Extended tools (rg, fzf, bat, fd)"
[[ "$USE_ZSH" == "1" ]] && echo "  - zsh shell"
echo "============================================================"
