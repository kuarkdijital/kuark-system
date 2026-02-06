# Kuark Universal Development System

Kuark ekibi icin multi-agent development sistemi. Claude Code uzerinden 15 uzman AI agent ile full-stack NestJS + Next.js gelistirme orkestrasyon sistemi.

## Hizli Kurulum

```bash
curl -sSL https://raw.githubusercontent.com/kuarkdijital/kuark-system/main/install.sh | bash
```

Veya manuel:

```bash
git clone https://github.com/kuarkdijital/kuark-system.git ~/.kuark
bash ~/.kuark/install.sh
```

## Ne Yapar?

- **15 uzman agent** ile otomatik orkestrasyon (PO -> PM -> Architect -> Developer zinciri)
- Herhangi bir proje dizininde `.swarm/` otomatik baslatma
- Kuark coding standartlari zorunlu kilma (multi-tenant, RBAC, guards, DTO validation)
- NestJS pattern validasyonu (organizationId, JwtAuthGuard, Swagger)
- Prisma schema kontrolu (organizationId, timestamps, indexes)
- Post-edit Prettier formatlama ve anti-pattern tespiti
- Session bazli ogrenme hafizasi

## Gereksinimler

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- git
- jq (`brew install jq` / `apt-get install jq`)

## Agent Listesi

| Agent | Rol |
|-------|-----|
| `product-owner` | Vizyon, gereksinimler, backlog, onceliklendirme |
| `project-manager` | Sprint planlama, task dagilimi, ilerleme takibi |
| `analyst` | Gereksinim analizi, user story yazimi |
| `architect` | Sistem tasarimi, ADR, teknoloji secimi |
| `nestjs-developer` | Backend API gelistirme |
| `nextjs-developer` | Frontend gelistirme |
| `database-engineer` | Prisma schema, migration, query optimizasyonu |
| `queue-developer` | BullMQ background job'lar |
| `qa-engineer` | Test stratejisi, unit/integration/e2e testler |
| `security-engineer` | Guvenlik audit, RBAC, OWASP |
| `devops-engineer` | Docker, CI/CD, Railway deployment |
| `api-researcher` | 3rd party API entegrasyonlari (iyzico, bankalar) |
| `documentation` | README, Swagger, teknik dokumantasyon |
| `python-developer` | FastAPI microservice'ler |

## Kullanim

### Yeni Proje Baslatma

Claude Code'u herhangi bir proje dizininde baslatin:

```
> proje baslat
```

Product Owner otomatik olarak aktif olur, sorular sorar, user story'ler yazar. Sonra Project Manager'a gecer, sprint planlar ve task'lari dagitir.

### Swarm Durumu

```
> durumu goster
> sprint durumu
> task listesi
```

### Agent Degistirme

```
> agent degistir: nestjs-developer
```

## Dizin Yapisi

```
~/.kuark/
├── agents/          # 15 agent SKILL.md dosyalari
├── hooks/           # Claude Code hook script'leri
├── skills/          # 10 modul MODULE.md dosyalari
├── templates/       # NestJS, NextJS, Prisma, Docker sablonlari
├── references/      # API format, error codes, deployment, caching
├── CLAUDE.md        # Ana direktifler (~/.claude/CLAUDE.md'ye inject edilir)
├── CONVENTIONS.md   # Kodlama standartlari
├── install.sh       # Kurulum
├── update.sh        # Guncelleme
└── uninstall.sh     # Kaldirma
```

### Proje Bazli (.swarm/)

Her projede otomatik olusturulur:

```
.swarm/
├── project.json           # Proje metadata
├── backlog.json           # Product backlog (user stories)
├── current-sprint.json    # Aktif sprint
├── tasks/                 # TASK-XXX.task.md dosyalari
├── sprints/               # Sprint arsivi
├── handoffs/              # Agent handoff log'lari
├── communications/        # Agent-arasi mesajlar
└── context/
    ├── active-agent.json  # Aktif agent takibi
    └── decisions.json     # Mimari kararlar (ADR)
```

## Teknoloji Stack

| Alan | Teknolojiler |
|------|-------------|
| Backend | NestJS 10+, TypeScript strict, Prisma 6, PostgreSQL 16, Redis 7, BullMQ |
| Frontend | Next.js 15 (App Router), React 19, Tailwind CSS, shadcn/ui, Zustand, TanStack Query |
| Altyapi | Docker multi-stage, Railway/Nixpacks, GitHub Actions, pnpm + Turborepo |

## Guncelleme

```bash
bash ~/.kuark/update.sh
```

## Kaldirma

```bash
bash ~/.kuark/uninstall.sh
```

Projelerdeki `.swarm/` dizinleri korunur.

## Hook'lar

Kurulum sonrasi `~/.claude/settings.json`'a eklenen hook'lar:

| Event | Hook | Islem |
|-------|------|-------|
| SessionStart | init.sh | Proje tespiti, .swarm/ baslatma, agent yukleme |
| PreToolUse (Edit/Write) | validate.sh | Hassas dosya kontrolu |
| PostToolUse (Edit/Write) | format.sh | Prettier + anti-pattern kontrolu |
| Stop | memory.sh | Session ogrenmeleri kaydetme |

## Lisans

Kuark Dijital - Internal Use Only
