#!/bin/bash
# Kuark Session Memory
# Persists learnings across sessions
# Runs as Claude Code Stop/SessionEnd hook

set -e

# Source common helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

MEMORY_DIR="$HOME/.claude/memory/kuark"
mkdir -p "$MEMORY_DIR"

# Generate project-specific memory file
PROJECT_HASH=$(pwd | md5sum 2>/dev/null | cut -d' ' -f1 || md5 -q -s "$(pwd)" 2>/dev/null || echo "default")
MEMORY_FILE="$MEMORY_DIR/$PROJECT_HASH.json"

# Determine event from hook input or environment
EVENT="${KUARK_EVENT:-${HOOK_EVENT:-}}"

case "$EVENT" in
    "SessionStart")
        # Load previous learnings
        if [ -f "$MEMORY_FILE" ]; then
            echo "[KUARK] Loading session memory..." >&2
            jq -r '.learnings[]? | "  - [\(.category)] \(.message)"' "$MEMORY_FILE" 2>/dev/null >&2 || true
        fi

        # Load global Kuark patterns
        GLOBAL_MEMORY="$MEMORY_DIR/global.json"
        if [ -f "$GLOBAL_MEMORY" ]; then
            echo "[KUARK] Loading global patterns..." >&2
            jq -r '.patterns[]? | "  - \(.name): \(.description)"' "$GLOBAL_MEMORY" 2>/dev/null >&2 || true
        fi
        ;;
    "Stop"|"SessionEnd")
        # Persist any pending learnings
        if [ -f "$MEMORY_FILE.pending" ]; then
            if [ -f "$MEMORY_FILE" ]; then
                # Merge pending into existing
                jq -s '.[0].learnings += .[1].learnings | .[0]' "$MEMORY_FILE" "$MEMORY_FILE.pending" > "$MEMORY_FILE.tmp" 2>/dev/null
                mv "$MEMORY_FILE.tmp" "$MEMORY_FILE"
            else
                mv "$MEMORY_FILE.pending" "$MEMORY_FILE"
            fi
            rm -f "$MEMORY_FILE.pending"
            echo "[KUARK] Session learnings saved" >&2
        fi
        ;;
    *)
        # Add learning (called via stdin with JSON: {"category":"...", "content":"..."})
        INPUT="$HOOK_INPUT"
        if [ -z "$INPUT" ]; then
            exit 0
        fi

        # Check if it's a learning entry (has category and content)
        if echo "$INPUT" | jq -e '.category' >/dev/null 2>&1; then
            ENTRY=$(echo "$INPUT" | jq -c '{ timestamp: (now | todate), category: .category, message: .content }' 2>/dev/null)
            if [ -n "$ENTRY" ]; then
                if [ ! -f "$MEMORY_FILE.pending" ]; then
                    echo '{"learnings":[]}' > "$MEMORY_FILE.pending"
                fi
                jq ".learnings += [$ENTRY]" "$MEMORY_FILE.pending" > "$MEMORY_FILE.pending.tmp" 2>/dev/null
                mv "$MEMORY_FILE.pending.tmp" "$MEMORY_FILE.pending"
                echo "[KUARK] Learning recorded" >&2
            fi
        fi
        ;;
esac

exit 0
