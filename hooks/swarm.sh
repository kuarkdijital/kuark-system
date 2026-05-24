#!/bin/bash
# swarm.sh — backwards-compat shim for the legacy Kuark swarm CLI
#
# This script used to be ~1000 lines managing .swarm/ JSON/MD files. It has been
# superseded by the `kuark` CLI which uses an append-only ledger.jsonl as the
# source of truth and auto-renders .swarm/views/*.md as the dashboard.
#
# Old call patterns are translated to the new CLI here. New work should call
# `kuark` directly. This shim exists so existing projects/scripts/hook chains
# don't break.

set -u

KUARK_HOME="${KUARK_HOME:-$HOME/.kuark}"
KUARK_BIN="$KUARK_HOME/kuark"

# Prefer the installed binary; fall back to source repo if running from a checkout
if [ ! -x "$KUARK_BIN" ]; then
  for candidate in "$HOME/Documents/kuark-system/kuark" "$(dirname "$0")/../kuark"; do
    if [ -x "$candidate" ]; then KUARK_BIN="$candidate"; break; fi
  done
fi

if [ ! -x "$KUARK_BIN" ]; then
  echo "swarm.sh: kuark binary not found (looked in $KUARK_HOME/kuark)" >&2
  echo "  Run install: bash ~/.kuark/install.sh" >&2
  exit 1
fi

# Deprecation notice (silenceable)
if [ "${KUARK_SILENCE_DEPRECATION:-0}" != "1" ]; then
  printf '\033[1;33m[deprecated]\033[0m swarm.sh is a shim; use `kuark` directly. (export KUARK_SILENCE_DEPRECATION=1 to silence)\n' >&2
fi

cmd="${1:-status}"
shift 2>/dev/null || true

case "$cmd" in
  init)
    exec "$KUARK_BIN" init "$@"
    ;;
  status)
    exec "$KUARK_BIN" status
    ;;
  repair)
    exec "$KUARK_BIN" repair
    ;;
  replay)
    exec "$KUARK_BIN" replay
    ;;

  task)
    sub="${1:-list}"; shift 2>/dev/null || true
    case "$sub" in
      create)  exec "$KUARK_BIN" task create "$@" ;;
      update)  exec "$KUARK_BIN" task update "$@" ;;
      list)    exec "$KUARK_BIN" task list "$@" ;;
      show)    exec "$KUARK_BIN" task show "$@" ;;
      *)       echo "swarm.sh task: unknown subcommand: $sub" >&2; exit 1 ;;
    esac
    ;;

  sprint)
    sub="${1:-status}"; shift 2>/dev/null || true
    case "$sub" in
      start)   exec "$KUARK_BIN" sprint start "$@" ;;
      end)     exec "$KUARK_BIN" sprint end ;;
      status)  exec "$KUARK_BIN" sprint status ;;
      *)       echo "swarm.sh sprint: unknown subcommand: $sub" >&2; exit 1 ;;
    esac
    ;;

  handoff)
    # Old signature: swarm.sh handoff <from> <to> [TASK-XXX] ["summary"]
    # New signature: kuark handoff <from> <to> [--task TASK-XXX] [--summary "..."]
    from="${1:-}"; to="${2:-}"
    task="${3:-}"; summary="${4:-}"
    args=("$from" "$to")
    [ -n "$task" ] && [ "$task" != "-" ] && args+=("--task" "$task")
    [ -n "$summary" ]                     && args+=("--summary" "$summary")
    exec "$KUARK_BIN" handoff "${args[@]}"
    ;;

  agent)
    sub="${1:-current}"; shift 2>/dev/null || true
    case "$sub" in
      set)     exec "$KUARK_BIN" agent set "$@" ;;
      current) exec "$KUARK_BIN" agent current ;;
      list)    exec "$KUARK_BIN" agent list ;;
      *)       echo "swarm.sh agent: unknown subcommand: $sub" >&2; exit 1 ;;
    esac
    ;;

  *)
    cat >&2 <<EOF
swarm.sh — legacy shim. Use \`kuark\` directly for new work.

Supported legacy commands (translated to kuark):
  init [name]
  status | repair | replay
  task create|update|list|show ...
  sprint start|end|status ...
  handoff <from> <to> [TASK-ID] [summary]
  agent set|current|list ...

Run \`kuark --help\` for the full new CLI.
EOF
    exit 1
    ;;
esac
