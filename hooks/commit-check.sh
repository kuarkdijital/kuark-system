#!/bin/bash
# Kuark Pre-commit Validation
# Runs checks before git commits

set -e

echo "[KUARK] Running pre-commit checks..."

# TypeScript check
if [ -f "tsconfig.json" ]; then
    echo "[KUARK] Checking TypeScript..."
    if command -v npx &> /dev/null; then
        npx tsc --noEmit 2>&1 || {
            echo "[KUARK] TypeScript errors found. Fix before committing." >&2
            exit 1
        }
    fi
fi

# Prisma validation
if [ -f "prisma/schema.prisma" ]; then
    echo "[KUARK] Validating Prisma schema..."
    if command -v npx &> /dev/null; then
        npx prisma validate 2>&1 || {
            echo "[KUARK] Prisma schema validation failed." >&2
            exit 1
        }
    fi
fi

# Check for secrets in staged files
echo "[KUARK] Scanning for secrets..."
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || echo "")

for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        # Check for common secret patterns
        if grep -E "(api[_-]?key|secret|password|token|private[_-]?key)\s*[:=]\s*['\"][^'\"]+['\"]" "$file" 2>/dev/null | grep -v "process\.env\|import\.meta\.env\|@ApiProperty\|example:" > /dev/null; then
            echo "[KUARK] Warning: Potential secret in $file" >&2
        fi
    fi
done

# Check for large files
for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        SIZE=$(wc -c < "$file" 2>/dev/null || echo "0")
        if [ "$SIZE" -gt 1000000 ]; then
            echo "[KUARK] Warning: Large file detected: $file ($(numfmt --to=iec $SIZE 2>/dev/null || echo "${SIZE}B"))" >&2
        fi
    fi
done

# Check for NestJS patterns in staged TS files
for file in $STAGED_FILES; do
    if [[ "$file" =~ \.controller\.ts$ ]]; then
        if ! grep -q "UseGuards\|JwtAuthGuard" "$file" 2>/dev/null; then
            echo "[KUARK] Warning: Controller without guards: $file" >&2
        fi
    fi

    if [[ "$file" =~ \.service\.ts$ ]]; then
        if grep -q "prisma\.\w\+\.find\|prisma\.\w\+\.create\|prisma\.\w\+\.update\|prisma\.\w\+\.delete" "$file" 2>/dev/null; then
            if ! grep -q "organizationId" "$file" 2>/dev/null; then
                echo "[KUARK] Warning: Service with Prisma operations but no organizationId: $file" >&2
            fi
        fi
    fi
done

# ESLint check if available
if [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] || [ -f "eslint.config.js" ]; then
    if command -v npx &> /dev/null && [ -f "node_modules/.bin/eslint" ]; then
        echo "[KUARK] Running ESLint..."
        npx eslint --max-warnings 0 $STAGED_FILES 2>&1 || {
            echo "[KUARK] ESLint errors found. Fix before committing." >&2
            exit 1
        }
    fi
fi

echo "[KUARK] Pre-commit checks passed"
exit 0
