# Agent Handoff Protocol

> Agent'lar arasi is teslim ve gecis protokolu

## Temel Prensipler

1. **State dosya tabanli** - Her agent ciktisini `.swarm/` altina yazar
2. **Acik gecis** - Hangi agent'tan hangisine gecildigi loglanir
3. **Context aktarimi** - Onceki agent'in ciktisi sonrakinin girdisidir
4. **Dogrulanabilirlik** - Her gecis checklist'e tabidir

---

## Handoff Mekanizmasi

### Adim 1: Agent Calismasini Tamamlar

Agent isi bitirdiginde su adimlari izler:

```bash
# 1. Task durumunu guncelle
bash hooks/swarm.sh task update TASK-001 review

# 2. Handoff'u logla
bash hooks/swarm.sh handoff nestjs-developer qa-engineer TASK-001 "Auth modulu tamamlandi, test bekleniyor"
```

### Adim 2: Cikti Dosyasi Olusturur

Her agent ciktisini `.swarm/handoffs/` altina yazar:

```
.swarm/handoffs/
├── 2024-01-15.json          # Gunluk handoff log'lari
└── outputs/                  # Agent cikti dosyalari
    ├── TASK-001-nestjs.md    # NestJS developer ciktisi
    ├── TASK-001-qa.md        # QA engineer ciktisi
    └── TASK-002-architect.md # Architect ciktisi
```

### Adim 3: Sonraki Agent Baslangic Kontrolleri

Yeni agent baslamadan once:

1. `.swarm/context/active-agent.json` kontrol edilir
2. Ilgili task dosyasi okunur
3. Onceki agent'in handoff ciktisi okunur
4. Kabul kriterleri dogrulanir

---

## Agent Cikti Formatlari

### Product Owner -> Project Manager

```json
{
  "handoff_type": "requirements_to_planning",
  "from": "product-owner",
  "to": "project-manager",
  "deliverables": {
    "project_json": ".swarm/project.json",
    "backlog": ".swarm/backlog.json",
    "user_stories": ["US-001", "US-002", "US-003"]
  },
  "notes": "MVP kapsaminda 3 user story belirlendi. Must-have oncelikli.",
  "next_action": "Sprint planlamasi ve task dagilimi"
}
```

### Project Manager -> Developer

```json
{
  "handoff_type": "task_assignment",
  "from": "project-manager",
  "to": "nestjs-developer",
  "deliverables": {
    "task_file": ".swarm/tasks/TASK-001.task.md",
    "sprint": "Sprint 1",
    "dependencies": []
  },
  "context": {
    "user_story": "US-001",
    "acceptance_criteria": ["..."],
    "technical_notes": "Multi-tenant, BullMQ entegrasyonu gerekli"
  },
  "next_action": "Modul implementasyonu"
}
```

### Architect -> UI/UX Designer

```json
{
  "handoff_type": "architecture_to_design",
  "from": "architect",
  "to": "ui-ux-designer",
  "deliverables": {
    "decisions": ".swarm/context/decisions.json",
    "screens_needed": ["Dashboard", "Feature List", "Feature Form", "Settings"],
    "data_models": ["Feature", "User", "Organization"],
    "user_stories": ["US-001", "US-002"]
  },
  "context": {
    "apps": ["web", "admin"],
    "multi_tenant": true,
    "permissions": ["FEATURE_READ", "FEATURE_CREATE"]
  },
  "next_action": "Wireframe ve design system olusturma"
}
```

### UI/UX Designer -> NextJS Developer

```json
{
  "handoff_type": "design_to_frontend",
  "from": "ui-ux-designer",
  "to": "nextjs-developer",
  "deliverables": {
    "design_files": ["designs/feature.pen"],
    "design_system": {
      "colors": "Renk token tanimlari",
      "typography": "Font ayarlari",
      "spacing": "Spacing scale"
    },
    "screens": [
      {
        "name": "Dashboard",
        "components": ["Sidebar", "KPICard", "DataTable"],
        "states": ["loading", "error", "empty", "success"],
        "responsive": ["mobile", "tablet", "desktop"]
      }
    ],
    "component_specs": ".swarm/handoffs/outputs/TASK-XXX-design.md"
  },
  "next_action": "Frontend component implementasyonu"
}
```

### Developer -> QA Engineer

```json
{
  "handoff_type": "implementation_to_testing",
  "from": "nestjs-developer",
  "to": "qa-engineer",
  "deliverables": {
    "task_file": ".swarm/tasks/TASK-001.task.md",
    "files_changed": [
      "apps/api/src/modules/auth/auth.module.ts",
      "apps/api/src/modules/auth/auth.controller.ts",
      "apps/api/src/modules/auth/auth.service.ts"
    ],
    "api_endpoints": [
      "POST /api/auth/login",
      "POST /api/auth/register",
      "GET /api/auth/me"
    ]
  },
  "verification": {
    "typescript_passes": true,
    "guards_applied": true,
    "organization_id_filtered": true,
    "dto_validated": true
  },
  "next_action": "Unit ve integration test yazimi"
}
```

### QA Engineer -> Security Engineer

```json
{
  "handoff_type": "testing_to_security",
  "from": "qa-engineer",
  "to": "security-engineer",
  "deliverables": {
    "task_file": ".swarm/tasks/TASK-001.task.md",
    "test_results": {
      "unit_tests": "15/15 passed",
      "integration_tests": "8/8 passed",
      "coverage": "87%"
    }
  },
  "next_action": "Guvenlik taramasi ve audit"
}
```

### Security Engineer -> DevOps Engineer

```json
{
  "handoff_type": "security_to_deployment",
  "from": "security-engineer",
  "to": "devops-engineer",
  "deliverables": {
    "security_report": {
      "status": "approved",
      "findings": [],
      "owasp_checklist": "passed"
    }
  },
  "next_action": "Production deployment hazirligi"
}
```

### DevOps -> Project Manager (Completion)

```json
{
  "handoff_type": "deployment_to_completion",
  "from": "devops-engineer",
  "to": "project-manager",
  "deliverables": {
    "deployment": {
      "status": "deployed",
      "environment": "staging",
      "url": "https://staging.example.com"
    }
  },
  "next_action": "Task'i done olarak isaretle"
}
```

---

## Standart Handoff Zincirleri

### Yeni Ozellik (Feature) Zinciri

```
product-owner ──→ project-manager ──→ architect ──→ database-engineer
                                                         │
                                                         ▼
                                                    nestjs-developer
                                                         │
                                                         ▼
                                                    ui-ux-designer
                                                         │
                                                         ▼
devops-engineer ←── security-engineer ←── qa-engineer ←── nextjs-developer
      │
      ▼
project-manager ←── product-owner (demo/report)
```

### Bug Fix Zinciri

```
project-manager ──→ developer ──→ qa-engineer ──→ project-manager
```

### UI Odakli Ozellik Zinciri

```
architect ──→ ui-ux-designer ──→ nextjs-developer ──→ qa-engineer
```

### Database Degisikligi Zinciri

```
architect ──→ database-engineer ──→ nestjs-developer ──→ qa-engineer
```

### API Entegrasyonu Zinciri

```
api-researcher ──→ architect ──→ nestjs-developer ──→ qa-engineer
```

---

## Context Injection Mekanizmasi

Agent basladiginda context'i su kaynaklardan okur:

### 1. Task Dosyasi
```bash
# Agent basladiginda ilgili task'i okur
cat .swarm/tasks/TASK-001.task.md
```

### 2. Onceki Agent Ciktisi
```bash
# Handoff log'undan onceki agent'in ciktisini okur
jq '.handoffs[-1]' .swarm/handoffs/$(date -u +%Y-%m-%d).json
```

### 3. Active Agent Context
```bash
# Kim nereye birakti
cat .swarm/context/active-agent.json
```

### 4. Proje Baglami
```bash
# Genel proje bilgisi
cat .swarm/project.json
cat .swarm/current-sprint.json
```

---

## Handoff Checklist

Her geciste dogrulanmasi gerekenler:

### Giden Agent (Teslim Eden)
- [ ] Task durumu guncellendi (in-progress -> review)
- [ ] Degistirilen dosyalar listelendi
- [ ] Kabul kriterlerinden gecen maddeler isaretlendi
- [ ] Kuark checklist'ten gecen maddeler isaretlendi
- [ ] Handoff log'u yazildi
- [ ] Sonraki agent icin notlar eklendi

### Gelen Agent (Teslim Alan)
- [ ] Task dosyasi okundu
- [ ] Onceki agent'in ciktisi incelendi
- [ ] Bagimliliklar kontrol edildi
- [ ] Kabul kriterleri anlasıldı
- [ ] Task durumu in-progress'e cekildi

---

## Escalation Protokolu

Bir agent blocker ile karsilastiginda:

```
1. Blocker'i task dosyasina yaz
2. Task durumunu "blocked" olarak isaretle
3. Handoff mesaji gonder:

bash hooks/swarm.sh handoff nestjs-developer project-manager TASK-001 "BLOCKER: API rate limit, architect karari gerekli"

4. Escalation zinciri:
   Developer -> Project Manager -> Architect -> Product Owner -> Kullanici
```

---

## Pratik Kullanim Ornegi

```bash
# 1. Product Owner proje baslatir
bash hooks/swarm.sh init "musteri-sadakat" "monorepo"
bash hooks/swarm.sh sprint start "Sprint 1" "MVP: Puan sistemi"

# 2. PM task olusturur
bash hooks/swarm.sh task create "Auth modulu" "nestjs-developer" "high" "US-001"
bash hooks/swarm.sh task create "Puan modeli" "database-engineer" "high" "US-002"
bash hooks/swarm.sh task create "Dashboard" "nextjs-developer" "medium" "US-003"

# 3. NestJS developer baslar
bash hooks/swarm.sh task update TASK-001 in-progress
# ... kod yazar ...
bash hooks/swarm.sh task update TASK-001 review
bash hooks/swarm.sh handoff nestjs-developer qa-engineer TASK-001 "Auth tamamlandi"

# 4. QA engineer devralir
bash hooks/swarm.sh task update TASK-001 in-progress
# ... test yazar ...
bash hooks/swarm.sh task update TASK-001 done
bash hooks/swarm.sh handoff qa-engineer project-manager TASK-001 "Testler gecti, %92 coverage"

# 5. Sprint durumu
bash hooks/swarm.sh sprint status
bash hooks/swarm.sh status
```
