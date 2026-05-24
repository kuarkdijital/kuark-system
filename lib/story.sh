#!/bin/bash
# Kuark CLI - user stories

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/ledger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
source "$(dirname "${BASH_SOURCE[0]}")/views.sh"

# kuark story add "title" [priority] [effort]
cmd_story_add() {
  require_swarm
  local title="$1"
  local priority="${2:-should_have}"
  local effort="${3:-M}"
  [ -z "$title" ] && die "story add: title required"

  local id; id=$(next_id "US")
  local data
  data=$(jq -nc \
    --arg id "$id" --arg title "$title" \
    --arg priority "$priority" --arg effort "$effort" \
    '{id:$id, title:$title, priority:$priority, effort:$effort, story:"", acceptance_criteria:[], technical_notes:""}')
  ledger_append "story.create" "${KUARK_AGENT:-product-owner}" "$data" || die "Failed"
  state_rebuild; views_render_all
  ok "Story created: $id — $title"
  echo "$id"
}

cmd_story_list() {
  require_swarm
  state_get | jq -r '
    .stories | to_entries | sort_by(.key) |
    if length == 0 then "No stories yet."
    else
      (["| ID | Title | Priority | Effort |", "|---|---|---|---|"] +
       [.[] | "| \(.value.id) | \(.value.title) | \(.value.priority // "-") | \(.value.effort // "-") |"])
      | .[]
    end
  '
}
