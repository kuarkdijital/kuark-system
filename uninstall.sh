#!/bin/bash
# Kuark Universal Development System - Uninstaller
# Cleanly removes kuark-system from the system
#
# Usage: bash ~/.kuark/uninstall.sh

set -e

KUARK_HOME="$HOME/.kuark"
CLAUDE_HOME="$HOME/.claude"

# Markers for CLAUDE.md
MARKER_START="<!-- KUARK-SYSTEM-START -->"
MARKER_END="<!-- KUARK-SYSTEM-END -->"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}[KUARK]${NC} Uninstalling Kuark Development System..."

# ─────────────────────────────────────────────────────────────
# Step 1: Remove kuark section from ~/.claude/CLAUDE.md
# ─────────────────────────────────────────────────────────────

CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
    if grep -q "$MARKER_START" "$CLAUDE_MD" 2>/dev/null; then
        # Remove content between markers (inclusive)
        awk -v start="$MARKER_START" '
            $0 ~ start { skip=1; next }
            /<!-- KUARK-SYSTEM-END -->/ { skip=0; next }
            !skip { print }
        ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp"
        mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"

        # Remove empty file
        if [ ! -s "$CLAUDE_MD" ] || [ "$(wc -w < "$CLAUDE_MD" | tr -d ' ')" = "0" ]; then
            rm -f "$CLAUDE_MD"
            echo -e "${GREEN}[OK]${NC} CLAUDE.md removed (was only kuark content)"
        else
            echo -e "${GREEN}[OK]${NC} Kuark section removed from CLAUDE.md"
        fi
    else
        echo -e "${YELLOW}[SKIP]${NC} No kuark section found in CLAUDE.md"
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} No CLAUDE.md found"
fi

# ─────────────────────────────────────────────────────────────
# Step 2: Remove kuark hooks from ~/.claude/settings.json
# ─────────────────────────────────────────────────────────────

SETTINGS_FILE="$CLAUDE_HOME/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "kuark" "$SETTINGS_FILE" 2>/dev/null; then
        # Remove hooks that reference kuark
        jq '
            if .hooks then
                .hooks |= with_entries(
                    .value |= map(
                        .hooks |= map(select(.command | test("kuark") | not))
                    ) | map(select(.hooks | length > 0))
                ) |
                if (.hooks | length) == 0 then del(.hooks) else . end
            else . end
        ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" 2>/dev/null

        if [ -s "$SETTINGS_FILE.tmp" ]; then
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        else
            rm -f "$SETTINGS_FILE.tmp"
        fi
        echo -e "${GREEN}[OK]${NC} Kuark hooks removed from settings.json"
    else
        echo -e "${YELLOW}[SKIP]${NC} No kuark hooks found in settings.json"
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} No settings.json found"
fi

# ─────────────────────────────────────────────────────────────
# Step 3: Remove memory directory
# ─────────────────────────────────────────────────────────────

if [ -d "$CLAUDE_HOME/memory/kuark" ]; then
    rm -rf "$CLAUDE_HOME/memory/kuark"
    echo -e "${GREEN}[OK]${NC} Session memory removed"
else
    echo -e "${YELLOW}[SKIP]${NC} No session memory found"
fi

# ─────────────────────────────────────────────────────────────
# Step 4: Remove kuark installation
# ─────────────────────────────────────────────────────────────

if [ -d "$KUARK_HOME" ]; then
    rm -rf "$KUARK_HOME"
    echo -e "${GREEN}[OK]${NC} Kuark installation removed ($KUARK_HOME)"
else
    echo -e "${YELLOW}[SKIP]${NC} No installation found at $KUARK_HOME"
fi

# ─────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}[KUARK]${NC} Uninstall complete!"
echo ""
echo -e "  ${YELLOW}Note:${NC} .swarm/ directories in your projects are preserved."
echo -e "  ${YELLOW}Note:${NC} To remove them manually: rm -rf /path/to/project/.swarm"
echo ""
