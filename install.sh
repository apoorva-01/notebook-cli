#!/usr/bin/env bash
# One-line installer: curl -fsSL https://raw.githubusercontent.com/apoorva-01/notebook-cli/main/install.sh | bash
set -euo pipefail

if ! command -v pipx >/dev/null 2>&1; then
  echo "→ pipx not found — installing via Homebrew (macOS) or pip --user."
  if command -v brew >/dev/null 2>&1; then
    brew install pipx
  else
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath || true
  fi
fi

echo "→ Installing notebook-cli (this brings notebooklm-py + playwright)…"
pipx install --force git+https://github.com/apoorva-01/notebook-cli

cat <<'EOF'

✓ Installed.

One-time setup remaining:
  playwright install chromium      # ~150 MB download
  notebooklm login                  # opens browser; complete Google login

Then try:
  notebook --version
  notebook --help

EOF
