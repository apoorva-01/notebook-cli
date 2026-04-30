#!/usr/bin/env bash
# One-line installer: curl -fsSL https://raw.githubusercontent.com/apoorva-01/notebook-cli/main/install.sh | bash
set -euo pipefail

DEST_DIR="${HOME}/.local/bin"
DEST="${DEST_DIR}/notebook"
SRC_URL="https://raw.githubusercontent.com/apoorva-01/notebook-cli/main/notebook"

mkdir -p "${DEST_DIR}"
echo "→ Downloading notebook to ${DEST}"
curl -fsSL "${SRC_URL}" -o "${DEST}"
chmod +x "${DEST}"

if ! command -v notebooklm >/dev/null 2>&1; then
  cat <<EOF

⚠️  The underlying \`notebooklm\` CLI is not installed.

Install it (one-time):
    pipx install notebooklm-py
    pipx inject notebooklm-py playwright
    ~/.local/pipx/venvs/notebooklm-py/bin/playwright install chromium
    notebooklm login

Then run:
    notebook --help
EOF
  exit 0
fi

echo "✓ Installed. Try: notebook --help"
case ":${PATH}:" in
  *":${DEST_DIR}:"*) ;;
  *) echo "ℹ️  Note: ${DEST_DIR} is not in your PATH. Add it to your shell profile."; ;;
esac
