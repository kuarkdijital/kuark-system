#!/bin/bash
# Kuark Status Line
# Shows contextual information in the CLI status bar

# Project type indicator
if [ -f "nest-cli.json" ]; then
    echo -n "[NestJS] "
elif [ -f "next.config.js" ] || [ -f "next.config.ts" ] || [ -f "next.config.mjs" ]; then
    echo -n "[Next.js] "
elif [ -f "pnpm-workspace.yaml" ] || [ -f "turbo.json" ]; then
    echo -n "[Monorepo] "
elif [ -f "pyproject.toml" ] && grep -q "fastapi" pyproject.toml 2>/dev/null; then
    echo -n "[FastAPI] "
fi

# Git branch
if [ -d ".git" ]; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [ -n "$BRANCH" ]; then
        # Check for unpushed commits
        UNPUSHED=$(git log @{u}.. --oneline 2>/dev/null | wc -l | tr -d ' ')
        if [ "$UNPUSHED" -gt 0 ]; then
            echo -n "[$BRANCH ↑$UNPUSHED] "
        else
            echo -n "[$BRANCH] "
        fi
    fi
fi

# Swarm status
if [ -d ".swarm" ]; then
    SWARM_INFO=""

    # Sprint name
    if [ -f ".swarm/current-sprint.json" ]; then
        SPRINT=$(cat .swarm/current-sprint.json | jq -r '.name // ""' 2>/dev/null || echo "")
        SPRINT_STATUS=$(cat .swarm/current-sprint.json | jq -r '.status // ""' 2>/dev/null || echo "")
        if [ -n "$SPRINT" ] && [ "$SPRINT" != "null" ]; then
            SWARM_INFO="$SPRINT"
        fi
    fi

    # Active agent
    if [ -f ".swarm/context/active-agent.json" ]; then
        AGENT=$(cat .swarm/context/active-agent.json | jq -r '.current // ""' 2>/dev/null || echo "")
        if [ -n "$AGENT" ] && [ "$AGENT" != "null" ]; then
            SWARM_INFO="$SWARM_INFO|$AGENT"
        fi
    fi

    # Task progress
    TOTAL=$(ls .swarm/tasks/*.task.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$TOTAL" -gt 0 ]; then
        DONE=$(grep -l 'Durum:\*\* done' .swarm/tasks/*.task.md 2>/dev/null | wc -l | tr -d ' ')
        SWARM_INFO="$SWARM_INFO|$DONE/$TOTAL"
    fi

    if [ -n "$SWARM_INFO" ]; then
        echo -n "[🐝 $SWARM_INFO] "
    else
        echo -n "[🐝 Swarm] "
    fi
fi

# Context window usage (if available)
if [ -n "$CLAUDE_CONTEXT_USED" ] && [ -n "$CLAUDE_CONTEXT_MAX" ]; then
    PCT=$((CLAUDE_CONTEXT_USED * 100 / CLAUDE_CONTEXT_MAX))
    echo -n "ctx:${PCT}% "
fi
