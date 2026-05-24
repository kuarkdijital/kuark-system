#!/bin/bash
# Kuark CLI - active agent tracking (lightweight; real work goes via Agent tool dispatch)

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/ledger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
source "$(dirname "${BASH_SOURCE[0]}")/views.sh"

VALID_AGENTS=(
  product-owner project-manager analyst architect
  nestjs-developer nextjs-developer database-engineer queue-developer python-developer
  qa-engineer security-engineer devops-engineer hadron-engineer
  ui-ux-designer api-researcher documentation orchestrator
)

cmd_agent_set() {
  require_swarm
  local agent="$1"
  [ -z "$agent" ] && die "agent set: name required"
  printf '%s\n' "${VALID_AGENTS[@]}" | grep -qx "$agent" \
    || die "Unknown agent: $agent. Valid: ${VALID_AGENTS[*]}"

  local data; data=$(jq -nc --arg a "$agent" '{agent:$a}')
  ledger_append "agent.set" "system" "$data" || die "Failed"
  state_rebuild; views_render_all
  ok "Active agent: $agent"
}

cmd_agent_current() {
  require_swarm
  state_query '.agent.current // "—"'
}

cmd_agent_list() {
  echo "Valid agents:"
  printf '  %s\n' "${VALID_AGENTS[@]}"
}
