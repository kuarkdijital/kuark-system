#!/bin/bash
# Kuark NestJS Pattern Check
# Validates NestJS files follow Kuark conventions

set -e

# Source common helpers (parses stdin JSON from Claude Code)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

FILE_PATH="${HOOK_FILE_PATH:-${CLAUDE_FILE_PATH:-}}"

# Only run for TypeScript files in modules directory
if [[ ! "$FILE_PATH" =~ modules/.*\.ts$ ]]; then
    exit 0
fi

# Skip spec files
if [[ "$FILE_PATH" =~ \.spec\.ts$ ]]; then
    exit 0
fi

CONTENT=$(cat "$FILE_PATH" 2>/dev/null || exit 0)

# Controller checks
if [[ "$FILE_PATH" =~ \.controller\.ts$ ]]; then
    echo "[KUARK] Checking controller patterns..."

    # Check for JwtAuthGuard
    if ! echo "$CONTENT" | grep -q "JwtAuthGuard"; then
        echo "[KUARK] Error: Controller missing JwtAuthGuard" >&2
        echo "  Add: @UseGuards(JwtAuthGuard, FullAccessGuard)" >&2
    fi

    # Check for FullAccessGuard
    if ! echo "$CONTENT" | grep -q "FullAccessGuard"; then
        echo "[KUARK] Warning: Controller missing FullAccessGuard" >&2
        echo "  Consider: @UseGuards(JwtAuthGuard, FullAccessGuard)" >&2
    fi

    # Check for @CurrentUser decorator usage
    if echo "$CONTENT" | grep -q "@Post\|@Put\|@Delete\|@Patch\|@Get"; then
        if ! echo "$CONTENT" | grep -q "@CurrentUser"; then
            echo "[KUARK] Warning: Controller methods should use @CurrentUser() for organizationId" >&2
        fi
    fi

    # Check for Swagger decorators
    if ! echo "$CONTENT" | grep -q "@ApiTags"; then
        echo "[KUARK] Note: Controller missing @ApiTags decorator" >&2
    fi

    if ! echo "$CONTENT" | grep -q "@ApiBearerAuth"; then
        echo "[KUARK] Note: Controller missing @ApiBearerAuth decorator" >&2
    fi
fi

# Service checks
if [[ "$FILE_PATH" =~ \.service\.ts$ ]]; then
    echo "[KUARK] Checking service patterns..."

    # Check for organizationId in Prisma queries
    if echo "$CONTENT" | grep -q "this\.prisma\.\|prisma\."; then
        # findMany without organizationId
        if echo "$CONTENT" | grep "findMany" | grep -v "organizationId" > /dev/null 2>&1; then
            echo "[KUARK] Warning: findMany without organizationId filter detected" >&2
        fi

        # findUnique/findFirst without organization check
        if echo "$CONTENT" | grep "findUnique\|findFirst" | grep -v "organizationId" > /dev/null 2>&1; then
            echo "[KUARK] Warning: findUnique/findFirst without organizationId filter detected" >&2
        fi

        # create without organizationId
        if echo "$CONTENT" | grep "\.create\s*(" | grep -v "organizationId" > /dev/null 2>&1; then
            echo "[KUARK] Warning: create without organizationId detected" >&2
        fi

        # update without organizationId in where clause
        if echo "$CONTENT" | grep "\.update\s*(" | grep -v "organizationId" > /dev/null 2>&1; then
            echo "[KUARK] Note: Ensure update operations verify organizationId ownership" >&2
        fi
    fi

    # Check for proper return format with pagination
    if echo "$CONTENT" | grep -q "findMany"; then
        if ! echo "$CONTENT" | grep -q "pagination\|skip.*take\|page.*limit"; then
            echo "[KUARK] Note: List operations should implement pagination" >&2
        fi
    fi
fi

# DTO checks
if [[ "$FILE_PATH" =~ \.dto\.ts$ ]]; then
    echo "[KUARK] Checking DTO patterns..."

    # Check for class-validator decorators
    if echo "$CONTENT" | grep -q "class.*Dto"; then
        if ! echo "$CONTENT" | grep -q "@Is\|@Min\|@Max\|@Length"; then
            echo "[KUARK] Warning: DTO missing validation decorators" >&2
            echo "  Add: class-validator decorators (@IsString, @IsEmail, etc.)" >&2
        fi
    fi

    # Check for Swagger decorators
    if ! echo "$CONTENT" | grep -q "@ApiProperty"; then
        echo "[KUARK] Note: DTO missing @ApiProperty decorators for Swagger" >&2
    fi
fi

# Processor checks
if [[ "$FILE_PATH" =~ \.processor\.ts$ ]]; then
    echo "[KUARK] Checking processor patterns..."

    # Check for WorkerHost extension
    if ! echo "$CONTENT" | grep -q "extends WorkerHost"; then
        echo "[KUARK] Note: Processor should extend WorkerHost" >&2
    fi

    # Check for Logger
    if ! echo "$CONTENT" | grep -q "Logger"; then
        echo "[KUARK] Warning: Processor missing Logger" >&2
    fi

    # Check for error handling
    if echo "$CONTENT" | grep -q "async process"; then
        if ! echo "$CONTENT" | grep -q "try\s*{"; then
            echo "[KUARK] Warning: Processor process method should have try/catch" >&2
        fi
    fi

    # Check for event handlers
    if ! echo "$CONTENT" | grep -q "@OnWorkerEvent"; then
        echo "[KUARK] Note: Consider adding @OnWorkerEvent handlers for logging" >&2
    fi
fi

exit 0
