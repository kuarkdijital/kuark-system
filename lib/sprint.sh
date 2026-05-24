#!/bin/bash
# Kuark CLI - sprints

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/ledger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
source "$(dirname "${BASH_SOURCE[0]}")/views.sh"

cmd_sprint_start() {
  require_swarm
  local name="${1:-Sprint $(($(state_query '.sprint.completed | length') + 1))}"
  local goal="${2:-}"

  local current; current=$(state_query '.sprint.current.id // ""')
  [ -n "$current" ] && [ "$current" != "null" ] && die "Active sprint exists: $current. End it first."

  local id; id=$(next_id "SPR" 2)
  local data
  data=$(jq -nc --arg id "$id" --arg name "$name" --arg goal "$goal" \
    '{id:$id, name:$name, goal:$goal}')
  ledger_append "sprint.start" "${KUARK_AGENT:-project-manager}" "$data" || die "Failed"
  state_rebuild; views_render_all
  ok "Sprint started: $id — $name"
}

cmd_sprint_end() {
  require_swarm
  local current; current=$(state_query '.sprint.current.id // ""')
  [ -z "$current" ] || [ "$current" = "null" ] && die "No active sprint"

  local data; data=$(jq -nc --arg id "$current" '{id:$id}')
  ledger_append "sprint.end" "${KUARK_AGENT:-project-manager}" "$data" || die "Failed"
  state_rebuild; views_render_all
  ok "Sprint ended: $current"
}

cmd_sprint_status() {
  require_swarm
  state_get | jq -r '
    if .sprint.current then
      "Active: \(.sprint.current.id) — \(.sprint.current.name)",
      "Goal:   \(.sprint.current.goal // "-")",
      "Started: \(.sprint.current.started // "-")"
    else "No active sprint." end
  '
}
