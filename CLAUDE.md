# Kuark Universal Development System - Core Directives

> Kuark şirketine özel multi-agent development sistemi
> Reference: ./CONVENTIONS.md for detailed standards

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
| Deploy, Docker, Railway | `devops-engineer` |
| 3rd party API, entegrasyon, iyzico, banka | `api-researcher` |
| Dokümantasyon, README, API docs | `documentation` |
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
| `nestjs` | skills/nestjs/ | Backend API development |
| `nextjs` | skills/nextjs/ | Frontend development |
| `prisma` | skills/prisma/ | Database design |
| `queue` | skills/queue/ | Background jobs |
| `devops` | skills/devops/ | Infrastructure |
| `security` | skills/security/ | Auth & security |
| `api` | skills/api/ | API design |
| `ui` | skills/ui/ | UI components |
| `python` | skills/python/ | Python microservices |
| `architect` | skills/architect/ | Architecture decisions |

---

## Agent Reference

| Agent | Path | Role |
|-------|------|------|
| Orchestrator | agents/orchestrator/SKILL.md | Coordination |
| Product Owner | agents/product-owner/ | Vision & backlog |
| Project Manager | agents/project-manager/ | Sprints & tasks |
| Analyst | agents/analyst/ | Requirements |
| Architect | agents/architect/ | Architecture |
| NestJS Developer | agents/nestjs-developer/ | Backend |
| NextJS Developer | agents/nextjs-developer/ | Frontend |
| Database Engineer | agents/database-engineer/ | Database |
| Queue Developer | agents/queue-developer/ | Background jobs |
| QA Engineer | agents/qa-engineer/ | Testing |
| Security Engineer | agents/security-engineer/ | Security |
| DevOps Engineer | agents/devops-engineer/ | Deployment |
| API Researcher | agents/api-researcher/ | 3rd party APIs |
| Documentation | agents/documentation/ | Docs |
| Python Developer | agents/python-developer/ | Python services |

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
| API Response Format | references/api-response-format.md | Standard API response structure |
| Error Codes | references/error-codes.md | HTTP status codes, error handling |
| Deployment Checklist | references/deployment-checklist.md | Railway + Docker deploy guide |
| Monorepo Structure | references/monorepo-structure.md | pnpm + Turborepo setup |
| Agent Handoff Protocol | references/agent-handoff-protocol.md | Agent-to-agent transition protocol |
| Caching Strategy | references/caching-strategy.md | Redis cache patterns, invalidation |
| Monitoring & Observability | references/monitoring-observability.md | Logging, metrics, health checks |
| Rollback Strategy | references/rollback-strategy.md | Error recovery, git checkpoints |

---

## Template Reference

| Template | Path | Use Case |
|----------|------|----------|
| NestJS Module | templates/nestjs-module/ | Full CRUD module scaffold |
| Next.js Page | templates/nextjs-page/ | App Router page + components |
| Prisma Model | templates/prisma-model/ | Multi-tenant schema template |
| BullMQ Processor | templates/bullmq-processor/ | Background job processor |
| Docker | templates/docker/ | Dockerfile + compose |
| Task | templates/task/ | Task, sprint, backlog templates |
| Test | templates/test/ | Unit, controller, E2E test templates |

---

## Swarm Management

### Initialize Swarm
```bash
bash hooks/swarm.sh init "project-name"    # Create .swarm/
bash hooks/swarm.sh status                  # Check status
```

### Task Management
```bash
bash hooks/swarm.sh task create "Title" "agent" "priority" "US-XXX"
bash hooks/swarm.sh task update TASK-001 in-progress
bash hooks/swarm.sh task list
```

### Sprint Management
```bash
bash hooks/swarm.sh sprint start "Sprint 1" "Goal"
bash hooks/swarm.sh sprint status
bash hooks/swarm.sh sprint end
```

### Agent Handoff
```bash
bash hooks/swarm.sh handoff from-agent to-agent TASK-XXX "summary"
```

> Full protocol: `references/agent-handoff-protocol.md`

---

## Session Memory

Capture discoveries during work:

```bash
echo '{"category":"discovery","content":"Description"}' | bash ./hooks/memory.sh
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
