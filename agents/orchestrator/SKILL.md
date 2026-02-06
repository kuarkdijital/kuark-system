# Kuark Swarm Orchestrator

> Central coordination hub for multi-agent development workflow

## Role

The Orchestrator manages the entire Kuark development workflow by:
1. Routing requests to appropriate agents
2. Coordinating inter-agent communication
3. Managing project state in `.swarm/`
4. Ensuring all output follows Kuark conventions

## Agent Hierarchy

```
┌───────────────────────────────────────────────────────────┐
│                      PRODUCT OWNER                        │
│             (Kullanıcı ile iletişim, vizyon)              │
└────────────────────────────┬──────────────────────────────┘
                             │
┌────────────────────────────▼──────────────────────────────┐
│                     PROJECT MANAGER                       │
│              (Task dağıtımı, sprint yönetimi)             │
└────────────────────────────┬──────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────▼────┐   ┌──────────▼──────────┐   ┌───▼───────────────┐
    │ ANALYST │   │  DEVELOPMENT SQUAD  │   │   SUPPORT SQUAD   │
    └─────────┘   │                     │   │                   │
                  │ • Architect         │   │ • QA Engineer     │
                  │ • NestJS Developer  │   │ • Security Eng.   │
                  │ • NextJS Developer  │   │ • DevOps Engineer │
                  │ • DB Engineer       │   │ • API Researcher  │
                  │ • Queue Developer   │   │ • Documentation   │
                  │ • Python Developer  │   │                   │
                  └─────────────────────┘   └───────────────────┘
```

## Agent Routing

### Request → Agent Mapping

| Request Type | Primary Agent | Support Agents |
|--------------|---------------|----------------|
| New project | product-owner | analyst |
| Requirements | analyst | product-owner |
| Sprint planning | project-manager | product-owner |
| Architecture design | architect | nestjs-developer |
| NestJS module | nestjs-developer | database-engineer |
| Next.js page | nextjs-developer | - |
| Database schema | database-engineer | architect |
| Background job | queue-developer | nestjs-developer |
| API integration | api-researcher | nestjs-developer |
| Tests | qa-engineer | relevant developer |
| Security audit | security-engineer | - |
| Deployment | devops-engineer | - |
| Documentation | documentation | - |
| Python service | python-developer | architect |

### Keyword → Agent Routing

```
"proje başlat", "vizyon", "backlog"     → product-owner
"sprint", "task", "dağıt"               → project-manager
"gereksinim", "user story", "analiz"    → analyst
"mimari", "teknoloji", "ADR"            → architect
"NestJS", "module", "controller"        → nestjs-developer
"Next.js", "page", "component"          → nextjs-developer
"Prisma", "schema", "migration"         → database-engineer
"BullMQ", "processor", "job"            → queue-developer
"test", "coverage", "QA"                → qa-engineer
"güvenlik", "auth", "RBAC"              → security-engineer
"Docker", "deploy", "CI/CD"             → devops-engineer
"API araştır", "entegrasyon"            → api-researcher
"dokümantasyon", "README"               → documentation
"FastAPI", "Python", "microservice"     → python-developer
```

## Workflow Orchestration

### New Project Flow
```
1. product-owner     → Gather requirements from user
2. analyst           → Write user stories
3. project-manager   → Create sprint plan
4. architect         → Design system architecture
5. database-engineer → Create database schema
6. nestjs-developer  → Build backend modules
7. nextjs-developer  → Build frontend
8. qa-engineer       → Write and run tests
9. security-engineer → Security audit
10. devops-engineer  → Setup deployment
11. documentation    → Write docs
12. product-owner    → Present to user
```

### Feature Development Flow
```
1. analyst           → Refine requirements
2. project-manager   → Assign tasks
3. architect         → Review design (if needed)
4. developer         → Implement feature
5. qa-engineer       → Test feature
6. security-engineer → Security check (if needed)
7. project-manager   → Mark complete
```

## State Management

### .swarm/ Initialization
```bash
# Yeni proje icin .swarm/ olustur
bash hooks/swarm.sh init "proje-adi" "monorepo"

# Mevcut durumu kontrol et
bash hooks/swarm.sh status
```

### .swarm/ Directory Structure
```
.swarm/
├── project.json           # Project metadata + counters
├── backlog.json           # Product backlog items
├── current-sprint.json    # Active sprint state
├── sprints/               # Sprint history (archived)
│   ├── Sprint-1.json
│   └── Sprint-2.json
├── tasks/                 # Task files (TASK-XXX.task.md)
│   ├── TASK-001.task.md
│   └── TASK-002.task.md
├── handoffs/              # Agent handoff logs
│   ├── 2024-01-15.json
│   └── outputs/           # Agent output files
├── communications/        # Inter-agent message logs
│   └── 2024-01-15.json
└── context/               # Runtime context
    ├── active-agent.json  # Current/previous agent tracking
    └── decisions.json     # ADR references
```

### Swarm CLI Komutlari
```bash
# Proje yonetimi
bash hooks/swarm.sh init "proje-adi"     # .swarm/ olustur
bash hooks/swarm.sh status               # Genel durum
bash hooks/swarm.sh reset "proje-adi"    # Sifirla

# Task yonetimi
bash hooks/swarm.sh task create "Baslik" "nestjs-developer" "high" "US-001"
bash hooks/swarm.sh task update TASK-001 in-progress
bash hooks/swarm.sh task update TASK-001 review
bash hooks/swarm.sh task update TASK-001 done
bash hooks/swarm.sh task list

# Sprint yonetimi
bash hooks/swarm.sh sprint start "Sprint 1" "MVP hedefi"
bash hooks/swarm.sh sprint status
bash hooks/swarm.sh sprint end

# Agent handoff
bash hooks/swarm.sh handoff nestjs-developer qa-engineer TASK-001 "Auth tamamlandi"

# Agent iletisimi (pipe JSON)
echo '{"from":"pm","to":"dev","type":"assignment","content":"..."}' | bash hooks/swarm.sh communicate
```

## Agent Handoff Protocol

> Detayli protokol: `references/agent-handoff-protocol.md`

### Handoff Zinciri

Her agent calismasini bitirdiginde:
1. Task durumunu gunceller (`review`)
2. Handoff loglar (`swarm.sh handoff`)
3. Sonraki agent context'i okuyarak baslar

### Standart Zincirler

**Yeni Ozellik:**
```
product-owner → project-manager → architect → database-engineer
    → nestjs-developer → nextjs-developer → qa-engineer
    → security-engineer → devops-engineer → project-manager → product-owner
```

**Bug Fix:**
```
project-manager → developer → qa-engineer → project-manager
```

**Database Degisikligi:**
```
architect → database-engineer → nestjs-developer → qa-engineer
```

### Context Injection

Her agent basladiginda su kaynaklari okur:
1. **Task dosyasi:** `.swarm/tasks/TASK-XXX.task.md`
2. **Active agent:** `.swarm/context/active-agent.json`
3. **Proje bilgisi:** `.swarm/project.json`
4. **Sprint durumu:** `.swarm/current-sprint.json`
5. **Onceki handoff:** `.swarm/handoffs/` (gunun dosyasi)

## Communication Protocol

### Inter-Agent Message Format
```json
{
  "from": "project-manager",
  "to": "nestjs-developer",
  "task_id": "TASK-001",
  "type": "assignment",
  "priority": "high",
  "content": "Implement authentication module",
  "context": {
    "requirements": "...",
    "dependencies": ["TASK-000"]
  },
  "timestamp": "2024-01-15T10:00:00Z"
}
```

### Message Types
- `assignment`: New task assigned
- `question`: Clarification needed
- `review`: Request review
- `completion`: Task completed
- `blocker`: Blocked by issue
- `escalation`: Needs higher authority

### Mesaj Gonderme
```bash
echo '{
  "from": "project-manager",
  "to": "nestjs-developer",
  "type": "assignment",
  "task_id": "TASK-001",
  "content": "Auth modulu implementasyonu"
}' | bash hooks/swarm.sh communicate
```

## Quality Gates

### Code Quality
- [ ] TypeScript strict mode passes
- [ ] ESLint no errors
- [ ] Test coverage >= 80%
- [ ] No TODO/FIXME comments
- [ ] organizationId in all queries

### Architecture Quality
- [ ] ADR for significant decisions
- [ ] Module boundaries respected
- [ ] Dependency injection used
- [ ] Error handling complete

### Security Quality
- [ ] JwtAuthGuard applied
- [ ] organizationId filtered
- [ ] Input validated
- [ ] No secrets in code

### Handoff Quality
- [ ] Task dosyasi guncellendi
- [ ] Handoff log'u yazildi
- [ ] Degistirilen dosyalar listelendi
- [ ] Sonraki agent icin notlar eklendi

## Escalation Path

```
Developer → Project Manager → Architect → Product Owner → User
```

Use escalation when:
- Technical decision affects scope
- Blocker cannot be resolved
- Requirement is unclear
- Timeline at risk

## Rollback Strategy

> Detayli strateji: `references/rollback-strategy.md`

Agent hata yaptiginda:
1. **Git checkpoint** - Her agent baslamadan once commit/stash
2. **Task rollback** - Durum onceki state'e dondurulur
3. **Handoff iptal** - Onceki agent'a geri devredilir
4. **Escalation** - Cozulemezse ust seviyeye ilet
