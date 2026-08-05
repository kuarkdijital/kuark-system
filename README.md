# Kuark Universal Development System

Kuark ekibi için **Cursor · Claude Code · Codex** üzerinde çalışan multi-agent development sistemi.
**v2:** parallel sub-agent + append-only ledger. 17 uzman agent, structured handoff, `kuark` CLI.

## Platformlar (eşit)

| Platform | Direktif | Dispatch | Skills / Agents |
|----------|----------|----------|-----------------|
| **Cursor** | `~/AGENTS.md` + `~/.cursor/rules/kuark.mdc` | `Task(subagent_type="kuark-…")` | `~/.cursor/skills/kuark-*/` |
| **Claude Code** | `~/.claude/CLAUDE.md` | `Agent(subagent_type="kuark-…")` | `~/.claude/agents/kuark-*.md` |
| **Codex** | `~/AGENTS.md` | native / aynı sözleşme | `~/.kuark/agents/*/SKILL.md` |

## Mimari (v2)

- **17 sub-agent** — `kuark-<name>` sözleşmesi her platformda aynı
- **Append-only ledger** (`.swarm/ledger.jsonl`) — tek writer: orchestrator (`kuark` CLI)
- **Auto-rendered views** — `tasks.md`, `dashboard.md`, `by-agent.md`, `timeline.md`
- **Slash commands** (Claude): `/kuark-proje-baslat`, `/kuark-tasks`, `/kuark-handoff`, `/kuark-dispatch`, `/kuark-agent`, `/kuark-durum`
- Resmi self-hosted PaaS: **Hadron** (`kuark-hadron-engineer`). Coolify = legacy.

## Model mapping (Cursor / Grok)

| Tier | Model slug | Agents |
|------|------------|--------|
| **high** | `cursor-grok-4.5-high-fast` | architect, nestjs/nextjs/database/queue/python, qa, security, devops, hadron, ui-ux |
| **fast** | `composer-2.5-fast` | product-owner, project-manager, analyst, api-researcher, documentation, orchestrator |

Claude Code frontmatter: kod/ADR → `opus`, planlama → `sonnet`.

## Hızlı kurulum

```bash
# Yerel checkout (önerilen — unpushed değişiklikler dahil)
bash /path/to/kuark-system/install.sh

# veya GitHub
curl -sSL https://raw.githubusercontent.com/kuarkdijital/kuark-system/main/install.sh | bash
```

Güncelleme:

```bash
bash ~/.kuark/update.sh
# veya checkout'tan: bash install.sh
```

## Gereksinimler

- git, jq
- Cursor ve/veya [Claude Code CLI](https://docs.anthropic.com/en/claude-code) ve/veya Codex
- Hadron işleri için: **hadron-mcp** MCP server

## Sub-agent listesi

| Agent | Cursor model | Claude model | Rol |
|-------|--------------|--------------|-----|
| `kuark-product-owner` | fast | sonnet | Vizyon, backlog, wizard |
| `kuark-project-manager` | fast | sonnet | Sprint, task |
| `kuark-analyst` | fast | sonnet | User story, AC |
| `kuark-architect` | **high** | **opus** | ADR, tech |
| `kuark-nestjs-developer` | **high** | **opus** | Backend |
| `kuark-nextjs-developer` | **high** | **opus** | Frontend |
| `kuark-database-engineer` | **high** | **opus** | Prisma |
| `kuark-queue-developer` | **high** | **opus** | BullMQ |
| `kuark-python-developer` | **high** | **opus** | FastAPI |
| `kuark-qa-engineer` | **high** | **opus** | Test |
| `kuark-security-engineer` | **high** | **opus** | Security |
| `kuark-devops-engineer` | **high** | **opus** | Docker/CI |
| `kuark-hadron-engineer` | **high** | sonnet | Hadron PaaS |
| `kuark-ui-ux-designer` | **high** | **opus** | UI + frontend-design |
| `kuark-api-researcher` | fast | sonnet | 3rd party API |
| `kuark-documentation` | fast | sonnet | Docs |
| `kuark-orchestrator` | fast | sonnet | Koordinasyon |

## Kullanım

### Yeni proje

```
proje baslat
# veya Claude: /kuark-proje-baslat
```

Orchestrator sırasıyla PO → PM → Architect dispatch eder; ardından bağımsız task'lar paralel gider.

### Cursor örnek

```
Task(subagent_type="kuark-database-engineer", model="cursor-grok-4.5-high-fast", prompt="TASK-001: ...")
Task(subagent_type="kuark-api-researcher", model="composer-2.5-fast", prompt="TASK-002: ...")
```

### CLI

```bash
kuark init "proje-adi"
kuark story add "Login" must_have S
kuark sprint start "Sprint 1" "MVP auth"
kuark task create "Build API" nestjs-developer high US-001
kuark task update TASK-001 in-progress
kuark handoff architect nestjs-developer --task TASK-002 --summary "ADR done"
kuark decide "ORM" "Prisma" "Multi-tenant"
kuark status
```

### Kullanıcı girdisi

Yapılandırılmış seçenek zorunlu — bkz. `references/user-input-protocol.md`
(Claude: `AskUserQuestion`; Cursor/Codex: `1)` `2)` `3)` `Other)`).

## Dizin yapısı

```
~/.kuark/                 # kaynak
├── kuark                 # CLI
├── AGENTS.md / CLAUDE.md # platform direktifleri
├── agents/*/SKILL.md
├── bin/generate-claude-agents.sh
├── bin/generate-cursor-agents.sh
├── commands/             # Claude slash commands
├── skills/               # nestjs, nextjs, hadron, …
├── templates/cursor/kuark.mdc
└── references/

~/.claude/agents/kuark-*.md
~/.cursor/skills/kuark-*/
~/.cursor/rules/kuark.mdc
~/AGENTS.md               # Cursor + Codex inject
```

### Proje `.swarm/`

```
.swarm/
├── ledger.jsonl          # source of truth
├── state.json
├── views/{tasks,dashboard,by-agent,timeline}.md
├── handoffs/
└── decisions/
```

## Stack

| Alan | Teknoloji |
|------|-----------|
| Backend | NestJS 10+, Prisma, PostgreSQL 16, Redis, BullMQ |
| Frontend | Next.js 15 App Router, Tailwind, shadcn/ui |
| Deploy | **Hadron**, Docker, Railway/Nixpacks, GitHub Actions |

## Kaldırma

```bash
bash ~/.kuark/uninstall.sh
```

`.swarm/` proje dizinlerinde korunur.

## Lisans

Kuark Dijital — Internal Use Only
