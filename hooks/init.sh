#!/bin/bash
# Kuark Session Initialization
# Runs as Claude Code SessionStart hook
# Detects project context, initializes .swarm/, and injects agent context

set -e

# Source common helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# Persist KUARK_HOME for the session
if [ -n "$CLAUDE_ENV_FILE" ]; then
    echo "export KUARK_HOME=\"$KUARK_HOME\"" >> "$CLAUDE_ENV_FILE"
fi

# ─────────────────────────────────────────────────────────────
# Project Detection
# ─────────────────────────────────────────────────────────────

detect_project() {
    if [ -f "nest-cli.json" ]; then
        echo "nestjs"
    elif [ -f "next.config.js" ] || [ -f "next.config.ts" ] || [ -f "next.config.mjs" ]; then
        echo "nextjs"
    elif [ -f "pnpm-workspace.yaml" ] || [ -f "turbo.json" ]; then
        echo "monorepo"
    elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
        if grep -q "fastapi" requirements.txt 2>/dev/null || grep -q "fastapi" pyproject.toml 2>/dev/null; then
            echo "fastapi"
        else
            echo "python"
        fi
    elif [ -f "package.json" ]; then
        if grep -q '"@nestjs/core"' package.json 2>/dev/null; then
            echo "nestjs"
        elif grep -q '"next"' package.json 2>/dev/null; then
            echo "nextjs"
        else
            echo "node"
        fi
    else
        echo "unknown"
    fi
}

detect_kuark_patterns() {
    local patterns=""

    if grep -r "organizationId" --include="*.ts" src/ 2>/dev/null | head -1 > /dev/null 2>&1; then
        patterns="$patterns multi-tenant"
    fi

    if grep -r "@nestjs/bullmq" --include="*.ts" src/ 2>/dev/null | head -1 > /dev/null 2>&1; then
        patterns="$patterns bullmq"
    fi

    if [ -f "prisma/schema.prisma" ]; then
        patterns="$patterns prisma"
    fi

    if grep -r "JwtAuthGuard" --include="*.ts" src/ 2>/dev/null | head -1 > /dev/null 2>&1; then
        patterns="$patterns jwt-auth"
    fi

    echo "$patterns"
}

PROJECT_TYPE=$(detect_project)
kuark_log "${CYAN}[KUARK]${NC} Initializing session..."
kuark_log "${GREEN}Project Type:${NC} $PROJECT_TYPE"

# Detect Kuark patterns
if [ "$PROJECT_TYPE" = "nestjs" ] || [ "$PROJECT_TYPE" = "monorepo" ]; then
    PATTERNS=$(detect_kuark_patterns)
    if [ -n "$PATTERNS" ]; then
        kuark_log "${GREEN}Kuark Patterns:${NC}$PATTERNS"
    fi
fi

# Git status
if [ -d ".git" ]; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
    CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    kuark_log "${GREEN}Branch:${NC} $BRANCH"

    if [ "$CHANGES" -gt 0 ]; then
        kuark_log "${YELLOW}Changes:${NC} $CHANGES uncommitted"
    fi

    kuark_log "${GREEN}Recent Commits:${NC}"
    git log --oneline -3 2>/dev/null | sed 's/^/  /' >&2
fi

# ─────────────────────────────────────────────────────────────
# Swarm State Management
# ─────────────────────────────────────────────────────────────

ACTIVE_AGENT=""

if [ ! -d ".swarm" ]; then
    kuark_log "${CYAN}[KUARK]${NC} No swarm found - auto-initializing..."
    PROJ_NAME=$(basename "$(pwd)")
    bash "$KUARK_HOME/hooks/swarm.sh" init "$PROJ_NAME" "$PROJECT_TYPE" 2>/dev/null || true

    # Set product-owner as initial active agent
    if [ -f ".swarm/context/active-agent.json" ]; then
        TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        cat > ".swarm/context/active-agent.json" << AGENTEOF
{
  "current": "product-owner",
  "previous": null,
  "handoffChain": [{"from": "system", "to": "product-owner", "at": "$TIMESTAMP"}],
  "lastUpdated": "$TIMESTAMP"
}
AGENTEOF
    fi
    ACTIVE_AGENT="product-owner"
    kuark_log "${GREEN}[KUARK]${NC} Swarm initialized. Active agent: product-owner"
fi

if [ -d ".swarm" ]; then
    # Show project info
    if [ -f ".swarm/project.json" ]; then
        SWARM_PROJECT_NAME=$(jq -r '.name // "Unknown"' .swarm/project.json 2>/dev/null || echo "Unknown")
        SWARM_PROJECT_STATUS=$(jq -r '.status // "unknown"' .swarm/project.json 2>/dev/null || echo "unknown")
        kuark_log "${GREEN}Project:${NC} $SWARM_PROJECT_NAME ($SWARM_PROJECT_STATUS)"
    fi

    # Sprint info
    if [ -f ".swarm/current-sprint.json" ]; then
        SPRINT_NAME=$(jq -r '.name // "None"' .swarm/current-sprint.json 2>/dev/null || echo "None")
        SPRINT_STATUS=$(jq -r '.status // "?"' .swarm/current-sprint.json 2>/dev/null || echo "?")
        if [ "$SPRINT_NAME" != "null" ] && [ "$SPRINT_NAME" != "None" ]; then
            kuark_log "${GREEN}Sprint:${NC} $SPRINT_NAME ($SPRINT_STATUS)"
        fi
    fi

    # Task summary
    TASK_COUNT=$(ls .swarm/tasks/*.task.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$TASK_COUNT" -gt 0 ]; then
        DONE_COUNT=$(grep -l 'Durum:\*\* done' .swarm/tasks/*.task.md 2>/dev/null | wc -l | tr -d ' ')
        ACTIVE_COUNT=$(grep -l 'Durum:\*\* in-progress' .swarm/tasks/*.task.md 2>/dev/null | wc -l | tr -d ' ')
        kuark_log "${GREEN}Tasks:${NC} $TASK_COUNT total | $ACTIVE_COUNT active | $DONE_COUNT done"
    fi

    # Determine active agent
    if [ -z "$ACTIVE_AGENT" ] && [ -f ".swarm/context/active-agent.json" ]; then
        ACTIVE_AGENT=$(jq -r '.current // "none"' .swarm/context/active-agent.json 2>/dev/null || echo "none")
        if [ "$ACTIVE_AGENT" = "null" ] || [ "$ACTIVE_AGENT" = "none" ]; then
            TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            jq --arg ts "$TIMESTAMP" '.current = "product-owner" | .lastUpdated = $ts' \
                .swarm/context/active-agent.json > .swarm/context/active-agent.json.tmp 2>/dev/null
            mv .swarm/context/active-agent.json.tmp .swarm/context/active-agent.json
            ACTIVE_AGENT="product-owner"
        fi
    fi

    kuark_log "${GREEN}Active Agent:${NC} $ACTIVE_AGENT"
fi

# ─────────────────────────────────────────────────────────────
# Build Agent Context for Claude Code
# ─────────────────────────────────────────────────────────────

AGENT_CONTEXT=""

if [ -n "$ACTIVE_AGENT" ] && [ -f "$KUARK_HOME/agents/$ACTIVE_AGENT/SKILL.md" ]; then
    AGENT_SKILL=$(cat "$KUARK_HOME/agents/$ACTIVE_AGENT/SKILL.md")
    AGENT_CONTEXT="=== KUARK ACTIVE AGENT: $ACTIVE_AGENT ===
Asagidaki talimatlari bu session boyunca ZORUNLU olarak uygula.
Kullaniciya ilk yanitinda bu agent rolunde selamlama yap.

$AGENT_SKILL

=== END AGENT INSTRUCTIONS ==="
else
    AGENT_CONTEXT="=== KUARK: No active agent. Normal Claude mode. ==="
fi

# Build swarm state context
SWARM_CONTEXT=""
if [ -d ".swarm" ]; then
    SWARM_CONTEXT="
=== KUARK SWARM STATE ===
Project Type: $PROJECT_TYPE
Active Agent: $ACTIVE_AGENT"

    if [ -f ".swarm/project.json" ]; then
        SWARM_CONTEXT="$SWARM_CONTEXT
Project: $(jq -r '.name // "Unknown"' .swarm/project.json 2>/dev/null)"
    fi

    if [ -f ".swarm/current-sprint.json" ]; then
        SPRINT_NAME=$(jq -r '.name // "None"' .swarm/current-sprint.json 2>/dev/null)
        if [ "$SPRINT_NAME" != "null" ] && [ "$SPRINT_NAME" != "None" ]; then
            SWARM_CONTEXT="$SWARM_CONTEXT
Sprint: $SPRINT_NAME ($(jq -r '.status' .swarm/current-sprint.json 2>/dev/null))"
        fi
    fi

    if [ "$TASK_COUNT" -gt 0 ] 2>/dev/null; then
        SWARM_CONTEXT="$SWARM_CONTEXT
Tasks: $TASK_COUNT total | $ACTIVE_COUNT active | $DONE_COUNT done"
    fi

    SWARM_CONTEXT="$SWARM_CONTEXT
=== END SWARM STATE ==="
fi

# Load session memory
MEMORY_DIR="$HOME/.claude/memory/kuark"
PROJECT_HASH=$(pwd | md5sum 2>/dev/null | cut -d' ' -f1 || md5 -q -s "$(pwd)" 2>/dev/null || echo "default")
MEMORY_FILE="$MEMORY_DIR/$PROJECT_HASH.json"
MEMORY_CONTEXT=""
if [ -f "$MEMORY_FILE" ]; then
    LEARNINGS=$(jq -r '.learnings[]? | "- [\(.category)] \(.message)"' "$MEMORY_FILE" 2>/dev/null)
    if [ -n "$LEARNINGS" ]; then
        MEMORY_CONTEXT="
=== KUARK SESSION MEMORY ===
$LEARNINGS
=== END SESSION MEMORY ==="
        kuark_log "${CYAN}[KUARK]${NC} Previous session learnings loaded"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Output JSON response for Claude Code SessionStart hook
# ─────────────────────────────────────────────────────────────

FULL_CONTEXT="$AGENT_CONTEXT

$SWARM_CONTEXT

$MEMORY_CONTEXT"

# Escape for JSON
ESCAPED_CONTEXT=$(echo "$FULL_CONTEXT" | jq -Rs '.')

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ESCAPED_CONTEXT
  }
}
EOF
