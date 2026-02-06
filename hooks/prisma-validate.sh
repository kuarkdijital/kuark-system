#!/bin/bash
# Kuark Prisma Schema Validation
# Checks Prisma schema for Kuark-specific patterns

set -e

# Source common helpers (parses stdin JSON from Claude Code)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

FILE_PATH="${HOOK_FILE_PATH:-${CLAUDE_FILE_PATH:-}}"

# Only run for Prisma schema files
if [[ ! "$FILE_PATH" =~ schema\.prisma$ ]]; then
    exit 0
fi

echo "[KUARK] Validating Prisma schema patterns..."

# Read the schema file
SCHEMA_CONTENT=$(cat "$FILE_PATH" 2>/dev/null || exit 0)

# Extract model names (excluding built-in models)
MODELS=$(echo "$SCHEMA_CONTENT" | grep -E "^model " | awk '{print $2}')

# Models that don't need organizationId
EXEMPT_MODELS="Organization User Account Session VerificationToken RefreshToken"

for model in $MODELS; do
    # Skip exempt models
    if echo "$EXEMPT_MODELS" | grep -q "\b$model\b"; then
        continue
    fi

    # Get model content
    MODEL_CONTENT=$(echo "$SCHEMA_CONTENT" | sed -n "/^model $model {/,/^}/p")

    # Check for organizationId
    if ! echo "$MODEL_CONTENT" | grep -q "organizationId"; then
        echo "[KUARK] Warning: Model '$model' is missing organizationId field" >&2
        echo "  Add: organizationId String" >&2
        echo "  Add: organization Organization @relation(fields: [organizationId], references: [id])" >&2
    fi

    # Check for soft delete (deletedAt)
    if ! echo "$MODEL_CONTENT" | grep -q "deletedAt"; then
        echo "[KUARK] Note: Model '$model' could benefit from soft delete (deletedAt DateTime?)" >&2
    fi

    # Check for timestamps
    if ! echo "$MODEL_CONTENT" | grep -q "createdAt"; then
        echo "[KUARK] Warning: Model '$model' is missing createdAt timestamp" >&2
    fi

    if ! echo "$MODEL_CONTENT" | grep -q "updatedAt"; then
        echo "[KUARK] Warning: Model '$model' is missing updatedAt timestamp" >&2
    fi

    # Check for organizationId index
    if echo "$MODEL_CONTENT" | grep -q "organizationId"; then
        if ! echo "$MODEL_CONTENT" | grep -q "@@index.*organizationId"; then
            echo "[KUARK] Note: Model '$model' should have @@index([organizationId])" >&2
        fi
    fi
done

# Run Prisma validate if available
if command -v npx &> /dev/null && [ -f "node_modules/.bin/prisma" ]; then
    echo "[KUARK] Running prisma validate..."
    npx prisma validate 2>&1 || {
        echo "[KUARK] Prisma validation failed" >&2
        exit 1
    }
fi

exit 0
