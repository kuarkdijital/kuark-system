#!/bin/bash
# Kuark CLI - project initialization

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/ledger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
source "$(dirname "${BASH_SOURCE[0]}")/views.sh"

cmd_init() {
  local project_name="${1:-$(basename "$PWD")}"

  if [ -d "$SWARM_DIR" ] && [ -f "$LEDGER" ]; then
    warn "Already initialized at $SWARM_DIR"
    return 0
  fi

  mkdir -p "$SWARM_DIR" "$VIEWS_DIR" "$HANDOFFS_DIR" "$DECISIONS_DIR"
  touch "$LEDGER"

  local data
  data=$(jq -nc \
    --arg name "$project_name" \
    --arg desc "" \
    --arg status "active" \
    '{name:$name, description:$desc, status:$status, created: now | strftime("%Y-%m-%dT%H:%M:%SZ")}')

  ledger_append "project.init" "system" "$data" || die "Failed to write init event"
  state_rebuild
  views_render_all

  cat > "$SWARM_DIR/README.md" <<EOF
# .swarm — Kuark Swarm State

This directory is managed by the \`kuark\` CLI. It contains the project's
multi-agent development state.

## Files

| Path | Purpose |
|---|---|
| \`ledger.jsonl\` | **Source of truth.** Append-only event log. |
| \`state.json\` | Cache. Current snapshot derived from ledger. Regenerable. |
| \`views/\` | Auto-rendered human-readable dashboards (markdown). |
| \`handoffs/\` | Structured agent-to-agent handoff payloads. |
| \`decisions/\` | Architectural decision records (ADRs). |

## Do not hand-edit

\`state.json\` and \`views/*.md\` are regenerated from \`ledger.jsonl\` on every event.
Use the \`kuark\` CLI instead — it ensures atomic writes and view refreshes.

## Quick view

\`\`\`bash
kuark status              # quick overview
kuark tasks               # task table
cat .swarm/views/dashboard.md
\`\`\`
EOF

  ok "Initialized: $project_name"
  say "Ledger: $LEDGER"
  say "Views:  $VIEWS_DIR/"
}

# Repair: ensure files/dirs exist, replay ledger
cmd_repair() {
  mkdir -p "$SWARM_DIR" "$VIEWS_DIR" "$HANDOFFS_DIR" "$DECISIONS_DIR"
  touch "$LEDGER"
  ledger_validate || die "Ledger has invalid lines; manual cleanup needed"
  state_rebuild   || die "State rebuild failed"
  views_render_all
  ok "Repaired. Events: $(ledger_count)"
}

# Replay: force-rebuild state.json + views from ledger
cmd_replay() {
  require_swarm
  state_rebuild   || die "State rebuild failed"
  views_render_all
  ok "Replayed $(ledger_count) events"
}

cmd_render() {
  require_swarm
  views_render_all
  ok "Views rendered: $VIEWS_DIR/"
}
