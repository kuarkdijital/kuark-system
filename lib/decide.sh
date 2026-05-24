#!/bin/bash
# Kuark CLI - architectural decision records

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/ledger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
source "$(dirname "${BASH_SOURCE[0]}")/views.sh"

# kuark decide "topic" "outcome" [rationale]
cmd_decide() {
  require_swarm
  local topic="$1"
  local outcome="$2"
  local rationale="${3:-}"
  [ -z "$topic" ]   && die "decide: topic required"
  [ -z "$outcome" ] && die "decide: outcome required"

  local id; id=$(next_id "DEC")
  mkdir -p "$DECISIONS_DIR"

  local file="$DECISIONS_DIR/$id.md"
  cat > "$file" <<EOF
---
id: $id
topic: $topic
ts: $(now_iso)
by: ${KUARK_AGENT:-architect}
---

# $id: $topic

## Outcome
$outcome

## Rationale
${rationale:-_[Fill in rationale]_}

## Alternatives Considered
- [Option A: pros/cons]
- [Option B: pros/cons]

## Consequences
- [What this enables / locks in]
EOF

  local data
  data=$(jq -nc \
    --arg id "$id" --arg topic "$topic" --arg outcome "$outcome" \
    --arg rationale "$rationale" --arg file "$file" \
    '{id:$id, topic:$topic, outcome:$outcome, rationale:$rationale, file:$file}')
  ledger_append "decision" "${KUARK_AGENT:-architect}" "$data" || die "Failed"
  state_rebuild; views_render_all
  ok "Decision recorded: $id — $topic"
  echo "File: $file"
}

cmd_decide_list() {
  require_swarm
  state_get | jq -r '
    .decisions | sort_by(.ts) | reverse |
    if length == 0 then "No decisions yet."
    else
      (["| ID | Topic | Outcome | By | When |",
        "|---|---|---|---|---|"] +
       [.[] | "| \(.id) | \(.topic) | \(.outcome // "-") | \(.by // "-") | \(.ts[0:16] | sub("T";" ")) |"])
      | .[]
    end
  '
}
