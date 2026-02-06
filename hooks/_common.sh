#!/bin/bash
# Kuark Common Hook Helpers
# Sourced by all hook scripts for shared functionality

# Global kuark-system installation path
KUARK_HOME="${KUARK_HOME:-$HOME/.kuark}"

# Colors (for stderr output only)
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse Claude Code hook JSON input from stdin
HOOK_INPUT=""
HOOK_FILE_PATH=""
HOOK_EVENT=""
HOOK_TOOL=""
HOOK_CWD=""
HOOK_SOURCE=""
HOOK_SESSION_ID=""

if [ ! -t 0 ]; then
    HOOK_INPUT=$(cat)
    if echo "$HOOK_INPUT" | jq -e '.' >/dev/null 2>&1; then
        HOOK_FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        HOOK_EVENT=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
        HOOK_TOOL=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
        HOOK_CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null)
        HOOK_SOURCE=$(echo "$HOOK_INPUT" | jq -r '.source // empty' 2>/dev/null)
        HOOK_SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    fi
fi

# Helper: log to stderr (visible to user, not parsed by Claude Code)
kuark_log() {
    echo -e "$@" >&2
}

# Helper: output JSON response to stdout (parsed by Claude Code)
kuark_respond() {
    local json="$1"
    echo "$json"
}

# Helper: check if running in a project with .swarm/
has_swarm() {
    [ -d ".swarm" ]
}

# Helper: get active agent from .swarm/
get_active_agent() {
    if [ -f ".swarm/context/active-agent.json" ]; then
        jq -r '.current // "none"' .swarm/context/active-agent.json 2>/dev/null || echo "none"
    else
        echo "none"
    fi
}
