#!/usr/bin/env bash
set -euo pipefail

# ====== настройки (можно менять) ======
TMUX_SESSION="${TMUX_SESSION:-main}"
ENABLE_REBOOT_TMUX="${ENABLE_REBOOT_TMUX:-1}"   # 1 = включить @reboot, 0 = выключить
INSTALL_CLAUDE="${INSTALL_CLAUDE:-1}"           # 1 = ставить claude code
# ======================================

echo "==> Updating apt and installing base packages..."
sudo apt update
sudo apt install -y git tmux curl openssh-server ca-certificates

echo "==> Enabling SSH service..."
sudo systemctl enable --now ssh || sudo systemctl enable --now sshd || true

# ---- git identity ----
if ! git config --global user.name >/dev/null 2>&1; then
  read -r -p "Git user.name (например: Anton Lenev): " GIT_NAME
  git config --global user.name "$GIT_NAME"
fi

if ! git config --global user.email >/dev/null 2>&1; then
  read -r -p "Git user.email (например: anton@example.com): " GIT_EMAIL
  git config --global user.email "$GIT_EMAIL"
fi

GIT_EMAIL="$(git config --global user.email)"

# ---- ssh key for git ----
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  echo "==> Generating SSH key (~/.ssh/id_ed25519)..."
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519 -N ""
else
  echo "==> SSH key already exists: ~/.ssh/id_ed25519"
fi

# ---- ssh config (не обязателен, но полезен) ----
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

# ---- tmux auto-attach on SSH login ----
BASHRC=~/.bashrc
if ! grep -q "tmux new-session -A -s ${TMUX_SESSION}" "$BASHRC"; then
cat >> "$BASHRC" <<EOF

# Auto-attach tmux on interactive SSH login
if [ -n "\$PS1" ] && [ -z "\$TMUX" ] && [ -n "\$SSH_CONNECTION" ]; then
  tmux new-session -A -s ${TMUX_SESSION}
fi
EOF
fi

# ---- optional: tmux session at reboot ----
if [[ "$ENABLE_REBOOT_TMUX" == "1" ]]; then
  echo "==> Setting up crontab @reboot for tmux session..."
  # добавим строку, если её нет
  ( crontab -l 2>/dev/null | grep -v "@reboot tmux new-session -d -s ${TMUX_SESSION}" || true
    echo "@reboot tmux new-session -d -s ${TMUX_SESSION} || true"
  ) | crontab -
fi

# ---- install Claude Code ----
if [[ "$INSTALL_CLAUDE" == "1" ]]; then
  if command -v claude >/dev/null 2>&1; then
    echo "==> Claude Code already installed: $(claude --version || true)"
  else
    echo "==> Installing Claude Code via official installer..."
    curl -fsSL https://claude.ai/install.sh | bash
  fi
fi

echo
echo "==> DONE."
echo
echo "Next steps:"
echo "1) Add this SSH public key to GitHub/GitLab:"
echo "------------------------------------------------------------"
cat ~/.ssh/id_ed25519.pub
echo "------------------------------------------------------------"
echo "2) Reconnect via SSH to auto-enter tmux, or run: tmux new -A -s ${TMUX_SESSION}"
echo "3) Verify Claude Code: claude --version (then claude auth/login if needed)"
echo "4) Test GitHub SSH (after adding key): ssh -T git@github.com"
