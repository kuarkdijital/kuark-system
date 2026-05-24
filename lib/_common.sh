#!/bin/bash
# Kuark CLI - common helpers (sourced by all lib/*.sh)

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Paths
SWARM_DIR="${KUARK_SWARM_DIR:-.swarm}"
LEDGER="$SWARM_DIR/ledger.jsonl"
STATE="$SWARM_DIR/state.json"
VIEWS_DIR="$SWARM_DIR/views"
HANDOFFS_DIR="$SWARM_DIR/handoffs"
DECISIONS_DIR="$SWARM_DIR/decisions"
LOCK_FILE="$SWARM_DIR/.lock"

# ── Output helpers ──────────────────────────────────────────
say()  { printf "${CYAN}[kuark]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}⚠${NC} %s\n" "$*" >&2; }
err()  { printf "${RED}✗${NC} %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ── Guards ──────────────────────────────────────────────────
require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq required. Install: brew install jq"
}

require_swarm() {
  [ -d "$SWARM_DIR" ] || die "Not initialized. Run: kuark init [project-name]"
  [ -f "$LEDGER" ] || die "Ledger missing. Run: kuark repair"
}

# ── Time & IDs ──────────────────────────────────────────────
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Atomic, padded sequential IDs scanned from ledger to avoid drift
next_id() {
  local prefix="$1"
  local pad="${2:-3}"
  local max=0
  if [ -f "$LEDGER" ]; then
    max=$(jq -r --arg p "$prefix" '
      select(.data.id // "" | startswith($p + "-"))
      | .data.id | sub("^"+$p+"-"; "") | tonumber? // 0
    ' "$LEDGER" 2>/dev/null | sort -n | tail -1)
    [ -z "$max" ] && max=0
  fi
  printf "%s-%0${pad}d" "$prefix" $((max + 1))
}

# Event UUID (short)
event_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr 'A-Z' 'a-z' | cut -c1-8
  else
    printf '%08x' "$RANDOM$RANDOM"
  fi
}

# ── Locking (macOS-friendly) ────────────────────────────────
with_lock() {
  local fd=9
  local timeout=10
  exec 9>"$LOCK_FILE" || die "Cannot acquire lock fd"
  if command -v flock >/dev/null 2>&1; then
    flock -w "$timeout" 9 || die "Lock timeout after ${timeout}s"
  else
    # macOS fallback: spin-wait on directory rename (atomic)
    local waited=0
    while ! mkdir "${LOCK_FILE}.d" 2>/dev/null; do
      sleep 0.1
      waited=$((waited + 1))
      [ $waited -gt $((timeout * 10)) ] && die "Lock timeout after ${timeout}s"
    done
    trap 'rm -rf "${LOCK_FILE}.d"' RETURN
  fi
  "$@"
  local rc=$?
  exec 9>&-
  [ ! -e "${LOCK_FILE}.d" ] || rm -rf "${LOCK_FILE}.d" 2>/dev/null
  return $rc
}

# ── JSON helpers ────────────────────────────────────────────
jq_val() { jq -r "$1" "$2" 2>/dev/null; }

valid_json_file() { jq empty "$1" 2>/dev/null; }
