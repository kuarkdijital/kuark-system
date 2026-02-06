#!/bin/bash
# Kuark Post-edit Formatting
# Auto-formats files after edits and checks for anti-patterns

set -e

FILE_PATH="${CLAUDE_FILE_PATH:-}"

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Get file extension
EXT="${FILE_PATH##*.}"

# Format with Prettier if available
if command -v npx &> /dev/null && [ -f "node_modules/.bin/prettier" ]; then
    case "$EXT" in
        ts|tsx|js|jsx|json|css|scss|md)
            npx prettier --write "$FILE_PATH" 2>/dev/null || true
            ;;
    esac
fi

# Check for anti-patterns in TypeScript/JavaScript
if [[ "$EXT" =~ ^(ts|tsx|js|jsx)$ ]]; then
    # Check for TODO comments
    if grep -n "TODO\|FIXME\|XXX" "$FILE_PATH" 2>/dev/null; then
        echo "[KUARK] Warning: TODO/FIXME comments detected - complete before commit" >&2
    fi

    # Check for any type
    if grep -n ": any\b" "$FILE_PATH" 2>/dev/null; then
        echo "[KUARK] Warning: 'any' type detected - use proper types" >&2
    fi

    # Check for console.log
    if grep -n "console\.log\|console\.debug" "$FILE_PATH" 2>/dev/null; then
        echo "[KUARK] Note: console.log detected - remove before production" >&2
    fi

    # Check for missing organizationId in service files
    if [[ "$FILE_PATH" =~ \.service\.ts$ ]]; then
        if grep -n "prisma\.\w\+\.find" "$FILE_PATH" 2>/dev/null | grep -v "organizationId" > /dev/null; then
            echo "[KUARK] Warning: Prisma query without organizationId filter detected" >&2
        fi
    fi

    # Check for missing guards in controller files
    if [[ "$FILE_PATH" =~ \.controller\.ts$ ]]; then
        if ! grep -q "JwtAuthGuard" "$FILE_PATH" 2>/dev/null; then
            echo "[KUARK] Warning: Controller without JwtAuthGuard detected" >&2
        fi
    fi
fi

# Check Prisma schema
if [[ "$FILE_PATH" =~ schema\.prisma$ ]]; then
    # Check for missing organizationId
    if grep -n "^model " "$FILE_PATH" 2>/dev/null | while read -r line; do
        model_name=$(echo "$line" | awk '{print $2}')
        # Skip certain models that don't need organizationId
        case "$model_name" in
            Organization|User|Session|VerificationToken|Account)
                continue
                ;;
        esac
        # Check if organizationId exists in model
        if ! grep -A 50 "^model $model_name" "$FILE_PATH" | grep -q "organizationId"; then
            echo "[KUARK] Warning: Model $model_name missing organizationId field" >&2
        fi
    done; then
        :
    fi
fi

exit 0
