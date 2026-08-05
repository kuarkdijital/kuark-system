#!/bin/bash
# Convert ~/.kuark/agents/*/SKILL.md → ~/.cursor/skills/kuark-<agent>/SKILL.md
#
# Cursor skill frontmatter + handoff protocol + model tier hints (Grok high / fast).
#
# Usage: bash bin/generate-cursor-agents.sh [--source DIR] [--target DIR] [--dry-run]

set -u

SRC="$HOME/.kuark/agents"
TGT="$HOME/.cursor/skills"
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

# ── Model tier (Cursor Task tool) ──
# high  → cursor-grok-4.5-high-fast
# fast  → composer-2.5-fast
model_tier_for() {
  case "$1" in
    architect|nestjs-developer|nextjs-developer|database-engineer|queue-developer|python-developer|qa-engineer|security-engineer|devops-engineer|hadron-engineer|ui-ux-designer)
      echo "high" ;;
    *) echo "fast" ;;
  esac
}

model_slug_for() {
  case "$(model_tier_for "$1")" in
    high) echo "cursor-grok-4.5-high-fast" ;;
    *)    echo "composer-2.5-fast" ;;
  esac
}

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
    ui-ux-designer)    echo "UI tasarımı + design system — frontend-design skill'i ile production-grade Tailwind/shadcn kodu üretir. Use when designing screens, components, or design systems." ;;
    api-researcher)    echo "3rd party API araştırma, entegrasyon dokümantasyonu (iyzico, banka POS, vb.). Use when researching third-party APIs or planning integrations." ;;
    documentation)     echo "README, API docs, technical documentation yazımı. Use when writing or updating project documentation." ;;
    orchestrator)      echo "Multi-agent koordinasyon, paralel dispatch, handoff yönetimi. Use to coordinate complex multi-agent workflows." ;;
    *)                 echo "Kuark $1 agent" ;;
  esac
}

read -r -d '' HANDOFF_PROTOCOL <<'PROTO' || true

---

## Kuark Handoff Protocol (REQUIRED)

You are a **pure sub-agent**. You do NOT write directly to `.swarm/ledger.jsonl` —
the orchestrator is the single writer. Your responsibilities:

### User input rule (CRITICAL)

Whenever you need input from the user, use the **platform user-input protocol**:
- Claude Code: `AskUserQuestion` (2–4 options + Other)
- Cursor / Codex: numbered options `1)` `2)` `3)` `Other)` — never unstructured free-text questions

See `~/.kuark/references/user-input-protocol.md`.

### When you start
1. Read the latest handoff payload directed to you:
   ```bash
   ls -t .swarm/handoffs/HOFF-*.md 2>/dev/null | head -1 | xargs cat
   ```
2. If a task ID was passed in your prompt, read `kuark task show <TASK-ID>`.
3. Read `.swarm/views/dashboard.md` for current project context.
4. Read any relevant `.swarm/decisions/DEC-*.md` mentioned in the handoff.

### While you work
- Use todo tracking for your own internal steps (not ledger).
- Architecture decisions → draft `.swarm/decisions/DEC-DRAFT-<topic>.md`.
- Keep changes scoped to the dispatched task.

### When you finish
1. Write `.swarm/handoffs/HOFF-DRAFT-<your-role>-<timestamp>.md` with:
   **What Was Done**, **Decisions Made**, **Open Questions**, **Context For Next Agent**, **Acceptance Criteria For Next Step**
2. Return a concise summary (<300 words) with Task ID, DRAFT paths, blockers.

### Zero-tolerance rules
- `organizationId` on ALL multi-tenant queries
- `@UseGuards(JwtAuthGuard, FullAccessGuard)` on protected routes
- `class-validator` DTOs on all inputs
- UI states: loading, error, empty, success
- TypeScript strict; run `npx tsc --noEmit` / `npx prisma validate` before claiming done
PROTO

count=0
for skill in "$SRC"/*/SKILL.md; do
  [ -f "$skill" ] || continue
  agent=$(basename "$(dirname "$skill")")
  tier=$(model_tier_for "$agent")
  slug=$(model_slug_for "$agent")
  desc=$(description_for "$agent")

  body=$(awk '
    BEGIN { fm_count = 0; in_fm = 0; }
    /^---$/ {
      fm_count++
      if (fm_count == 1) { in_fm = 1; next }
      if (fm_count == 2) { in_fm = 0; next }
    }
    !in_fm { print }
  ' "$skill")

  outdir="$TGT/kuark-$agent"
  out="$outdir/SKILL.md"

  if [ $DRY -eq 1 ]; then
    printf "[dry-run] %-25s → %s (tier=%s model=%s)\n" "$agent" "$out" "$tier" "$slug"
  else
    mkdir -p "$outdir"
    {
      printf -- '---\n'
      printf 'name: kuark-%s\n' "$agent"
      printf 'description: |\n'
      printf '  %s\n' "$desc"
      printf '  Cursor model hint: %s (%s). Dispatch via Task(subagent_type="kuark-%s", model="%s").\n' "$tier" "$slug" "$agent" "$slug"
      printf -- '---\n\n'
      printf '# Kuark %s\n\n' "$agent"
      printf '**Cursor model:** `%s` (tier: %s)\n\n' "$slug" "$tier"
      printf '%s\n' "$body"
      printf '%s\n' "$HANDOFF_PROTOCOL"
    } > "$out"
    printf "  %-25s → %s (%s)\n" "$agent" "$out" "$slug"
  fi
  count=$((count + 1))
done

# Orchestrator skill alias: replace legacy swarm-team pointer
ORCH_SRC="$SRC/orchestrator/SKILL.md"
SWARM_DIR="$TGT/swarm-team"
if [ -f "$ORCH_SRC" ] && [ $DRY -eq 0 ]; then
  mkdir -p "$SWARM_DIR"
  {
    echo '---'
    echo 'name: swarm-team'
    echo 'description: |'
    echo '  Kuark v2 orchestrator (ledger-backed). Use for proje başlat, sprint, paralel kuark-* Task dispatch.'
    echo '  Legacy role-play swarm-team replaced — prefer Task(subagent_type="kuark-orchestrator") or follow AGENTS.md.'
    echo '---'
    echo ''
    echo '# Kuark Swarm Team (v2)'
    echo ''
    echo 'Bu skill legacy `swarm-team` yerine **Kuark v2** protokolüne yönlendirir.'
    echo ''
    echo '- Direktifler: `~/AGENTS.md` veya `~/.kuark/AGENTS.md`'
    echo '- Dispatch: `Task(subagent_type="kuark-<name>", model=...)`'
    echo '- Model: kod/ADR → `cursor-grok-4.5-high-fast`, planlama → `composer-2.5-fast`'
    echo '- Durum: `kuark status` / `.swarm/views/dashboard.md`'
    echo ''
    echo 'Detay için `~/.cursor/skills/kuark-orchestrator/SKILL.md`.'
  } > "$SWARM_DIR/SKILL.md"
  echo "  swarm-team               → $SWARM_DIR/SKILL.md (v2 pointer)"
fi

echo
echo "Done. $count Cursor skills generated under $TGT/kuark-*."
exit 0
