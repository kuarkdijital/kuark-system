#!/bin/bash
# Kuark updater — pull (if git) then re-run install for all platforms
set -e

KUARK_HOME="$HOME/.kuark"
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}[KUARK]${NC} Updating..."

if [ ! -d "$KUARK_HOME" ]; then
    echo -e "${RED}[ERROR]${NC} Not installed. Run install.sh first."
    exit 1
fi

OLD_VERSION=$(cat "$KUARK_HOME/version.txt" 2>/dev/null || echo "unknown")

if [ -d "$KUARK_HOME/.git" ]; then
    cd "$KUARK_HOME"
    echo -e "${CYAN}[KUARK]${NC} Fetching origin/main..."
    git fetch origin main 2>/dev/null || true
    git reset --hard origin/main 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC} Repo updated"
else
    echo -e "${YELLOW}[NOTE]${NC} ~/.kuark has no .git — reinstall from local checkout if needed:"
    echo -e "         bash /path/to/kuark-system/install.sh"
fi

bash "$KUARK_HOME/install.sh"

NEW_VERSION=$(cat "$KUARK_HOME/version.txt" 2>/dev/null || echo "local")
echo -e "${GREEN}[KUARK]${NC} Update complete! ${OLD_VERSION:0:8} → ${NEW_VERSION:0:8}"
echo -e "${YELLOW}[NOTE]${NC} Unpushed local edits: run install.sh from your checkout instead of update.sh"
