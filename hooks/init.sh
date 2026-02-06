#!/bin/bash
# Kuark Session Initialization
# Detects project context and loads relevant information

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}[KUARK]${NC} Initializing session..."

# Detect project type
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

# Detect Kuark-specific patterns
detect_kuark_patterns() {
    local patterns=""

    # Check for multi-tenant pattern
    if grep -r "organizationId" --include="*.ts" src/ 2>/dev/null | head -1 > /dev/null; then
        patterns="$patterns multi-tenant"
    fi

    # Check for BullMQ
    if grep -r "@nestjs/bullmq" --include="*.ts" src/ 2>/dev/null | head -1 > /dev/null; then
        patterns="$patterns bullmq"
    fi

    # Check for Prisma
    if [ -f "prisma/schema.prisma" ]; then
        patterns="$patterns prisma"
    fi

    # Check for guards
    if grep -r "JwtAuthGuard" --include="*.ts" src/ 2>/dev/null | head -1 > /dev/null; then
        patterns="$patterns jwt-auth"
    fi

    echo "$patterns"
}

PROJECT_TYPE=$(detect_project)
echo -e "${GREEN}Project Type:${NC} $PROJECT_TYPE"

# Show Kuark patterns
if [ "$PROJECT_TYPE" = "nestjs" ] || [ "$PROJECT_TYPE" = "monorepo" ]; then
    PATTERNS=$(detect_kuark_patterns)
    if [ -n "$PATTERNS" ]; then
        echo -e "${GREEN}Kuark Patterns:${NC}$PATTERNS"
    fi
fi

# Git status
if [ -d ".git" ]; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
    CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    echo -e "${GREEN}Branch:${NC} $BRANCH"

    if [ "$CHANGES" -gt 0 ]; then
        echo -e "${YELLOW}Changes:${NC} $CHANGES uncommitted"
    fi

    # Recent commits
    echo -e "${GREEN}Recent Commits:${NC}"
    git log --oneline -3 2>/dev/null | sed 's/^/  /'
fi

# Swarm state management
if [ -d ".swarm" ]; then
    echo -e "${CYAN}[KUARK]${NC} Swarm state detected"
    if [ -f ".swarm/project.json" ]; then
        PROJECT_NAME=$(cat .swarm/project.json | jq -r '.name // "Unknown"' 2>/dev/null || echo "Unknown")
        PROJECT_STATUS=$(cat .swarm/project.json | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
        echo -e "${GREEN}Project:${NC} $PROJECT_NAME ($PROJECT_STATUS)"
    fi

    # Sprint info
    if [ -f ".swarm/current-sprint.json" ]; then
        SPRINT_NAME=$(cat .swarm/current-sprint.json | jq -r '.name // "None"' 2>/dev/null || echo "None")
        SPRINT_STATUS=$(cat .swarm/current-sprint.json | jq -r '.status // "?"' 2>/dev/null || echo "?")
        if [ "$SPRINT_NAME" != "null" ] && [ "$SPRINT_NAME" != "None" ]; then
            echo -e "${GREEN}Sprint:${NC} $SPRINT_NAME ($SPRINT_STATUS)"
        fi
    fi

    # Task summary
    TASK_COUNT=$(ls .swarm/tasks/*.task.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$TASK_COUNT" -gt 0 ]; then
        DONE_COUNT=$(grep -l 'Durum:\*\* done' .swarm/tasks/*.task.md 2>/dev/null | wc -l | tr -d ' ')
        ACTIVE_COUNT=$(grep -l 'Durum:\*\* in-progress' .swarm/tasks/*.task.md 2>/dev/null | wc -l | tr -d ' ')
        echo -e "${GREEN}Tasks:${NC} $TASK_COUNT total | $ACTIVE_COUNT active | $DONE_COUNT done"
    fi

    # Active agent
    if [ -f ".swarm/context/active-agent.json" ]; then
        ACTIVE_AGENT=$(cat .swarm/context/active-agent.json | jq -r '.current // "none"' 2>/dev/null || echo "none")
        if [ "$ACTIVE_AGENT" != "null" ] && [ "$ACTIVE_AGENT" != "none" ]; then
            echo -e "${GREEN}Active Agent:${NC} $ACTIVE_AGENT"
        fi
    fi
else
    echo -e "${YELLOW}[KUARK]${NC} No swarm state. Initialize with: bash hooks/swarm.sh init [project-name]"
fi

# Load session memory if exists
MEMORY_DIR="$HOME/.claude/memory/kuark"
MEMORY_FILE="$MEMORY_DIR/$(pwd | md5sum 2>/dev/null | cut -d' ' -f1 || echo "default").json"
if [ -f "$MEMORY_FILE" ]; then
    echo -e "${CYAN}[KUARK]${NC} Previous session learnings loaded"
fi

echo ""
