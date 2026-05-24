#!/bin/bash
# Kuark CLI - state.json derivation (rebuild from ledger)
#
# state.json is a CACHE — ledger is source of truth. Always regenerable.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# Replay ledger to build state.json
state_rebuild() {
  [ -f "$LEDGER" ] || { echo '{}' > "$STATE"; return 0; }

  local state
  state=$(jq -s '
    # Start with empty shell
    reduce .[] as $e (
      {
        version: "1.0",
        rebuilt_at: null,
        project: null,
        agent: { current: null, previous: null, history: [] },
        sprint: { current: null, completed: [] },
        stories: {},
        tasks: {},
        handoffs: [],
        decisions: [],
        stats: {}
      };
      # Dispatch by event type
      if   $e.type == "project.init"  then .project = $e.data
      elif $e.type == "story.create"  then .stories[$e.data.id] = $e.data
      elif $e.type == "sprint.start"  then
        (if .sprint.current then .sprint.completed += [.sprint.current] else . end)
        | .sprint.current = ($e.data + {started: $e.ts, status: "active"})
      elif $e.type == "sprint.end"    then
        (if .sprint.current then
          .sprint.completed += [.sprint.current + {ended: $e.ts, status: "ended"}]
          | .sprint.current = null
        else . end)
      elif $e.type == "task.create"   then
        .tasks[$e.data.id] = ($e.data + {
          status: "planned",
          created: $e.ts,
          updated: $e.ts,
          history: [{ts: $e.ts, event: "created", by: $e.by}]
        })
      elif $e.type == "task.update"   then
        (if .tasks[$e.data.id] then
          .tasks[$e.data.id] |= (
            . + ($e.data | with_entries(select(.key != "id")))
              + {updated: $e.ts}
              | .history += [{ts: $e.ts, event: "updated", by: $e.by, changes: ($e.data | with_entries(select(.key != "id")))}]
          )
        else . end)
      elif $e.type == "handoff"       then
        .handoffs += [$e.data + {ts: $e.ts}]
        | .agent.previous = $e.data.from
        | .agent.current = $e.data.to
        | .agent.history += [{from: $e.data.from, to: $e.data.to, ts: $e.ts, task: $e.data.task}]
      elif $e.type == "decision"      then
        .decisions += [$e.data + {ts: $e.ts, by: $e.by}]
      elif $e.type == "agent.set"     then
        .agent.previous = .agent.current
        | .agent.current = $e.data.agent
        | .agent.history += [{set: $e.data.agent, ts: $e.ts, by: $e.by}]
      else . end
    )
    # Compute stats
    | .stats = {
        events:   (input_line_number // 0),
        tasks_total:       (.tasks | length),
        tasks_done:        ([.tasks[] | select(.status == "done")] | length),
        tasks_in_progress: ([.tasks[] | select(.status == "in-progress")] | length),
        tasks_planned:     ([.tasks[] | select(.status == "planned")] | length),
        tasks_review:      ([.tasks[] | select(.status == "review")] | length),
        tasks_blocked:     ([.tasks[] | select(.status == "blocked")] | length),
        stories_total:     (.stories | length),
        decisions_total:   (.decisions | length),
        handoffs_total:    (.handoffs | length),
        by_agent: (
          .tasks
          | to_entries
          | group_by(.value.assignee)
          | map({
              key: (.[0].value.assignee // "unassigned"),
              value: {
                total: length,
                done:  ([.[] | select(.value.status == "done")]        | length),
                inprog:([.[] | select(.value.status == "in-progress")] | length),
                planned:([.[] | select(.value.status == "planned")]    | length)
              }
            })
          | from_entries
        )
      }
    | .rebuilt_at = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
  ' "$LEDGER" 2>/dev/null)

  if [ -z "$state" ]; then
    err "state_rebuild: jq failed"
    return 1
  fi

  echo "$state" > "$STATE.tmp"
  if jq empty "$STATE.tmp" 2>/dev/null; then
    mv "$STATE.tmp" "$STATE"
    return 0
  else
    err "state_rebuild: invalid output JSON"
    rm -f "$STATE.tmp"
    return 1
  fi
}

# Get full state
state_get() {
  [ -f "$STATE" ] || state_rebuild
  cat "$STATE"
}

# Get a path from state (jq syntax)
state_query() {
  [ -f "$STATE" ] || state_rebuild
  jq -r "$1" "$STATE"
}
