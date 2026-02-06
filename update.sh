#!/bin/bash
# Kuark Universal Development System - Updater
# Updates the global kuark-system installation
#
# Usage: bash ~/.kuark/update.sh

set -e

KUARK_HOME="$HOME/.kuark"
CLAUDE_HOME="$HOME/.claude"

# Markers for CLAUDE.md injection
MARKER_START="<!-- KUARK-SYSTEM-START -->"
MARKER_END="<!-- KUARK-SYSTEM-END -->"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}[KUARK]${NC} Updating Kuark Development System..."

# Check installation
if [ ! -d "$KUARK_HOME" ]; then
    echo -e "${RED}[ERROR]${NC} Kuark not installed. Run install.sh first."
    echo "  curl -sSL https://raw.githubusercontent.com/kuarkdijital/kuark-system/main/install.sh | bash"
    exit 1
fi

# Store current version
OLD_VERSION=$(cat "$KUARK_HOME/version.txt" 2>/dev/null || echo "unknown")

# Pull latest
cd "$KUARK_HOME"
echo -e "${CYAN}[KUARK]${NC} Fetching latest changes..."
git fetch origin main 2>/dev/null
git reset --hard origin/main 2>/dev/null
echo -e "${GREEN}[OK]${NC} Repository updated"

# Make hooks executable
chmod +x "$KUARK_HOME"/hooks/*.sh 2>/dev/null || true

# Update CLAUDE.md
CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
KUARK_CLAUDE_MD="$KUARK_HOME/CLAUDE.md"

if [ -f "$KUARK_CLAUDE_MD" ] && [ -f "$CLAUDE_MD" ]; then
    KUARK_SECTION="$MARKER_START
# Kuark Universal Development System (Auto-injected)
# Source: ~/.kuark/CLAUDE.md | Do not edit between markers
# Update: bash ~/.kuark/update.sh | Remove: bash ~/.kuark/uninstall.sh

$(cat "$KUARK_CLAUDE_MD")
$MARKER_END"

    if grep -q "$MARKER_START" "$CLAUDE_MD" 2>/dev/null; then
        awk -v start="$MARKER_START" -v replacement="$KUARK_SECTION" '
            $0 ~ start { printing=0; print replacement; next }
            /<!-- KUARK-SYSTEM-END -->/ { printing=1; next }
            printing!=0 { print }
            BEGIN { printing=1 }
        ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp"
        mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    else
        echo "" >> "$CLAUDE_MD"
        echo "$KUARK_SECTION" >> "$CLAUDE_MD"
    fi
    echo -e "${GREEN}[OK]${NC} CLAUDE.md updated"
fi

# Update hooks in settings.json
SETTINGS_FILE="$CLAUDE_HOME/settings.json"
HOOKS_SOURCE="$KUARK_HOME/.claude-hooks.json"

if [ -f "$HOOKS_SOURCE" ] && [ -f "$SETTINGS_FILE" ]; then
    # Remove existing kuark hooks
    CLEANED=$(jq '
        if .hooks then
            .hooks |= with_entries(
                .value |= map(
                    .hooks |= map(select(.command | test("kuark") | not))
                ) | map(select(.hooks | length > 0))
            )
        else . end
    ' "$SETTINGS_FILE" 2>/dev/null || cat "$SETTINGS_FILE")
    echo "$CLEANED" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

    # Re-add kuark hooks
    KUARK_HOOKS=$(cat "$HOOKS_SOURCE")
    jq -s '
        (.[0] // {}) as $existing |
        (.[1] // {}) as $kuark |
        $existing * {
            hooks: (
                ($existing.hooks // {}) as $eh |
                ($kuark.hooks // {}) as $kh |
                ($eh | keys) + ($kh | keys) | unique | map(
                    . as $key |
                    (($eh[$key] // []) + ($kh[$key] // [])) |
                    {($key): .}
                ) | add // {}
            )
        }
    ' "$SETTINGS_FILE" <(echo "$KUARK_HOOKS") > "$SETTINGS_FILE.tmp" 2>/dev/null

    if [ -s "$SETTINGS_FILE.tmp" ]; then
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    else
        rm -f "$SETTINGS_FILE.tmp"
    fi
    echo -e "${GREEN}[OK]${NC} Hooks updated in settings.json"
fi

# Record new version
NEW_VERSION=$(cd "$KUARK_HOME" && git rev-parse HEAD 2>/dev/null || echo "local")
echo "$NEW_VERSION" > "$KUARK_HOME/version.txt"

echo ""
echo -e "${GREEN}[KUARK]${NC} Update complete!"
echo -e "  ${CYAN}Old:${NC} ${OLD_VERSION:0:8}"
echo -e "  ${CYAN}New:${NC} ${NEW_VERSION:0:8}"
echo ""
