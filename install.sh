#!/bin/bash
# Kuark Universal Development System - Global Installer
# Installs for Cursor + Claude Code + Codex (equal platforms)
#
# Usage:
#   bash install.sh                          # from local checkout (preferred)
#   curl -sSL .../install.sh | bash          # from GitHub

set -e

KUARK_HOME="$HOME/.kuark"
CLAUDE_HOME="$HOME/.claude"
CURSOR_HOME="$HOME/.cursor"
REPO_URL="https://github.com/kuarkdijital/kuark-system.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"

MARKER_START="<!-- KUARK-SYSTEM-START -->"
MARKER_END="<!-- KUARK-SYSTEM-END -->"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}[KUARK]${NC} Installing Kuark Universal Development System..."
echo -e "${CYAN}[KUARK]${NC} Targets: Cursor · Claude Code · Codex"
echo ""

# ── Prerequisites ────────────────────────────────────────────

if ! command -v git &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} git is required."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}[WARN]${NC} jq missing — attempting install..."
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
        brew install jq 2>/dev/null || { echo -e "${RED}[ERROR]${NC} Install jq: brew install jq"; exit 1; }
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y jq 2>/dev/null || { echo -e "${RED}[ERROR]${NC} Install jq manually"; exit 1; }
    else
        echo -e "${RED}[ERROR]${NC} Install jq manually."; exit 1
    fi
fi
echo -e "${GREEN}[OK]${NC} Prerequisites satisfied"

# ── Step 1: Populate ~/.kuark ────────────────────────────────

sync_from_local() {
    local src="$1"
    mkdir -p "$KUARK_HOME"
    # Prefer rsync; fall back to tar
    if command -v rsync &> /dev/null; then
        rsync -a --delete \
            --exclude '.git' \
            --exclude '.DS_Store' \
            --exclude '.swarm' \
            --exclude '.claude/worktrees' \
            --exclude 'team-stats' \
            "$src/" "$KUARK_HOME/"
    else
        (cd "$src" && tar cf - \
            --exclude '.git' --exclude '.DS_Store' --exclude '.swarm' \
            --exclude '.claude/worktrees' --exclude 'team-stats' .) \
            | (cd "$KUARK_HOME" && tar xf -)
    fi
}

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/CLAUDE.md" ] && [ -d "$SCRIPT_DIR/agents" ]; then
    echo -e "${CYAN}[KUARK]${NC} Syncing from local checkout: $SCRIPT_DIR"
    sync_from_local "$SCRIPT_DIR"
    echo -e "${GREEN}[OK]${NC} ~/.kuark synced from local repo"
elif [ -d "$KUARK_HOME/.git" ]; then
    echo -e "${CYAN}[KUARK]${NC} Updating existing install from origin/main..."
    cd "$KUARK_HOME"
    git fetch origin main 2>/dev/null
    git reset --hard origin/main 2>/dev/null
    echo -e "${GREEN}[OK]${NC} Repository updated"
else
    echo -e "${CYAN}[KUARK]${NC} Cloning to $KUARK_HOME..."
    git clone "$REPO_URL" "$KUARK_HOME" 2>/dev/null
    echo -e "${GREEN}[OK]${NC} Repository cloned"
fi

chmod +x "$KUARK_HOME"/hooks/*.sh 2>/dev/null || true
chmod +x "$KUARK_HOME"/kuark 2>/dev/null || true
chmod +x "$KUARK_HOME"/bin/*.sh 2>/dev/null || true
echo -e "${GREEN}[OK]${NC} Scripts executable"

# ── Step 2: kuark CLI on PATH ────────────────────────────────

KUARK_BIN_SRC="$KUARK_HOME/kuark"
KUARK_BIN_INSTALLED=""
for target in "$HOME/.local/bin" "/usr/local/bin"; do
    if [ -d "$target" ] && [ -w "$target" ]; then
        ln -sf "$KUARK_BIN_SRC" "$target/kuark"
        KUARK_BIN_INSTALLED="$target/kuark"
        echo -e "${GREEN}[OK]${NC} kuark CLI: $KUARK_BIN_INSTALLED"
        break
    fi
done
if [ -z "$KUARK_BIN_INSTALLED" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$KUARK_BIN_SRC" "$HOME/.local/bin/kuark"
    KUARK_BIN_INSTALLED="$HOME/.local/bin/kuark"
    echo -e "${GREEN}[OK]${NC} kuark CLI: $KUARK_BIN_INSTALLED"
    echo -e "${YELLOW}[NOTE]${NC} Ensure ~/.local/bin is on PATH"
fi

# ── inject_marked_file helper ────────────────────────────────

inject_marked_file() {
    local dest="$1"
    local source_md="$2"
    local label="$3"

    if [ ! -f "$source_md" ]; then
        echo -e "${YELLOW}[WARN]${NC} Missing $source_md — skip $label"
        return 0
    fi

    SECTION_TMP=$(mktemp)
    {
        echo "$MARKER_START"
        echo "# Kuark Universal Development System (Auto-injected)"
        echo "# Source: $source_md | Do not edit between markers"
        echo "# Update: bash ~/.kuark/update.sh | Remove: bash ~/.kuark/uninstall.sh"
        echo ""
        cat "$source_md"
        echo "$MARKER_END"
    } > "$SECTION_TMP"

    mkdir -p "$(dirname "$dest")"
    if [ -f "$dest" ] && grep -q "$MARKER_START" "$dest" 2>/dev/null; then
        python3 -c "
import sys
ms, me = sys.argv[1], sys.argv[2]
content = open(sys.argv[3]).read()
section = open(sys.argv[4]).read()
i = content.index(ms)
j = content.index(me) + len(me)
open(sys.argv[3], 'w').write(content[:i] + section + content[j:])
" "$MARKER_START" "$MARKER_END" "$dest" "$SECTION_TMP"
        echo -e "${GREEN}[OK]${NC} $label updated (section replaced)"
    elif [ -f "$dest" ]; then
        echo "" >> "$dest"
        cat "$SECTION_TMP" >> "$dest"
        echo -e "${GREEN}[OK]${NC} $label updated (section appended)"
    else
        cp "$SECTION_TMP" "$dest"
        echo -e "${GREEN}[OK]${NC} $label created"
    fi
    rm -f "$SECTION_TMP"
}

# ── Step 3: Claude Code agents + commands + CLAUDE.md + hooks ─

if [ -x "$KUARK_HOME/bin/generate-claude-agents.sh" ]; then
    "$KUARK_HOME/bin/generate-claude-agents.sh" >/dev/null 2>&1 && \
      echo -e "${GREEN}[OK]${NC} Claude sub-agents → ~/.claude/agents/kuark-*.md" || \
      echo -e "${YELLOW}[WARN]${NC} generate-claude-agents.sh failed"
fi

if [ -d "$KUARK_HOME/commands" ]; then
    mkdir -p "$HOME/.claude/commands"
    cp "$KUARK_HOME/commands/"*.md "$HOME/.claude/commands/" 2>/dev/null || true
    cmd_count=$(ls "$KUARK_HOME/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
    [ "$cmd_count" -gt 0 ] && echo -e "${GREEN}[OK]${NC} $cmd_count Claude slash commands installed"
fi

mkdir -p "$CLAUDE_HOME/memory/kuark"
inject_marked_file "$CLAUDE_HOME/CLAUDE.md" "$KUARK_HOME/CLAUDE.md" "Claude CLAUDE.md"

SETTINGS_FILE="$CLAUDE_HOME/settings.json"
HOOKS_SOURCE="$KUARK_HOME/.claude-hooks.json"
if [ -f "$HOOKS_SOURCE" ]; then
    if [ -f "$SETTINGS_FILE" ]; then
        if grep -q "kuark" "$SETTINGS_FILE" 2>/dev/null; then
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
            echo -e "${GREEN}[OK]${NC} Claude hooks merged"
        else
            rm -f "$SETTINGS_FILE.tmp"
            jq --argjson hooks "$(jq '.hooks' "$HOOKS_SOURCE")" '.hooks = $hooks' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" 2>/dev/null
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            echo -e "${GREEN}[OK]${NC} Claude hooks set"
        fi
    else
        echo '{}' | jq --argjson hooks "$(jq '.hooks' "$HOOKS_SOURCE")" '. + {hooks: $hooks}' > "$SETTINGS_FILE"
        echo -e "${GREEN}[OK]${NC} Claude settings.json created"
    fi
else
    echo -e "${YELLOW}[WARN]${NC} .claude-hooks.json missing — skip hooks"
fi

# ── Step 4: Cursor skills + rule + AGENTS.md ─────────────────

if [ -x "$KUARK_HOME/bin/generate-cursor-agents.sh" ]; then
    "$KUARK_HOME/bin/generate-cursor-agents.sh" >/dev/null 2>&1 && \
      echo -e "${GREEN}[OK]${NC} Cursor skills → ~/.cursor/skills/kuark-*/" || \
      echo -e "${YELLOW}[WARN]${NC} generate-cursor-agents.sh failed"
fi

mkdir -p "$CURSOR_HOME/rules"
if [ -f "$KUARK_HOME/templates/cursor/kuark.mdc" ]; then
    cp "$KUARK_HOME/templates/cursor/kuark.mdc" "$CURSOR_HOME/rules/kuark.mdc"
    echo -e "${GREEN}[OK]${NC} Cursor rule → ~/.cursor/rules/kuark.mdc"
fi

# Cursor / Codex share ~/AGENTS.md
AGENTS_SRC="$KUARK_HOME/AGENTS.md"
[ -f "$AGENTS_SRC" ] || AGENTS_SRC="$KUARK_HOME/CLAUDE.md"
inject_marked_file "$HOME/AGENTS.md" "$AGENTS_SRC" "~/AGENTS.md (Cursor/Codex)"

# Optional project-level rule copy hint is in README; global rule is enough

# ── Step 5: Codex note (AGENTS.md already injected) ──────────

echo -e "${GREEN}[OK]${NC} Codex: uses ~/AGENTS.md + kuark CLI (same v2 protocol)"

# ── Version ──────────────────────────────────────────────────

cd "$KUARK_HOME"
if git rev-parse HEAD >/dev/null 2>&1; then
    git rev-parse HEAD > "$KUARK_HOME/version.txt"
else
    date -u +"%Y-%m-%dT%H:%M:%SZ-local" > "$KUARK_HOME/version.txt"
fi

AGENT_COUNT=$(ls -d "$KUARK_HOME"/agents/*/ 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[KUARK]${NC} Installation complete!"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}Install:${NC}       $KUARK_HOME"
echo -e "  ${CYAN}CLI:${NC}           $KUARK_BIN_INSTALLED"
echo -e "  ${CYAN}Agents:${NC}        $AGENT_COUNT (hadron dahil)"
echo -e "  ${CYAN}Claude MD:${NC}     $CLAUDE_HOME/CLAUDE.md"
echo -e "  ${CYAN}AGENTS.md:${NC}     $HOME/AGENTS.md"
echo -e "  ${CYAN}Cursor rule:${NC}   $CURSOR_HOME/rules/kuark.mdc"
echo -e "  ${CYAN}Cursor skills:${NC} $CURSOR_HOME/skills/kuark-*/"
echo ""
echo -e "  ${CYAN}Deploy target:${NC} Hadron (Coolify legacy)"
echo -e "  ${CYAN}Cursor models:${NC} code/ADR → cursor-grok-4.5-high-fast | plan → composer-2.5-fast"
echo ""
echo -e "  ${YELLOW}Usage:${NC}  'proje baslat' | /kuark-proje-baslat | kuark status"
echo -e "  ${YELLOW}Update:${NC} bash ~/.kuark/update.sh  (or bash install.sh from checkout)"
echo ""
