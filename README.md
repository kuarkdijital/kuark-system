# Kuark Universal Development System

Kuark ekibi icin Claude Code uzerinde **parallel sub-agent + append-only ledger** mimarisiyle calisan multi-agent development sistemi. 17 uzman AI sub-agent, structured handoff'lar, otomatik dashboard.

## Mimari (v2 — Sub-Agent + Ledger)

- **17 sub-agent** Claude Code native formatinda (`~/.claude/agents/kuark-*.md`). Her biri kendi izole context'inde, paralel calisabilir.
- **Append-only ledger** (`.swarm/ledger.jsonl`) tek hakikat kaynagi. Race condition yok — sadece orchestrator (main Claude) yazar.
- **Auto-rendered views** (`.swarm/views/*.md`) — tasks.md, dashboard.md, by-agent.md, timeline.md her event sonrasi yeniden uretilir.
- **Structured handoff payloads** — agent'lar arasi sifir context kaybi.
- **Slash commands**: `/kuark-proje-baslat`, `/kuark-tasks`, `/kuark-handoff`, `/kuark-dispatch`, `/kuark-agent`, `/kuark-durum`.
- **`kuark` CLI** — ledger yazimi, state derivation, view rendering tek binary'de.

## Hizli Kurulum

```bash
curl -sSL https://raw.githubusercontent.com/kuarkdijital/kuark-system/main/install.sh | bash
```

Veya manuel:

```bash
git clone https://github.com/kuarkdijital/kuark-system.git ~/.kuark
bash ~/.kuark/install.sh
```
Manuel Update:
```bash
cd ~/.kuark && git pull origin main
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

## Sub-Agent Listesi

Claude Code'da `Agent(subagent_type="kuark-<name>", prompt="...")` ile cagrilir.

| Agent | Model | Rol |
|-------|-------|-----|
| `kuark-product-owner` | sonnet | Vizyon, gereksinimler, backlog, wizard |
| `kuark-project-manager` | sonnet | Sprint planlama, task dagilimi, kapasite |
| `kuark-analyst` | sonnet | User story analizi, kabul kriterleri |
| `kuark-architect` | **opus** | Sistem tasarimi, ADR, teknoloji secimi |
| `kuark-nestjs-developer` | **opus** | Backend API: controller, service, guard, DTO |
| `kuark-nextjs-developer` | **opus** | Frontend: App Router, RSC, components |
| `kuark-database-engineer` | **opus** | Prisma schema, migration, multi-tenant |
| `kuark-queue-developer` | **opus** | BullMQ processor, background jobs |
| `kuark-python-developer` | **opus** | FastAPI mikroservis |
| `kuark-qa-engineer` | **opus** | Unit/integration/E2E testler |
| `kuark-security-engineer` | **opus** | Guvenlik audit, RBAC, OWASP |
| `kuark-devops-engineer` | **opus** | Docker, CI/CD, Railway/Hadron deploy |
| `kuark-hadron-engineer` | sonnet | Hadron (Dokploy fork) self-hosted PaaS |
| `kuark-ui-ux-designer` | sonnet | Wireframe, mockup, design system (Pencil MCP) |
| `kuark-api-researcher` | sonnet | 3rd party API arastirma (iyzico, bankalar) |
| `kuark-documentation` | sonnet | README, API docs, teknik dokumantasyon |
| `kuark-orchestrator` | sonnet | Multi-agent koordinasyon (genelde main Claude bu rolu yapar) |

**Model atamasi:** kod yazan + yuksek bahisli karar veren ajanlar `opus`, planlama/koordinasyon/arastirma `sonnet`. Hicbir ajan `haiku` degil.

## Kullanim

### Yeni Proje Baslatma

Herhangi bir proje dizininde Claude Code'da:

```
/kuark-proje-baslat
```

Orchestrator (main Claude) sirasiyla **kuark-product-owner**, **kuark-project-manager**, **kuark-architect** sub-agent'larini dispatch eder. Ardindan bagimsiz task'lar paralel sub-agent dispatch ile baslar.

### Durum & Task Takibi

```
/kuark-durum                              # Genel durum + son aktivite
/kuark-tasks                              # Tum task tablosu
/kuark-tasks --status in-progress         # Filtreli
/kuark-tasks --agent nextjs-developer

cat .swarm/views/dashboard.md             # Tam dashboard
cat .swarm/views/tasks.md                 # Task'lar grupli
cat .swarm/views/by-agent.md              # Ajan basina dagilim
cat .swarm/views/timeline.md              # Kronolojik aktivite
```

`.swarm/views/tasks.md`'i editor'de acik tutarsaniz canli dashboard gibi calisir — her `kuark` komutu sonrasi yeniden render edilir.

### Manuel Handoff & Dispatch

```
/kuark-handoff <to-agent> [TASK-ID]       # Aktif ajandan handoff
/kuark-dispatch TASK-001 TASK-002         # Birden fazla task'i paralel dispatch
/kuark-agent <name>                       # Aktif ajani degistir
```

### CLI Dogrudan Kullanim

```bash
kuark init "proje-adi"
kuark story add "Login flow" must_have S
kuark sprint start "Sprint 1" "MVP auth"
kuark task create "Build API" nestjs-developer high US-001
kuark task update TASK-001 in-progress
kuark task update TASK-001 done
kuark handoff architect nestjs-developer --task TASK-002 --summary "ADR-003 done"
kuark decide "ORM" "Prisma" "Multi-tenant + DX"
kuark status
kuark log --tail 20
```

## Dizin Yapisi

```
~/.kuark/                              # Kuark kaynak (clone edilen repo)
├── kuark                              # Ana CLI (sembol link ~/.local/bin/kuark)
├── lib/                               # CLI modulleri (ledger, state, views, ...)
├── bin/                               # Yardimcilar (generate-claude-agents.sh, ...)
├── commands/                          # Slash command tanimlari
├── agents/<name>/SKILL.md             # Sub-agent domain bilgisi (kaynak)
├── hooks/                             # Claude Code hook'lari + swarm.sh shim
├── skills/                            # 13 modul MODULE.md dosyalari
├── templates/                         # NestJS, NextJS, Prisma, Docker sablonlari
├── references/                        # API format, error codes, deployment, ...
├── CLAUDE.md                          # Ana direktifler (~/.claude/CLAUDE.md'ye inject)
├── CONVENTIONS.md                     # Kodlama standartlari
└── install.sh / update.sh / uninstall.sh

~/.claude/                             # Claude Code kullanici dizini
├── agents/kuark-*.md                  # 17 sub-agent (install.sh tarafindan uretilir)
├── commands/kuark-*.md                # Slash command'lar
└── CLAUDE.md                          # Kuark direktifleri buraya inject edilir
```

### Proje Bazli (`.swarm/`)

`kuark init` ile her projede olusturulur:

```
.swarm/
├── ledger.jsonl                       # Kalp — append-only event log (source of truth)
├── state.json                         # Cache — ledger'dan turetilen current state
├── views/
│   ├── tasks.md                       # Tum task'lar (status'a gore grupli)
│   ├── dashboard.md                   # Proje genel bakis
│   ├── by-agent.md                    # Ajan basina dagilim
│   └── timeline.md                    # Son 50 event kronolojik
├── handoffs/HOFF-*.md                 # Structured handoff payload'lari
└── decisions/DEC-*.md                 # Mimari kararlar (ADR'ler)
```

`state.json` ve `views/*.md` her `kuark` komutu sonrasi yeniden uretilir — manuel duzenleme. `ledger.jsonl` append-only, sadece son care olarak duzenle (sonra `kuark replay`).

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
