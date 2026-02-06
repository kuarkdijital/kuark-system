# Rollback Strategy & Agent Error Recovery

> Agent hata yonetimi, geri alma ve kurtarma protokolleri

## Rollback Katmanlari

```
Katman 1: Git Checkpoint (kod degisiklikleri)
Katman 2: Task Rollback (.swarm/ state)
Katman 3: Handoff Iptal (agent zinciri)
Katman 4: Sprint Rollback (toplu geri alma)
```

---

## 1. Git Checkpoint Stratejisi

### Agent Baslamadan Once
Her agent ise baslamadan once bir checkpoint olusturur:

```bash
# Stash veya commit ile checkpoint
git stash push -m "checkpoint:TASK-001:nestjs-developer:before"

# Veya WIP commit
git add -A
git commit -m "wip: checkpoint before TASK-001 [nestjs-developer]"
```

### Agent Hata Yaptiginda

```bash
# Son checkpoint'e don
git stash pop  # stash kullanildiysa

# Veya WIP commit'i geri al
git reset --soft HEAD~1  # son commit'i geri al, degisiklikleri koru

# Veya tamamen geri al
git reset --hard HEAD~1  # son commit'i ve degisiklikleri sil
```

### Checkpoint Convention
```
Commit message formati:
  wip: checkpoint before TASK-XXX [agent-adi]
  wip: checkpoint after TASK-XXX [agent-adi]

Stash message formati:
  checkpoint:TASK-XXX:agent-adi:before
  checkpoint:TASK-XXX:agent-adi:after
```

---

## 2. Task Rollback

### Durum Gecisleri

```
planned → in-progress → review → done
                ↑           │
                └───────────┘  (rework)
                ↑
           blocked
```

### Rollback Adimlari

```bash
# 1. Task'i onceki duruma dondur
bash hooks/swarm.sh task update TASK-001 planned

# 2. Handoff'u logla (geri)
bash hooks/swarm.sh handoff qa-engineer nestjs-developer TASK-001 "Rework gerekli: test basarisiz"

# 3. Blocker kaydet (gerekirse)
bash hooks/swarm.sh task update TASK-001 blocked
```

### Rollback Nedenleri

| Neden | Aksiyon | Kim Yapar |
|-------|---------|-----------|
| Test basarisiz | Task → rework, developer'a geri | QA Engineer |
| Guvenlik acigi | Task → blocked, developer'a geri | Security Engineer |
| Mimari uyumsuzluk | Task → rework, architect review | Architect |
| Gereksinim degisikligi | Task → planned, PO karari beklenir | Project Manager |
| Build hatasi | Task → in-progress, hata duzeltme | Developer |

---

## 3. Handoff Iptal Protokolu

### Normal Handoff Zinciri
```
A (developer) → B (QA) → C (security) → D (devops)
```

### Iptal Senaryolari

**Senaryo 1: QA testleri basarisiz**
```
A → B (FAIL)
B → A (rework mesaji ile geri)
A (duzeltir) → B (tekrar)
```

**Senaryo 2: Security acik buldu**
```
A → B → C (VULN FOUND)
C → A (security fix gerekli)
A (duzeltir) → B → C (tekrar)
```

**Senaryo 3: Deploy basarisiz**
```
A → B → C → D (DEPLOY FAIL)
D → A (ornegin: env config eksik)
```

### Iptal Handoff Formati
```json
{
  "handoff_type": "rollback",
  "from": "qa-engineer",
  "to": "nestjs-developer",
  "reason": "3 test basarisiz: auth token expiry, role check, rate limit",
  "task_id": "TASK-001",
  "severity": "medium",
  "action_required": [
    "token expiry logic'i duzelt",
    "role guard'ina admin role ekle",
    "throttle decorator'u ekle"
  ],
  "files_affected": [
    "src/modules/auth/auth.service.ts",
    "src/modules/auth/guards/role.guard.ts"
  ]
}
```

---

## 4. Sprint Rollback

Sprint seviyesinde geri alma gerektiginde:

### Eskalasyon Matrisi

| Durum | Karar Verici | Aksiyon |
|-------|-------------|---------|
| Tek task basarisiz | Project Manager | Task rework |
| Birden fazla task basarisiz | Project Manager + Architect | Sprint re-plan |
| Mimari hata | Architect + Product Owner | Sprint iptal + yeniden tasarim |
| Gereksinim temelden degisti | Product Owner | Sprint iptal + backlog guncelleme |

### Sprint Iptal Adimlari
```bash
# 1. Sprint'i sonlandir
bash hooks/swarm.sh sprint end

# 2. Tamamlanmamis task'lari planned'a cek
for task in .swarm/tasks/*.task.md; do
  if grep -q 'Durum:\*\* in-progress\|Durum:\*\* review' "$task"; then
    TASK_ID=$(basename "$task" .task.md)
    bash hooks/swarm.sh task update "$TASK_ID" planned
  fi
done

# 3. Yeni sprint baslat
bash hooks/swarm.sh sprint start "Sprint N+1" "Duzeltilmis hedef"
```

---

## 5. Database Rollback

### Prisma Migration Geri Alma
```bash
# Son migration'i geri al
npx prisma migrate resolve --rolled-back "migration_name"

# Veya manual SQL ile
npx prisma db execute --file rollback.sql
```

### Guvenli Migration Kurallari
1. Her migration geri alinabilir olmali
2. Veri silme migration'lari backup ile yapilmali
3. Column drop yerine once nullable yap, sonra sil
4. Index degisiklikleri ayri migration'da

---

## 6. Hata Tipleri ve Kurtarma

### Compile Error (TypeScript)
```bash
# Agent: Developer
# Kurtarma: Hatayi duzelt, tsc --noEmit ile dogrula
npx tsc --noEmit
# Basarisizsa: git stash pop ile checkpoint'e don
```

### Runtime Error (Test Failure)
```bash
# Agent: QA Engineer
# Kurtarma: Hatayi raporla, developer'a handoff
bash hooks/swarm.sh handoff qa-engineer nestjs-developer TASK-001 "Test failure: [detay]"
```

### Schema Error (Prisma)
```bash
# Agent: Database Engineer
# Kurtarma: Schema'yi duzelt, validate et
npx prisma validate
# Basarisizsa: migration'i geri al
```

### Security Vulnerability
```bash
# Agent: Security Engineer
# Kurtarma: Severity'ye gore:
#   Critical → Deploy engelle, developer'a acil handoff
#   High → Sprint icinde duzeltme gorevi olustur
#   Medium → Backlog'a ekle
#   Low → Dokumante et
```

### Deploy Failure
```bash
# Agent: DevOps Engineer
# Kurtarma: Onceki basarili deployment'a rollback
# Railway: Previous deployment'a revert
# Docker: Onceki image tag'ine donme
```

---

## 7. Onleme Stratejileri

### Pre-flight Checks
Her agent baslamadan once calistirmali:

```bash
# TypeScript derlemesi
npx tsc --noEmit

# Prisma schema validation
npx prisma validate

# Mevcut testler
npm test -- --bail

# Lint
npx eslint src/ --quiet
```

### Atomic Commits
```bash
# Her mantiksal degisiklik icin ayri commit
git add src/modules/auth/auth.service.ts
git commit -m "feat(auth): add token refresh logic"

git add src/modules/auth/auth.controller.ts
git commit -m "feat(auth): add refresh endpoint"
```

### Branch Strategy
```bash
# Her task icin feature branch
git checkout -b feature/TASK-001-auth-module

# Tamamlaninca PR olustur
# PR review sonrasi merge
```

---

## Ozet: Karar Agaci

```
Agent hata yapti
├── Compile error?
│   └── Developer duzeltir, checkpoint'e donmez
├── Test failure?
│   └── QA → Developer handoff (rework)
├── Security issue?
│   ├── Critical? → Deploy engelle, acil fix
│   └── Non-critical? → Backlog'a ekle
├── Deploy failure?
│   └── Onceki versiyona rollback
├── Mimari hata?
│   └── Architect review, sprint re-plan
└── Gereksinim degisti?
    └── PO karari, sprint iptal olabilir
```
