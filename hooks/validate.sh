#!/bin/bash
# Kuark Pre-edit Validation
# Runs as Claude Code PreToolUse hook for Edit|Write
# Checks for potentially dangerous patterns before file edits

set -e

# Source common helpers (parses stdin JSON from Claude Code)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

FILE_PATH="${HOOK_FILE_PATH:-${CLAUDE_FILE_PATH:-}}"

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Check for sensitive files
case "$FILE_PATH" in
    *.env|*.env.*|.env*)
        echo "[KUARK] Warning: Editing environment file - ensure no secrets are exposed" >&2
        ;;
    *credentials*|*secrets*|*private*|*keys*)
        echo "[KUARK] Warning: Editing potentially sensitive file" >&2
        ;;
    */prisma/schema.prisma)
        echo "[KUARK] Note: Prisma schema change - remember to run migration" >&2
        ;;
    */migrations/*)
        echo "[KUARK] Warning: Editing migration file directly - this may cause issues" >&2
        ;;
    *docker-compose*.yml|*docker-compose*.yaml)
        echo "[KUARK] Note: Docker compose change - review port mappings and volumes" >&2
        ;;
esac

exit 0
