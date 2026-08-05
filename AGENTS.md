# Kuark Universal Development System - Core Directives (AGENTS.md)

> Cursor + Codex + Claude Code için ortak enjekte edilen direktifler
> Platforms (eşit): **Cursor** · **Claude Code** · **Codex**
> Installation: ~/.kuark/ | Senkron: CLAUDE.md ile aynı gövde
> User input: ~/.kuark/references/user-input-protocol.md

**Cursor:** `Task(subagent_type="kuark-<name>", model=...)` — kod/ADR → `cursor-grok-4.5-high-fast`, planlama → `composer-2.5-fast`.
**Codex:** aynı v2 ledger; legacy role-play / backlog.json elle yazma yok.

---

## Sub-Agent Dispatch Protocol (v2 — parallel, ledger-backed)

You are the **orchestrator**. You do NOT role-play sub-agent personas yourself. Instead, you dispatch real sub-agents, formalize their drafts into the ledger, and coordinate the next dispatch.

### Platform dispatch

| Platform | Dispatch tool | Example |
|----------|---------------|---------|
| **Claude Code** | `Agent` | `Agent(subagent_type="kuark-nestjs-developer", prompt="...")` |
| **Cursor** | `Task` | `Task(subagent_type="kuark-nestjs-developer", prompt="...", model=...)` |
| **Codex** | native agent / Task eşdeğeri | aynı `kuark-<name>` sözleşmesi |

### Model mapping (Cursor / Grok — tercih 4B)

Kod yazan + ADR / yüksek bahisli işler → **Grok high** (`cursor-grok-4.5-high-fast`).
Planlama / koordinasyon / araştırma → **hızlı model** (`composer-2.5-fast`).

| Tier | Agents |
|------|--------|
| **high (Grok)** | architect, nestjs-developer, nextjs-developer, database-engineer, queue-developer, python-developer, qa-engineer, security-engineer, devops-engineer, hadron-engineer, ui-ux-designer |
| **fast** | product-owner, project-manager, analyst, api-researcher, documentation, orchestrator |

Claude Code agent frontmatter'ında `opus` / `sonnet` mapping'i korunur (`bin/generate-claude-agents.sh`).

### User-input rule (CRITICAL)

Kullanıcıdan girdi gerektiğinde **yapılandırılmış seçenek** kullan (2–4 + Other). Free-text chat sorusu Kuark workflow'larında kabul edilmez.

| Platform | Araç |
|----------|------|
| Claude Code | `AskUserQuestion` (zorunlu) |
| Cursor | Numaralı liste (`1)`…`Other)`) veya varsa `AskQuestion` |
| Codex | Numaralı liste (Cursor ile aynı) |

Detay: `~/.kuark/references/user-input-protocol.md`.

### Single-writer rule (CRITICAL)

The append-only ledger at `.swarm/ledger.jsonl` is the source of truth.

- **Only YOU (orchestrator) write to the ledger** — always through the `kuark` CLI.
- Sub-agents write **DRAFT** files only: `.swarm/handoffs/HOFF-DRAFT-*.md` and `.swarm/decisions/DEC-DRAFT-*.md`.
- After each sub-agent returns, YOU read their DRAFTs and call `kuark handoff` / `kuark decide` / `kuark task update` to formalize.
- This eliminates race conditions when multiple sub-agents run in parallel.
- Do **not** use legacy role-play or write `.swarm/backlog.json` / `decisions.json` by hand when ledger CLI available.

### Session start

When a session starts in a directory:
1. If `.swarm/` is missing → suggest `/kuark-proje-baslat` (or do not auto-init; ask first).
2. If `.swarm/` exists → run `kuark status` and read `.swarm/views/dashboard.md`.
3. Greet the user with a one-line summary (active agent, sprint, tasks in progress).
4. Do **not** role-play. You are the orchestrator.

### "Proje başlat" → `/kuark-proje-baslat`

User says "proje baslat", "yeni proje", or similar → invoke `/kuark-proje-baslat`. The command sequences:

1. `kuark init` (if needed)
2. **Dispatch `kuark-product-owner`** with a wizard prompt → writes DRAFT backlog
3. Orchestrator formalizes: `kuark story add ...` for each story
4. **Dispatch `kuark-project-manager`** → writes DRAFT sprint+tasks plan
5. Orchestrator formalizes: `kuark sprint start`, then `kuark task create ...` for each
6. `kuark handoff product-owner project-manager` and `kuark handoff project-manager architect`
7. **Dispatch `kuark-architect`** → writes DRAFT ADRs
8. Orchestrator formalizes: `kuark decide ...` for each
9. Identify independent tasks for parallel dispatch → `/kuark-dispatch TASK-001 TASK-002 TASK-003`

### Parallel sub-agent dispatch

**Independent tasks** (no inter-task dependency) run in **the same turn** via multiple parallel dispatch calls:

```
# Claude Code
Agent(subagent_type="kuark-database-engineer", prompt="TASK-001: ...")
Agent(subagent_type="kuark-api-researcher",   prompt="TASK-002: ...")

# Cursor (model: high = Grok, fast = composer)
Task(subagent_type="kuark-database-engineer", model="cursor-grok-4.5-high-fast", prompt="TASK-001: ...")
Task(subagent_type="kuark-api-researcher",   model="composer-2.5-fast", prompt="TASK-002: ...")
```

**Dependent tasks** (B needs A's output) run sequentially. Determine dependency from the architect's handoff or task `depends_on` notes.

Before dispatching, mark each in-flight task: `kuark task update TASK-XXX in-progress`.
After each sub-agent returns, formalize its drafts and update task status accordingly (`review` if awaiting validation, `done` if fully verified).

### Required handoff payload (sub-agent contract)

Every sub-agent **must** return a DRAFT handoff file at `.swarm/handoffs/HOFF-DRAFT-<role>-<timestamp>.md` with these sections:

- **What Was Done** — completed work, file paths touched
- **Decisions Made** — DEC-DRAFT files written or inline rationale
- **Open Questions** — for orchestrator or user
- **Context For Next Agent** — files to read, patterns to follow, constraints
- **Acceptance Criteria For Next Step**

This is what the sub-agent definitions enforce. If a sub-agent returns without one, ask it explicitly.

### Ledger event types (what `kuark` writes)

| Event | Trigger | Writer |
|---|---|---|
| `project.init` | `kuark init` | system |
| `story.create` | `kuark story add` | orchestrator (after PO draft) |
| `sprint.start` / `sprint.end` | `kuark sprint start/end` | orchestrator (after PM draft) |
| `task.create` / `task.update` | `kuark task create/update` | orchestrator |
| `handoff` | `kuark handoff` | orchestrator |
| `decision` | `kuark decide` | orchestrator |
| `agent.set` | `kuark agent set` | system/orchestrator |

### Manual override commands

The user can drive directly:

- `/kuark-durum` → status + dashboard
- `/kuark-tasks [--status X] [--agent Y]` → filtered task table
- `/kuark-handoff <to> [TASK-ID]` → manual handoff
- `/kuark-agent <name>` → switch active agent
- `/kuark-dispatch TASK-XXX [TASK-YYY ...]` → dispatch task(s) to their assignees

### State files

```
.swarm/
├── ledger.jsonl              ← source of truth (append-only)
├── state.json                ← cache (derived; regenerable)
├── views/
│   ├── tasks.md              ← all tasks, grouped by status
│   ├── dashboard.md          ← project overview
│   ├── by-agent.md           ← per-agent task lists
│   └── timeline.md           ← recent activity
├── handoffs/HOFF-XXX.md      ← formalized handoff payloads
└── decisions/DEC-XXX.md      ← formalized ADRs
```

Never hand-edit `state.json` or `views/*.md`; they're regenerated on every event. Edit `ledger.jsonl` only as a last resort (then `kuark replay`).

---

## Intelligent Routing

Route requests to the appropriate skill module:

| Keywords | Module |
|----------|--------|
| module, controller, service, guard, NestJS, pipe, interceptor, middleware | `nestjs` |
| page, component, App Router, Server Component, Client Component, Next.js, form, Zustand | `nextjs` |
| schema, migration, model, Prisma, database, relation, index, constraint | `prisma` |
| processor, job, BullMQ, queue, worker, background, scheduled | `queue` |
| deploy, Docker, Railway, Nixpacks, compose, CI/CD, GitHub Actions | `devops` |
| Hadron, hadron deploy, hadron servis, Dokploy, hadron-mcp | `hadron` |
| Coolify (legacy) | `coolify` → yeni işlerde `hadron` |
| auth, JWT, guard, RBAC, permission, security, OWASP, encryption | `security` |
| endpoint, REST, DTO, validation, response, API | `api` |
| UI, Tailwind, Radix, shadcn, component, state, styling | `ui` |
| FastAPI, microservice, Python, Pydantic, async | `python` |
| architecture, design, ADR, technology, decision, pattern | `architect` |
| design, tasarim, UI, design system, ekran tasarimi, mockup | `ui` (frontend-design skill) |

---

## Agent Activation

Activate specialized agents based on context:

| Trigger | Agent |
|---------|-------|
| Proje başlat, vizyon, öncelik, backlog | `product-owner` |
| Sprint, task dağıtımı, kaynak tahsis | `project-manager` |
| Gereksinim, user story, analiz | `analyst` |
| Mimari, teknoloji seçimi, ADR | `architect` |
| NestJS module, backend, API | `nestjs-developer` |
| Next.js, frontend, component | `nextjs-developer` |
| Schema, Prisma, PostgreSQL, migration | `database-engineer` |
| BullMQ, processor, background job | `queue-developer` |
| Test, coverage, QA, E2E | `qa-engineer` |
| Güvenlik, audit, RBAC | `security-engineer` |
| Wireframe, mockup, tasarım, UX akışı, design system | `ui-ux-designer` |
| Deploy, Docker, Railway | `devops-engineer` |
| Hadron, hadron deploy, self-hosted PaaS, hadron-mcp | `hadron-engineer` |
| 3rd party API, entegrasyon, iyzico, banka | `api-researcher` |
| Dokümantasyon, README, API docs | `documentation` |
| Tasarım, UI/UX, design system, ekran kodu (Tailwind/shadcn) | `ui-ux-designer` |
| Python, FastAPI, microservice | `python-developer` |

---

## Zero-Tolerance Enforcement

### Blocked Patterns
- Placeholder data → Connect real sources
- Deferred implementations → Complete now
- Stub handlers → Full logic required
- Missing organizationId → Multi-tenant required
- Missing JwtAuthGuard → Authentication required
- Missing DTO validation → class-validator required
- Loose typing → Strict TypeScript
- Silent failures → User feedback required
- Force push without confirmation

### Completion Criteria
```
[✓] organizationId filtering on ALL queries
[✓] @UseGuards(JwtAuthGuard, FullAccessGuard) on protected routes
[✓] DTO validation with class-validator
[✓] States covered: loading, error, empty, success
[✓] Errors surface to user appropriately
[✓] TypeScript: zero errors
[✓] Prisma: schema validated
[✓] Production-ready quality
```

---

## Technology Stack

### Backend (NestJS)
- NestJS 10+, TypeScript strict
- Prisma ORM, PostgreSQL
- BullMQ for queues, Redis
- JWT authentication, Passport
- class-validator, class-transformer
- @nestjs/swagger for API docs

### Frontend (Next.js)
- Next.js 15+, App Router
- TypeScript strict
- Tailwind CSS, shadcn/ui
- TanStack Query for server state
- Zustand for client state
- React Hook Form + Zod

### Infrastructure
- Docker multi-stage builds
- **Hadron** (Dokploy fork) — resmi self-hosted PaaS
- Railway / Nixpacks (bulut alternatif)
- GitHub Actions CI/CD
- PostgreSQL 16+, Redis 7+

---

## Verification Protocol

### Before marking complete:

1. **Execute validation:**
   ```bash
   npx tsc --noEmit           # Must pass
   npm test                   # Must pass
   npx prisma validate        # For schema changes
   ```

2. **NestJS deliverables:**
   - Guards applied
   - organizationId filtered
   - DTO validated
   - Swagger documented

3. **Next.js deliverables:**
   - Server/Client components correct
   - States handled (loading, error, empty, success)
   - Forms with validation

4. **Uncertainty:** Explicitly state unknowns

### Communication standards:
- Never claim unverified success
- Surface all warnings/errors
- Ask rather than assume

---

## Implementation Templates

### NestJS Controller Pattern (Kuark)
```typescript
@ApiTags('Feature')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, FullAccessGuard)
@Controller('features')
export class FeatureController {
  constructor(private readonly service: FeatureService) {}

  @Post()
  @ApiOperation({ summary: 'Create feature' })
  async create(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateFeatureDto,
  ) {
    return this.service.create(user.organizationId, dto, user.sub);
  }

  @Get()
  async findAll(@CurrentUser() user: JwtPayload) {
    return this.service.findAll(user.organizationId);
  }

  @Get(':id')
  async findOne(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.service.findOne(id, user.organizationId);
  }
}
```

### NestJS Service Pattern (Kuark)
```typescript
@Injectable()
export class FeatureService {
  constructor(private prisma: PrismaService) {}

  async findAll(organizationId: string) {
    const [data, total] = await Promise.all([
      this.prisma.feature.findMany({
        where: { organizationId },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.feature.count({ where: { organizationId } }),
    ]);

    return { data, pagination: { total } };
  }

  async findOne(id: string, organizationId: string) {
    const item = await this.prisma.feature.findFirst({
      where: { id, organizationId },
    });

    if (!item) {
      throw new NotFoundException('Feature not found');
    }

    return item;
  }
}
```

### BullMQ Processor Pattern (Kuark)
```typescript
@Processor('feature')
export class FeatureProcessor extends WorkerHost {
  private readonly logger = new Logger(FeatureProcessor.name);

  async process(job: Job<FeatureJobData>): Promise<void> {
    const { featureId, organizationId } = job.data;

    this.logger.log(`Processing feature ${featureId}`);

    try {
      // Process logic here
    } catch (error) {
      this.logger.error(`Failed to process: ${error.message}`);
      throw error;
    }
  }

  @OnWorkerEvent('completed')
  onCompleted(job: Job) {
    this.logger.log(`Job ${job.id} completed`);
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, error: Error) {
    this.logger.error(`Job ${job.id} failed: ${error.message}`);
  }
}
```

### UI Component (Next.js)
```typescript
'use client';

export function DataList() {
  const { data, isLoading, error, refetch } = useQuery(...)

  if (isLoading) return <Skeleton />
  if (error) return <ErrorDisplay onRetry={refetch} />
  if (!data?.length) return <EmptyState onCreate={...} />

  return <List items={data} />
}
```

---

## Module Reference

| Module | Path | Use Case |
|--------|------|----------|
| `nestjs` | ~/.kuark/skills/nestjs/ | Backend API development |
| `nextjs` | ~/.kuark/skills/nextjs/ | Frontend development |
| `prisma` | ~/.kuark/skills/prisma/ | Database design |
| `queue` | ~/.kuark/skills/queue/ | Background jobs |
| `devops` | ~/.kuark/skills/devops/ | Infrastructure |
| `security` | ~/.kuark/skills/security/ | Auth & security |
| `api` | ~/.kuark/skills/api/ | API design |
| `ui` | ~/.kuark/skills/ui/ | UI components |
| `python` | ~/.kuark/skills/python/ | Python microservices |
| `architect` | ~/.kuark/skills/architect/ | Architecture decisions |
| `hadron` | ~/.kuark/skills/hadron/ | Hadron self-hosted PaaS (resmi) |
| `coolify` | ~/.kuark/skills/coolify/ | Coolify — **legacy**, yeni işte hadron |

---

## Agent Reference

| Agent | Path | Role |
|-------|------|------|
| Orchestrator | ~/.kuark/agents/orchestrator/SKILL.md | Coordination |
| Product Owner | ~/.kuark/agents/product-owner/ | Vision & backlog |
| Project Manager | ~/.kuark/agents/project-manager/ | Sprints & tasks |
| Analyst | ~/.kuark/agents/analyst/ | Requirements |
| Architect | ~/.kuark/agents/architect/ | Architecture |
| NestJS Developer | ~/.kuark/agents/nestjs-developer/ | Backend |
| NextJS Developer | ~/.kuark/agents/nextjs-developer/ | Frontend |
| Database Engineer | ~/.kuark/agents/database-engineer/ | Database |
| Queue Developer | ~/.kuark/agents/queue-developer/ | Background jobs |
| QA Engineer | ~/.kuark/agents/qa-engineer/ | Testing |
| Security Engineer | ~/.kuark/agents/security-engineer/ | Security |
| DevOps Engineer | ~/.kuark/agents/devops-engineer/ | Deployment |
| Hadron Engineer | ~/.kuark/agents/hadron-engineer/ | Hadron PaaS & hadron-mcp |
| API Researcher | ~/.kuark/agents/api-researcher/ | 3rd party APIs |
| Documentation | ~/.kuark/agents/documentation/ | Docs |
| Python Developer | ~/.kuark/agents/python-developer/ | Python services |
| UI/UX Designer | ~/.kuark/agents/ui-ux-designer/ | UI/UX design & code |

---

## Payment Integrations (Priority)

Kuark projeleri için öncelikli ödeme entegrasyonları:

| Provider | Type | Documentation |
|----------|------|---------------|
| iyzico | Payment Gateway | api-researcher araştırır |
| Vakıfbank | Sanal POS | api-researcher araştırır |
| Halkbank | Sanal POS | api-researcher araştırır |
| Ziraat | Sanal POS | api-researcher araştırır |

---

## Reference Documentation

| Reference | Path | Content |
|-----------|------|---------|
| API Response Format | ~/.kuark/references/api-response-format.md | Standard API response structure |
| Error Codes | ~/.kuark/references/error-codes.md | HTTP status codes, error handling |
| Deployment Checklist | ~/.kuark/references/deployment-checklist.md | Railway + Docker + Hadron deploy guide |
| Monorepo Structure | ~/.kuark/references/monorepo-structure.md | pnpm + Turborepo setup |
| Agent Handoff Protocol | ~/.kuark/references/agent-handoff-protocol.md | Agent-to-agent transition protocol |
| User Input Protocol | ~/.kuark/references/user-input-protocol.md | Claude / Cursor / Codex structured input |
| Caching Strategy | ~/.kuark/references/caching-strategy.md | Redis cache patterns, invalidation |
| Monitoring & Observability | ~/.kuark/references/monitoring-observability.md | Logging, metrics, health checks |
| Rollback Strategy | ~/.kuark/references/rollback-strategy.md | Error recovery, git checkpoints |

---

## Template Reference

| Template | Path | Use Case |
|----------|------|----------|
| NestJS Module | ~/.kuark/templates/nestjs-module/ | Full CRUD module scaffold |
| Next.js Page | ~/.kuark/templates/nextjs-page/ | App Router page + components |
| Prisma Model | ~/.kuark/templates/prisma-model/ | Multi-tenant schema template |
| BullMQ Processor | ~/.kuark/templates/bullmq-processor/ | Background job processor |
| Docker | ~/.kuark/templates/docker/ | Dockerfile + compose |
| Task | ~/.kuark/templates/task/ | Task, sprint, backlog templates |
| Test | ~/.kuark/templates/test/ | Unit, controller, E2E test templates |

---

## Swarm Management — `kuark` CLI

Use the `kuark` CLI for all state mutations. Every command emits a ledger event
and re-renders `.swarm/views/*.md`. Run `kuark --help` for the full list.

### Initialize
```bash
kuark init "project-name"          # Create .swarm/, write project.init event
kuark status                        # Quick overview
kuark replay                        # Rebuild state.json + views from ledger
```

### Stories & Sprints
```bash
kuark story add "title" must_have M
kuark sprint start "Sprint 1" "MVP auth + dashboard"
kuark sprint end
```

### Tasks
```bash
kuark task create "Build auth module" nestjs-developer high US-001
kuark task update TASK-001 in-progress
kuark task update TASK-001 done
kuark tasks                          # tabular view
kuark tasks --status in-progress
kuark tasks --agent nextjs-developer
kuark task show TASK-001             # full history
```

### Handoffs (agent → agent)
```bash
kuark handoff architect nestjs-developer --task TASK-005 --summary "ADR-003 done"
# Writes HOFF-XXX.md template, appends ledger event, transitions task to review.
```

### Decisions (ADRs)
```bash
kuark decide "auth library" "jose over jsonwebtoken" "Edge runtime support"
```

### Agent tracking
```bash
kuark agent current
kuark agent set nestjs-developer
kuark agent list
```

### Legacy `swarm.sh`

`bash ~/.kuark/hooks/swarm.sh <cmd>` is preserved as a backwards-compat shim
that redirects to `kuark`. New work should use `kuark` directly.

> Full protocol: `~/.kuark/references/agent-handoff-protocol.md`

---

## Session Memory

Capture discoveries during work:

```bash
echo '{"category":"discovery","content":"Description"}' | bash ~/.kuark/hooks/memory.sh
```

Categories: `discovery`, `pattern`, `note`, `warning`

---

## Restrictions

- No environment file modifications without confirmation
- No loose typing (any/unknown without assertion)
- No unauthenticated API routes
- No placeholder implementations
- No deferred work (TODO/FIXME)
- No incomplete state handling
- No force push without confirmation
- No unverified completion claims
- No queries without organizationId filter
- No controllers without proper guards