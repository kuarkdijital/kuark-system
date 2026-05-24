#!/bin/bash
# Kuark CLI - tasks

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/ledger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
source "$(dirname "${BASH_SOURCE[0]}")/views.sh"

# kuark task create "title" <assignee> [priority] [story-id]
cmd_task_create() {
  require_swarm
  local title="$1"
  local assignee="$2"
  local priority="${3:-medium}"
  local story="${4:-}"
  [ -z "$title" ]    && die "task create: title required"
  [ -z "$assignee" ] && die "task create: assignee required"

  local sprint; sprint=$(state_query '.sprint.current.id // ""')
  if [ -z "$sprint" ] || [ "$sprint" = "null" ]; then
    warn "No active sprint; auto-starting Sprint 1"
    source "$(dirname "${BASH_SOURCE[0]}")/sprint.sh"
    cmd_sprint_start "Sprint 1" "Auto-started"
    sprint=$(state_query '.sprint.current.id')
  fi

  local id; id=$(next_id "TASK")
  local data
  data=$(jq -nc \
    --arg id "$id" --arg title "$title" --arg assignee "$assignee" \
    --arg priority "$priority" --arg story "$story" --arg sprint "$sprint" \
    '{id:$id, title:$title, assignee:$assignee, priority:$priority, story:$story, sprint:$sprint}')
  ledger_append "task.create" "${KUARK_AGENT:-project-manager}" "$data" || die "Failed"
  state_rebuild; views_render_all
  ok "Task created: $id ($assignee, $priority)"
  echo "$id"
}

# kuark task update <id> <status> [reason]
cmd_task_update() {
  require_swarm
  local id="$1"
  local status="$2"
  local reason="${3:-}"
  [ -z "$id" ]     && die "task update: id required"
  [ -z "$status" ] && die "task update: status required"

  case "$status" in
    planned|in-progress|review|blocked|done) ;;
    *) die "Invalid status: $status (use planned|in-progress|review|blocked|done)" ;;
  esac

  local exists; exists=$(state_query ".tasks[\"$id\"].id // \"\"")
  [ -z "$exists" ] || [ "$exists" = "null" ] && die "Task not found: $id"

  local data
  data=$(jq -nc --arg id "$id" --arg status "$status" --arg reason "$reason" \
    '{id:$id, status:$status} + (if $reason != "" then {reason:$reason} else {} end)')
  ledger_append "task.update" "${KUARK_AGENT:-system}" "$data" || die "Failed"
  state_rebuild; views_render_all
  ok "Task $id → $status"
}

# kuark task list [--status X] [--agent Y]
cmd_task_list() {
  require_swarm
  local status_filter=""
  local agent_filter=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) status_filter="$2"; shift 2 ;;
      --agent)  agent_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  state_get | jq -r --arg s "$status_filter" --arg a "$agent_filter" '
    [.tasks[] |
      select($s == "" or .status == $s) |
      select($a == "" or .assignee == $a)
    ] | sort_by(.id) |
    if length == 0 then "No tasks match filter."
    else
      (["| ID | Title | Assignee | Status | Priority | Story |",
        "|---|---|---|---|---|---|"] +
       [.[] | "| \(.id) | \(.title) | \(.assignee // "-") | \(.status) | \(.priority // "-") | \(.story // "-") |"])
      | .[]
    end
  '
}

# kuark task show <id>
cmd_task_show() {
  require_swarm
  local id="$1"
  [ -z "$id" ] && die "task show: id required"

  local task
  task=$(state_query ".tasks[\"$id\"]")
  [ "$task" = "null" ] && die "Task not found: $id"

  echo "$task" | jq -r '
    "# \(.id) — \(.title)",
    "",
    "- **Assignee:** \(.assignee // "-")",
    "- **Status:**   \(.status)",
    "- **Priority:** \(.priority // "-")",
    "- **Story:**    \(.story // "-")",
    "- **Sprint:**   \(.sprint // "-")",
    "- **Created:**  \(.created)",
    "- **Updated:**  \(.updated)",
    "",
    "## History"
  '
  echo "$task" | jq -r '.history[] | "- \(.ts) | \(.event) | \(.by // "system") | \(.changes // {} | tostring)"'
}
