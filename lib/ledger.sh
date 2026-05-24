#!/bin/bash
# Kuark CLI - ledger.jsonl event log (append-only source of truth)
#
# Event schema:
#   {
#     "ts":   "<ISO-8601 UTC>",
#     "uuid": "<8-char unique>",
#     "type": "project.init | story.create | sprint.start | sprint.end |
#              task.create | task.update | handoff | decision | agent.set",
#     "by":   "<agent-name or 'system'>",
#     "data": { ... type-specific payload ... }
#   }

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# Append an event atomically. Validates JSON before writing.
# Usage: ledger_append <type> <by> <data-json>
ledger_append() {
  local type="$1"
  local by="${2:-system}"
  local data="${3-}"
  [ -z "$data" ] && data='{}'

  [ -z "$type" ] && { err "ledger_append: type required"; return 1; }

  local event
  event=$(jq -nc \
    --arg ts "$(now_iso)" \
    --arg uuid "$(event_uuid)" \
    --arg type "$type" \
    --arg by "$by" \
    --argjson data "$data" \
    '{ts:$ts, uuid:$uuid, type:$type, by:$by, data:$data}' 2>/dev/null) \
    || { err "ledger_append: invalid data JSON"; return 1; }

  # Validate single-line
  echo "$event" | jq empty 2>/dev/null || { err "ledger_append: validation failed"; return 1; }

  # Atomic append under lock
  _ledger_append_locked() {
    echo "$event" >> "$LEDGER"
  }
  with_lock _ledger_append_locked || return 1

  return 0
}

# Read all events, optionally filtered by type
# Usage: ledger_read [type-filter]
ledger_read() {
  local filter="$1"
  [ -f "$LEDGER" ] || return 0
  if [ -n "$filter" ]; then
    jq -c --arg t "$filter" 'select(.type == $t)' "$LEDGER"
  else
    cat "$LEDGER"
  fi
}

# Count events
ledger_count() {
  [ -f "$LEDGER" ] && wc -l < "$LEDGER" | tr -d ' ' || echo 0
}

# Last N events (chronological)
ledger_tail() {
  local n="${1:-20}"
  [ -f "$LEDGER" ] && tail -n "$n" "$LEDGER"
}

# Validate every line is well-formed JSON
ledger_validate() {
  [ -f "$LEDGER" ] || return 0
  local line_no=0
  local errors=0
  while IFS= read -r line; do
    line_no=$((line_no + 1))
    if ! echo "$line" | jq empty 2>/dev/null; then
      err "Line $line_no: invalid JSON"
      errors=$((errors + 1))
    fi
  done < "$LEDGER"
  [ $errors -eq 0 ]
}
