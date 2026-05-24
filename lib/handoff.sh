#!/bin/bash
# Kuark CLI - structured agent-to-agent handoffs
#
# A handoff carries the FULL context a fresh sub-agent needs to start work
# without seeing prior conversation. The payload markdown is the "memo" left
# on the desk for the next agent.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/ledger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
source "$(dirname "${BASH_SOURCE[0]}")/views.sh"

# kuark handoff <from> <to> [--task TASK-XXX] [--summary "..."] [--payload PATH]
#
# If --payload is omitted, an interactive template is written to handoffs/HOFF-XXX.md
# and its path is printed (so the caller can fill it in).
cmd_handoff() {
  require_swarm
  local from="$1"; local to="$2"; shift 2 2>/dev/null || true
  local task=""
  local summary=""
  local payload=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --task)    task="$2"; shift 2 ;;
      --summary) summary="$2"; shift 2 ;;
      --payload) payload="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$from" ] && die "handoff: from required"
  [ -z "$to" ]   && die "handoff: to required"

  local id; id=$(next_id "HOFF")
  mkdir -p "$HANDOFFS_DIR"

  if [ -z "$payload" ]; then
    payload="$HANDOFFS_DIR/$id.md"
    _write_handoff_template "$payload" "$id" "$from" "$to" "$task" "$summary"
  fi

  local data
  data=$(jq -nc \
    --arg id "$id" --arg from "$from" --arg to "$to" \
    --arg task "$task" --arg summary "$summary" --arg payload "$payload" \
    '{id:$id, from:$from, to:$to, task:$task, summary:$summary, payload:$payload}')
  ledger_append "handoff" "$from" "$data" || die "Failed"
  state_rebuild; views_render_all

  # Auto-transition outgoing task to review (if specified)
  if [ -n "$task" ]; then
    local cur_status; cur_status=$(state_query ".tasks[\"$task\"].status // \"\"")
    if [ "$cur_status" = "in-progress" ]; then
      source "$(dirname "${BASH_SOURCE[0]}")/task.sh"
      cmd_task_update "$task" "review" "handed off to $to via $id" >/dev/null
    fi
  fi

  ok "Handoff $id: $from → $to${task:+ [$task]}"
  echo "Payload: $payload"
}

_write_handoff_template() {
  local file="$1" id="$2" from="$3" to="$4" task="$5" summary="$6"
  cat > "$file" <<EOF
---
id: $id
from: $from
to: $to
task: $task
ts: $(now_iso)
summary: $summary
---

# Handoff $id: $from → $to

${task:+## Task
\`$task\`

}## What Was Done

- [bullet list of completed work]

## Decisions Made

- [DEC-XXX or inline rationale]

## Open Questions

- [questions for the next agent or for the user]

## Context For Next Agent

**Files to read:**
- \`path/to/file.ts:lineno\`

**Patterns to follow:**
- [link to existing pattern in codebase]

**Constraints:**
- [organizationId filter, JwtAuthGuard, DTO validation, etc.]

## Acceptance Criteria For Next Step

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] All Kuark zero-tolerance rules pass (tsc, prisma validate, guards, DTOs)
EOF
}

cmd_handoff_list() {
  require_swarm
  state_get | jq -r '
    .handoffs | sort_by(.ts) | reverse |
    if length == 0 then "No handoffs yet."
    else
      (["| ID | Time | From | To | Task | Payload |",
        "|---|---|---|---|---|---|"] +
       [.[] | "| \(.id) | \(.ts[0:16] | sub("T";" ")) | \(.from) | \(.to) | \(.task // "-") | \(.payload // "-") |"])
      | .[]
    end
  '
}
