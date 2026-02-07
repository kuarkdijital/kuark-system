#!/bin/bash
# Kuark Universal Development System - Global Installer
# Installs kuark-system globally for Claude Code
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/kuarkdijital/kuark-system/main/install.sh | bash
#   OR
#   bash install.sh

set -e

# ─────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────

KUARK_HOME="$HOME/.kuark"
CLAUDE_HOME="$HOME/.claude"
REPO_URL="https://github.com/kuarkdijital/kuark-system.git"

# Markers for CLAUDE.md injection
MARKER_START="<!-- KUARK-SYSTEM-START -->"
MARKER_END="<!-- KUARK-SYSTEM-END -->"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────
# Prerequisites
# ─────────────────────────────────────────────────────────────

echo -e "${CYAN}[KUARK]${NC} Installing Kuark Universal Development System..."
echo ""

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} git is required but not installed."
    echo "  macOS: xcode-select --install"
    echo "  Linux: sudo apt-get install git"
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}[WARN]${NC} jq is not installed. Attempting to install..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install jq 2>/dev/null || {
                echo -e "${RED}[ERROR]${NC} Failed to install jq. Install manually: brew install jq"
                exit 1
            }
        else
            echo -e "${RED}[ERROR]${NC} Homebrew not found. Install jq manually: brew install jq"
            exit 1
        fi
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y jq 2>/dev/null || {
            echo -e "${RED}[ERROR]${NC} Failed to install jq. Install manually: sudo apt-get install jq"
            exit 1
        }
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq 2>/dev/null || {
            echo -e "${RED}[ERROR]${NC} Failed to install jq. Install manually: sudo yum install jq"
            exit 1
        }
    else
        echo -e "${RED}[ERROR]${NC} Cannot auto-install jq. Please install it manually."
        exit 1
    fi
    echo -e "${GREEN}[OK]${NC} jq installed"
fi

echo -e "${GREEN}[OK]${NC} Prerequisites satisfied"

# ─────────────────────────────────────────────────────────────
# Step 1: Clone or update repository
# ─────────────────────────────────────────────────────────────

if [ -d "$KUARK_HOME" ]; then
    echo -e "${CYAN}[KUARK]${NC} Existing installation found. Updating..."
    cd "$KUARK_HOME"
    git fetch origin main 2>/dev/null
    git reset --hard origin/main 2>/dev/null
    echo -e "${GREEN}[OK]${NC} Repository updated"
else
    echo -e "${CYAN}[KUARK]${NC} Cloning kuark-system to $KUARK_HOME..."
    git clone "$REPO_URL" "$KUARK_HOME" 2>/dev/null
    echo -e "${GREEN}[OK]${NC} Repository cloned"
fi

# ─────────────────────────────────────────────────────────────
# Step 2: Make hooks executable
# ─────────────────────────────────────────────────────────────

chmod +x "$KUARK_HOME"/hooks/*.sh 2>/dev/null || true
echo -e "${GREEN}[OK]${NC} Hook scripts made executable"

# ─────────────────────────────────────────────────────────────
# Step 3: Setup Claude Code directory
# ─────────────────────────────────────────────────────────────

mkdir -p "$CLAUDE_HOME"
mkdir -p "$CLAUDE_HOME/memory/kuark"

# ─────────────────────────────────────────────────────────────
# Step 4: Inject CLAUDE.md into ~/.claude/CLAUDE.md
# ─────────────────────────────────────────────────────────────

CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
KUARK_CLAUDE_MD="$KUARK_HOME/CLAUDE.md"

if [ ! -f "$KUARK_CLAUDE_MD" ]; then
    echo -e "${RED}[ERROR]${NC} CLAUDE.md not found in kuark-system"
    exit 1
fi

# Build the kuark section with markers
KUARK_SECTION="$MARKER_START
# Kuark Universal Development System (Auto-injected)
# Source: ~/.kuark/CLAUDE.md | Do not edit between markers
# Update: bash ~/.kuark/update.sh | Remove: bash ~/.kuark/uninstall.sh

$(cat "$KUARK_CLAUDE_MD")
$MARKER_END"

if [ -f "$CLAUDE_MD" ]; then
    if grep -q "$MARKER_START" "$CLAUDE_MD" 2>/dev/null; then
        # Replace existing kuark section
        # Use awk to replace content between markers
        awk -v start="$MARKER_START" -v replacement="$KUARK_SECTION" '
            $0 ~ start { printing=0; print replacement; next }
            /<!-- KUARK-SYSTEM-END -->/ { printing=1; next }
            printing!=0 { print }
            BEGIN { printing=1 }
        ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp"
        mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
        echo -e "${GREEN}[OK]${NC} CLAUDE.md updated (existing kuark section replaced)"
    else
        # Append to existing file
        echo "" >> "$CLAUDE_MD"
        echo "$KUARK_SECTION" >> "$CLAUDE_MD"
        echo -e "${GREEN}[OK]${NC} CLAUDE.md updated (kuark section appended)"
    fi
else
    echo "$KUARK_SECTION" > "$CLAUDE_MD"
    echo -e "${GREEN}[OK]${NC} CLAUDE.md created"
fi

# ─────────────────────────────────────────────────────────────
# Step 5: Merge hooks into ~/.claude/settings.json
# ─────────────────────────────────────────────────────────────

SETTINGS_FILE="$CLAUDE_HOME/settings.json"
HOOKS_SOURCE="$KUARK_HOME/.claude-hooks.json"

if [ ! -f "$HOOKS_SOURCE" ]; then
    echo -e "${YELLOW}[WARN]${NC} .claude-hooks.json not found. Skipping hooks setup."
else
    if [ -f "$SETTINGS_FILE" ]; then
        # Check if kuark hooks already exist
        if grep -q "kuark" "$SETTINGS_FILE" 2>/dev/null; then
            # Remove existing kuark hooks first, then re-add
            # Use jq to filter out kuark hooks from each event
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
        fi

        # Merge kuark hooks into settings
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
            echo -e "${GREEN}[OK]${NC} Hooks merged into existing settings.json"
        else
            rm -f "$SETTINGS_FILE.tmp"
            # Fallback: just add hooks key
            jq --argjson hooks "$(jq '.hooks' "$HOOKS_SOURCE")" '.hooks = $hooks' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" 2>/dev/null
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            echo -e "${GREEN}[OK]${NC} Hooks added to settings.json"
        fi
    else
        # No existing settings - create from hooks source with existing permissions pattern
        echo '{}' | jq --argjson hooks "$(jq '.hooks' "$HOOKS_SOURCE")" '. + {hooks: $hooks}' > "$SETTINGS_FILE"
        echo -e "${GREEN}[OK]${NC} settings.json created with kuark hooks"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Step 6: Record version
# ─────────────────────────────────────────────────────────────

cd "$KUARK_HOME"
git rev-parse HEAD > "$KUARK_HOME/version.txt" 2>/dev/null || echo "local" > "$KUARK_HOME/version.txt"

# ─────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[KUARK]${NC} Installation complete!"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}Installation:${NC}  $KUARK_HOME"
echo -e "  ${CYAN}Claude MD:${NC}     $CLAUDE_MD"
echo -e "  ${CYAN}Settings:${NC}      $SETTINGS_FILE"
echo -e "  ${CYAN}Memory:${NC}        $CLAUDE_HOME/memory/kuark/"
echo ""
echo -e "  ${CYAN}Agents:${NC}        16 specialized AI agents"
echo -e "  ${CYAN}Hooks:${NC}         SessionStart, PreToolUse, PostToolUse, Stop"
echo -e "  ${CYAN}Skills:${NC}        NestJS, NextJS, Prisma, Queue, DevOps, Security, API, UI, Python, Architect, Pencil"
echo ""
echo -e "  ${YELLOW}Usage:${NC}"
echo -e "    Start Claude Code in any project directory."
echo -e "    The swarm system will auto-initialize."
echo -e "    Say 'proje baslat' to begin a new project."
echo ""
echo -e "  ${YELLOW}Commands:${NC}"
echo -e "    Update:    bash ~/.kuark/update.sh"
echo -e "    Uninstall: bash ~/.kuark/uninstall.sh"
echo ""
