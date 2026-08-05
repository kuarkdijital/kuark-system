#!/bin/bash
# Convert ~/.kuark/agents/*/SKILL.md → ~/.claude/agents/kuark-*.md
#
# Adds Claude Code native sub-agent frontmatter:
#   - name:        kuark-<agent>
#   - description: routing hint (one line, action-oriented)
#   - tools:       scoped per role
#   - model:       opus for code-writing agents, sonnet for others
#
# Appends a "Handoff Protocol" section so each fresh sub-agent knows to
# read the latest .swarm/handoffs/HOFF-*.md on start and write one on finish.
#
# Usage: bash bin/generate-claude-agents.sh [--source DIR] [--target DIR] [--dry-run]
#
# Compatible with macOS bash 3.2 (no associative arrays).

set -u

SRC="$HOME/.kuark/agents"
TGT="$HOME/.claude/agents"
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --source)  SRC="$2"; shift 2 ;;
    --target)  TGT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *)         echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -d "$SRC" ] || { echo "Source missing: $SRC" >&2; exit 1; }
[ $DRY -eq 1 ] || mkdir -p "$TGT"

# ── Model assignment (opus for code-writing + arch + devops) ──
model_for() {
  case "$1" in
    architect|nestjs-developer|nextjs-developer|database-engineer|queue-developer|python-developer|qa-engineer|security-engineer|devops-engineer|ui-ux-designer) echo "opus" ;;
    *) echo "sonnet" ;;
  esac
}

# ── Tools allocation ────────────────────────────────────────
tools_for() {
  case "$1" in
    nestjs-developer|nextjs-developer|database-engineer|queue-developer|python-developer|qa-engineer|devops-engineer|hadron-engineer|documentation)
      echo "Read, Write, Edit, Bash, Grep, Glob, TodoWrite" ;;
    security-engineer)
      echo "Read, Bash, Grep, Glob, TodoWrite" ;;
    product-owner|project-manager|analyst|architect|orchestrator)
      echo "Read, Write, Edit, Bash, Grep, Glob, TodoWrite, WebFetch" ;;
    api-researcher)
      echo "Read, Write, Bash, Grep, Glob, WebFetch, WebSearch, TodoWrite" ;;
    ui-ux-designer)
      echo "Read, Write, Edit, Bash, Grep, Glob, TodoWrite, Skill" ;;
    *)
      echo "Read, Write, Edit, Bash, Grep, Glob, TodoWrite" ;;
  esac
}

# ── One-line routing descriptions ───────────────────────────
description_for() {
  case "$1" in
    product-owner)     echo "Vizyon, kullanıcı gereksinimleri toplama, backlog yönetimi. Use when starting a new project, gathering requirements, or prioritizing features." ;;
    project-manager)   echo "Sprint planlama, task oluşturma ve dağıtımı, ilerleme takibi. Use when breaking a backlog into sprints/tasks, assigning work, or planning capacity." ;;
    analyst)           echo "User story analizi, kabul kriterleri, gereksinim netleştirme. Use when refining user stories or writing acceptance criteria." ;;
    architect)         echo "Mimari kararlar, ADR yazımı, teknoloji seçimi, sistem tasarımı. Use for architecture decisions, ADRs, technology selection, or system design." ;;
    nestjs-developer)  echo "NestJS backend modülleri (controller, service, guard, DTO, processor). Use when building backend API modules, services, or guards." ;;
    nextjs-developer)  echo "Next.js 15 App Router sayfalar, RSC/Client components, formlar, state. Use when building frontend pages, components, or client-side flows." ;;
    database-engineer) echo "Prisma schema tasarımı, migration, multi-tenant model, index optimization. Use when designing database schema, writing migrations, or optimizing queries." ;;
    queue-developer)   echo "BullMQ processor, background job, scheduled task implementation. Use when building background jobs, queues, or scheduled processors." ;;
    python-developer)  echo "FastAPI mikroservis, Pydantic model, async Python kod. Use when building Python microservices or FastAPI endpoints." ;;
    qa-engineer)       echo "Unit/integration/E2E test yazımı, coverage, test stratejisi. Use when writing tests, planning test strategy, or improving coverage." ;;
    security-engineer) echo "Güvenlik audit, RBAC, JWT, OWASP review, vulnerability scan. Use for security audits, auth review, or vulnerability assessment." ;;
    devops-engineer)   echo "Docker, CI/CD, Railway/Nixpacks, deployment, infrastructure. Use for deployment, Docker configuration, CI/CD pipelines, or infrastructure." ;;
    hadron-engineer)   echo "Hadron (Dokploy fork) self-hosted PaaS deploy, hadron-mcp ops. Use for Hadron-specific deployment and infrastructure tasks." ;;
    ui-ux-designer)    echo "UI tasarımı + design system — frontend-design skill'i ile production-grade Tailwind/shadcn kodu üretir (wireframe değil). Use when designing screens, components, or design systems." ;;
    api-researcher)    echo "3rd party API araştırma, entegrasyon dokümantasyonu (iyzico, banka POS, vb.). Use when researching third-party APIs or planning integrations." ;;
    documentation)     echo "README, API docs, technical documentation yazımı. Use when writing or updating project documentation." ;;
    orchestrator)      echo "Multi-agent koordinasyon, paralel dispatch, handoff yönetimi. Use to coordinate complex multi-agent workflows." ;;
    *)                 echo "Kuark $1 agent" ;;
  esac
}

# ── Handoff protocol section appended to every agent ────────
read -r -d '' HANDOFF_PROTOCOL <<'PROTO' || true

---

## Kuark Handoff Protocol (REQUIRED)

You are a **pure sub-agent**. You do NOT write directly to `.swarm/ledger.jsonl` —
the orchestrator is the single writer. Your responsibilities:

### User input rule (CRITICAL)

Whenever you need input from the user — preferences, choices, confirmations,
clarifications, anything — follow the **platform user-input protocol**
(`~/.kuark/references/user-input-protocol.md`):

- **Claude Code:** use the `AskUserQuestion` tool (2–4 choices, "Other" auto).
- **Cursor / Codex:** numbered options `1)` `2)` `3)` `Other)` — no unstructured free-text.

- Never ask the user free-text questions in chat (except Other / open-ended creative).
- Reason: structured UI is faster, prevents typos, produces parseable answers,
  and keeps the wizard consistent across sub-agents.

### When you start
1. Read the latest handoff payload directed to you:
   ```bash
   ls -t .swarm/handoffs/HOFF-*.md 2>/dev/null | head -1 | xargs cat
   ```
2. If a task ID was passed in your prompt, read `kuark task show <TASK-ID>`.
3. Read `.swarm/views/dashboard.md` for current project context.
4. Read any relevant `.swarm/decisions/DEC-*.md` mentioned in the handoff.

### While you work
- Use `TodoWrite` for your own internal step tracking (not visible in ledger).
- If you make an architecture decision, write a draft to `.swarm/decisions/DEC-DRAFT-<topic>.md` for the orchestrator to formalize.
- Keep changes scoped to the task you were dispatched for. Out-of-scope work → flag to orchestrator.

### When you finish
1. Write a structured handoff payload draft for the orchestrator to formalize:
   - Create `.swarm/handoffs/HOFF-DRAFT-<your-role>-<timestamp>.md`
   - Sections required: **What Was Done**, **Decisions Made**, **Open Questions**, **Context For Next Agent**, **Acceptance Criteria For Next Step**
2. Return a concise summary (under 300 words) to the orchestrator with:
   - Task ID completed
   - Path to your DRAFT handoff payload
   - Path to any DRAFT decisions
   - Any blockers or open questions

The orchestrator reads your DRAFT files, formalizes them via `kuark handoff` / `kuark decide`, and dispatches the next agent.

### Zero-tolerance rules (always apply)
- `organizationId` filter on ALL multi-tenant queries
- `@UseGuards(JwtAuthGuard, FullAccessGuard)` on protected routes
- `class-validator` DTOs on all inputs
- All UI states: loading, error, empty, success
- TypeScript strict — no `any` without explicit reason
- Run `npx tsc --noEmit` and `npx prisma validate` before claiming done
PROTO

# ── Generator loop ──────────────────────────────────────────
count=0
for skill in "$SRC"/*/SKILL.md; do
  [ -f "$skill" ] || continue
  agent=$(basename "$(dirname "$skill")")
  model=$(model_for "$agent")
  tools=$(tools_for "$agent")
  desc=$(description_for "$agent")

  # Strip existing frontmatter (between first two `---` lines)
  body=$(awk '
    BEGIN { fm_count = 0; in_fm = 0; }
    /^---$/ {
      fm_count++
      if (fm_count == 1) { in_fm = 1; next }
      if (fm_count == 2) { in_fm = 0; next }
    }
    !in_fm { print }
  ' "$skill")

  out="$TGT/kuark-$agent.md"

  if [ $DRY -eq 1 ]; then
    printf "[dry-run] %-25s → %s (model=%s)\n" "$agent" "$out" "$model"
  else
    {
      printf -- '---\n'
      printf 'name: kuark-%s\n' "$agent"
      printf 'description: %s\n' "$desc"
      printf 'tools: %s\n' "$tools"
      printf 'model: %s\n' "$model"
      printf -- '---\n\n'
      printf '# Kuark %s\n' "$agent"
      printf '%s\n' "$body"
      printf '%s\n' "$HANDOFF_PROTOCOL"
    } > "$out"
    printf "  %-25s → %s (%s)\n" "$agent" "$out" "$model"
  fi
  count=$((count + 1))
done

echo
echo "Done. $count agents generated."
[ $DRY -eq 0 ] && echo "Sub-agents are now available in Claude Code (subagent_type: kuark-<name>)."
exit 0
