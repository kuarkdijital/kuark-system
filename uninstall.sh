#!/bin/bash
# Kuark Universal Development System - Uninstaller
# Removes Claude + Cursor + Codex injections; preserves project .swarm/

set -e

KUARK_HOME="$HOME/.kuark"
CLAUDE_HOME="$HOME/.claude"
CURSOR_HOME="$HOME/.cursor"

MARKER_START="<!-- KUARK-SYSTEM-START -->"
MARKER_END="<!-- KUARK-SYSTEM-END -->"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}[KUARK]${NC} Uninstalling Kuark Development System..."

strip_markers() {
    local file="$1"
    local label="$2"
    if [ -f "$file" ] && grep -q "$MARKER_START" "$file" 2>/dev/null; then
        awk -v start="$MARKER_START" '
            $0 ~ start { skip=1; next }
            /<!-- KUARK-SYSTEM-END -->/ { skip=0; next }
            !skip { print }
        ' "$file" > "$file.tmp"
        mv "$file.tmp" "$file"
        if [ ! -s "$file" ] || [ "$(wc -w < "$file" | tr -d ' ')" = "0" ]; then
            rm -f "$file"
            echo -e "${GREEN}[OK]${NC} $label removed (was only kuark)"
        else
            echo -e "${GREEN}[OK]${NC} Kuark section removed from $label"
        fi
    else
        echo -e "${YELLOW}[SKIP]${NC} No kuark section in $label"
    fi
}

strip_markers "$CLAUDE_HOME/CLAUDE.md" "Claude CLAUDE.md"
strip_markers "$HOME/AGENTS.md" "~/AGENTS.md"

# Claude hooks
SETTINGS_FILE="$CLAUDE_HOME/settings.json"
if [ -f "$SETTINGS_FILE" ] && grep -q "kuark" "$SETTINGS_FILE" 2>/dev/null; then
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
fi

# Claude agents + commands
rm -f "$CLAUDE_HOME"/agents/kuark-*.md 2>/dev/null || true
rm -f "$CLAUDE_HOME"/commands/kuark-*.md 2>/dev/null || true
echo -e "${GREEN}[OK]${NC} Claude kuark agents/commands removed"

# Cursor
rm -f "$CURSOR_HOME/rules/kuark.mdc" 2>/dev/null || true
rm -rf "$CURSOR_HOME"/skills/kuark-* 2>/dev/null || true
# Restore note on swarm-team — leave v2 pointer or remove if we wrote it
if [ -f "$CURSOR_HOME/skills/swarm-team/SKILL.md" ] && grep -q 'Kuark Swarm Team (v2)' "$CURSOR_HOME/skills/swarm-team/SKILL.md" 2>/dev/null; then
    rm -rf "$CURSOR_HOME/skills/swarm-team"
    echo -e "${GREEN}[OK]${NC} Cursor swarm-team v2 pointer removed"
fi
echo -e "${GREEN}[OK]${NC} Cursor kuark rule/skills removed"

if [ -d "$CLAUDE_HOME/memory/kuark" ]; then
    rm -rf "$CLAUDE_HOME/memory/kuark"
    echo -e "${GREEN}[OK]${NC} Session memory removed"
fi

# kuark symlink
for target in "$HOME/.local/bin/kuark" "/usr/local/bin/kuark"; do
    if [ -L "$target" ]; then
        rm -f "$target"
        echo -e "${GREEN}[OK]${NC} Removed symlink $target"
    fi
done

if [ -d "$KUARK_HOME" ]; then
    rm -rf "$KUARK_HOME"
    echo -e "${GREEN}[OK]${NC} Removed $KUARK_HOME"
fi

echo ""
echo -e "${GREEN}[KUARK]${NC} Uninstall complete!"
echo -e "  ${YELLOW}Note:${NC} Project .swarm/ directories are preserved."
echo ""
