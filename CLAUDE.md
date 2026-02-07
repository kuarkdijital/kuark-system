# Kuark Universal Development System - Core Directives

> Kuark şirketine özel multi-agent development sistemi
> Installation: ~/.kuark/ | Hooks: ~/.claude/settings.json
> Reference: ~/.kuark/CONVENTIONS.md for detailed standards

---

## Automatic Orchestration Protocol

### Session Start Behavior

When a Claude Code session starts in any project:
1. The SessionStart hook auto-initializes `.swarm/` if missing
2. `.swarm/context/active-agent.json` determines the current agent
3. If no active agent exists, default to `product-owner`
4. The agent's SKILL.md is loaded from `~/.kuark/agents/{agent}/SKILL.md`
5. Greet the user in the active agent's role
6. Follow the agent's protocol from its SKILL.md

### "Proje Baslat" Automatic Flow

When user says "proje baslat", "yeni proje", or similar, follow this automatic chain:

**Phase 1: Product Owner**
1. Activate `product-owner` role
2. Ask the questions from `~/.kuark/agents/product-owner/SKILL.md`
3. Gather requirements from user (vizyon, kapsam, teknik gereksinimler)
4. Write user stories to `.swarm/backlog.json` in this format:
   ```json
   {
     "items": [
       {
         "id": "US-001",
         "title": "...",
         "story": "Kullanici olarak... istiyorum ki... boylece...",
         "priority": "must_have",
         "effort": "M",
         "acceptance_criteria": ["..."],
         "technical_notes": "..."
       }
     ]
   }
   ```
5. Update `.swarm/project.json` with project details
6. Execute: `bash ~/.kuark/hooks/swarm.sh handoff product-owner project-manager`
7. Announce: "Gereksinimler toplandi. Project Manager rolune geciyorum."

**Phase 2: Project Manager**
1. Activate `project-manager` role, read `~/.kuark/agents/project-manager/SKILL.md`
2. Read `.swarm/backlog.json` for user stories
3. Start sprint: `bash ~/.kuark/hooks/swarm.sh sprint start "Sprint 1" "Sprint hedefi"`
4. Create tasks for each user story:
   ```bash
   bash ~/.kuark/hooks/swarm.sh task create "Task Title" "assigned-agent" "priority" "US-XXX"
   ```
5. Execute: `bash ~/.kuark/hooks/swarm.sh handoff project-manager architect`
6. Announce: "Sprint planlandi, X task olusturuldu. Mimari tasarima geciyorum."

**Phase 3: Architect**
1. Activate `architect` role, read `~/.kuark/agents/architect/SKILL.md`
2. Read tasks and backlog
3. Make architectural decisions, write to `.swarm/context/decisions.json`
4. Handoff to `ui-ux-designer` for UI/UX tasks, or directly to developer agents for backend-only tasks

**Phase 4: UI/UX Designer**
1. Activate `ui-ux-designer` role, read `~/.kuark/agents/ui-ux-designer/SKILL.md`
2. Read architectural decisions and user stories
3. Create wireframes/mockups using Pencil MCP (.pen files)
4. Define design system (colors, typography, spacing tokens)
5. Write component specs for each screen
6. Design all states: loading, error, empty, success
7. Execute: `bash ~/.kuark/hooks/swarm.sh handoff ui-ux-designer nextjs-developer TASK-XXX "Design tamamlandi"`
8. Announce: "Tasarimlar tamamlandi. Frontend gelistirmeye geciyorum."

**Phase 5+: Development Agents**
Follow the standard chain per task type:
```
database-engineer → nestjs-developer → ui-ux-designer → nextjs-developer → qa-engineer → security-engineer → devops-engineer
```

### Agent Transition Rules

When transitioning between agents, ALWAYS:
1. Run `bash ~/.kuark/hooks/swarm.sh task update TASK-XXX review` (for outgoing task)
2. Run `bash ~/.kuark/hooks/swarm.sh handoff {current-agent} {next-agent} TASK-XXX "summary"`
3. Read the next agent's SKILL.md: `cat ~/.kuark/agents/{next-agent}/SKILL.md`
4. Announce the role change to the user
5. Continue with the next agent's responsibilities

### State File Update Rules

ALWAYS update .swarm files as work progresses:
- Writing user stories → update `.swarm/backlog.json`
- Creating tasks → `bash ~/.kuark/hooks/swarm.sh task create ...`
- Starting work on a task → `bash ~/.kuark/hooks/swarm.sh task update TASK-XXX in-progress`
- Completing a task → `bash ~/.kuark/hooks/swarm.sh task update TASK-XXX done`
- Changing agents → `bash ~/.kuark/hooks/swarm.sh handoff ...`
- Making architecture decisions → update `.swarm/context/decisions.json`

### Manual Override Commands

User can override automatic flow at any time:
- "agent degistir: {agent-name}" → Switch to specific agent
- "durumu goster" → Run `bash ~/.kuark/hooks/swarm.sh status`
- "sprint durumu" → Run `bash ~/.kuark/hooks/swarm.sh sprint status`
- "task listesi" → Run `bash ~/.kuark/hooks/swarm.sh task list`
- "backlog goster" → Read `.swarm/backlog.json`

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
| auth, JWT, guard, RBAC, permission, security, OWASP, encryption | `security` |
| endpoint, REST, DTO, validation, response, API | `api` |
| UI, Tailwind, Radix, shadcn, component, state, styling | `ui` |
| FastAPI, microservice, Python, Pydantic, async | `python` |
| architecture, design, ADR, technology, decision, pattern | `architect` |
| Pencil, .pen, wireframe, mockup, design system, ekran tasarimi | `pencil` |

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
| 3rd party API, entegrasyon, iyzico, banka | `api-researcher` |
| Dokümantasyon, README, API docs | `documentation` |
| Wireframe, mockup, tasarım, UX, design system, Pencil | `ui-ux-designer` |
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
- Railway / Nixpacks
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
| `pencil` | ~/.kuark/skills/pencil/ | Pencil MCP ile UI tasarimi |

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
| API Researcher | ~/.kuark/agents/api-researcher/ | 3rd party APIs |
| Documentation | ~/.kuark/agents/documentation/ | Docs |
| Python Developer | ~/.kuark/agents/python-developer/ | Python services |
| UI/UX Designer | ~/.kuark/agents/ui-ux-designer/ | UI/UX design & wireframe |

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
| Deployment Checklist | ~/.kuark/references/deployment-checklist.md | Railway + Docker deploy guide |
| Monorepo Structure | ~/.kuark/references/monorepo-structure.md | pnpm + Turborepo setup |
| Agent Handoff Protocol | ~/.kuark/references/agent-handoff-protocol.md | Agent-to-agent transition protocol |
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

## Swarm Management

### Initialize Swarm
```bash
bash ~/.kuark/hooks/swarm.sh init "project-name"    # Create .swarm/
bash ~/.kuark/hooks/swarm.sh status                  # Check status
```

### Task Management
```bash
bash ~/.kuark/hooks/swarm.sh task create "Title" "agent" "priority" "US-XXX"
bash ~/.kuark/hooks/swarm.sh task update TASK-001 in-progress
bash ~/.kuark/hooks/swarm.sh task list
```

### Sprint Management
```bash
bash ~/.kuark/hooks/swarm.sh sprint start "Sprint 1" "Goal"
bash ~/.kuark/hooks/swarm.sh sprint status
bash ~/.kuark/hooks/swarm.sh sprint end
```

### Agent Handoff
```bash
bash ~/.kuark/hooks/swarm.sh handoff from-agent to-agent TASK-XXX "summary"
```

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