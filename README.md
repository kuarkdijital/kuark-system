# Kuark Swarm - Kullanim Kilavuzu

> Yazilim ekibi icin multi-agent gelistirme sistemi kullanim rehberi

---

## Icindekiler

1. [Kuark Swarm Nedir?](#1-kuark-swarm-nedir)
2. [Kurulum](#2-kurulum)
3. [Senaryo 1: Sifirdan Yeni Proje Baslatma](#3-senaryo-1-sifirdan-yeni-proje-baslatma)
4. [Senaryo 2: Mevcut Projeye Swarm Ekleme](#4-senaryo-2-mevcut-projeye-swarm-ekleme)
5. [Senaryo 3: Mevcut Swarm Projesine Yeni Oturum Baslatma](#5-senaryo-3-mevcut-swarm-projesine-yeni-oturum-baslatma)
6. [Senaryo 4: Yeni Ozellik Gelistirme](#6-senaryo-4-yeni-ozellik-gelistirme)
7. [Senaryo 5: Bug Fix](#7-senaryo-5-bug-fix)
8. [Senaryo 6: Database Degisikligi](#8-senaryo-6-database-degisikligi)
9. [Senaryo 7: 3rd Party API Entegrasyonu](#9-senaryo-7-3rd-party-api-entegrasyonu)
10. [Senaryo 8: Sprint Bitirme ve Yeni Sprint](#10-senaryo-8-sprint-bitirme-ve-yeni-sprint)
11. [Senaryo 9: Bir Sey Ters Giderse (Rollback)](#11-senaryo-9-bir-sey-ters-giderse-rollback)
12. [Agent Rehberi - Kimden Ne Istenir?](#12-agent-rehberi---kimden-ne-istenir)
13. [Komut Referansi](#13-komut-referansi)
14. [Yapilmasi ve Yapilmamasi Gerekenler](#14-yapilmasi-ve-yapilmamasi-gerekenler)
15. [Sik Sorulan Sorular](#15-sik-sorulan-sorular)

---

## 1. Kuark Swarm Nedir?

Kuark Swarm, Claude Code CLI uzerinde calisan multi-agent gelistirme sistemidir. 15 uzman agent'i koordine ederek yazilim projelerinizi Kuark standartlarinda uretir.

### Nasil Calisir?

```
Sen (kullanici)
 │
 ▼
Claude Code CLI  ←──  kuark-system/ (config, hooks, agents, skills)
 │
 ├── product-owner agent     → Gereksinimleri toplar
 ├── project-manager agent   → Task'lari dagitir
 ├── architect agent         → Mimariyi tasarlar
 ├── nestjs-developer agent  → Backend yazar
 ├── nextjs-developer agent  → Frontend yazar
 ├── database-engineer agent → Schema tasarlar
 ├── qa-engineer agent       → Test yazar
 ├── security-engineer agent → Guvenlik denetler
 ├── devops-engineer agent   → Deploy hazirlar
 └── ... (toplam 15 agent)
```

### Ne Ise Yarar?

- Her agent kendi alaninin uzmani gibi davranir
- Kuark standartlari otomatik olarak uygulanir (organizationId, guards, DTO validation)
- Hook'lar her dosya yazildiginda pattern kontrolu yapar
- `.swarm/` dizini proje state'ini takip eder

### Otomatik Calisan Kontroller

Claude Code ile calisirken arka planda surekli calisan hook'lar:

| Hook | Ne Zaman | Ne Yapar |
|------|----------|----------|
| `init.sh` | Oturum baslangici | Proje tipini tespit eder, swarm durumunu gosterir |
| `memory.sh` | Oturum bas/son | Oturum ogrenimlerini kaydeder/yukler |
| `swarm.sh` | Oturum baslangici | Swarm durumunu gosterir |
| `validate.sh` | Dosya yazilmadan | Hassas dosya uyarilari (.env, secrets) |
| `prisma-validate.sh` | Dosya yazilmadan | Prisma schema kurallari kontrolu |
| `nestjs-pattern-check.sh` | Dosya yazilmadan | Guard, organizationId, DTO kontrolu |
| `format.sh` | Dosya yazildiktan sonra | Prettier, TODO/FIXME, any kontrolu |
| `commit-check.sh` | Commit oncesi | TypeScript, test, secret taramasi |

---

## 2. Kurulum

### On Kosullar

- Claude Code CLI kurulu olmali
- `jq` yuklu olmali (`brew install jq`)
- Git yuklu olmali

### Adimlar

```bash
# 1. kuark-system reposunu indir
git clone <kuark-system-repo-url> ~/kuark-system

# 2. Hook'lari calistirilabilir yap
chmod +x ~/kuark-system/hooks/*.sh

# 3. Claude Code global config'e bagla
# ~/.claude/CLAUDE.md dosyasina kuark-system icerigi zaten yuklu
```

### Hook Yapisi (Onemli!)

Hook'lar `~/.claude/settings.json` dosyasinda tanimlanir. Bu dosya Claude Code'un **resmi** ayar dosyasidir.

**Dikkat:** Hook'lar proje kokundeki `config.json`'da degil, `settings.json`'da olmalidir!

Claude Code 3 katmanli settings okur:

| Dosya | Kapsam | Git'e Eklenir? |
|-------|--------|----------------|
| `~/.claude/settings.json` | Global (tum projeler) | Hayir |
| `.claude/settings.json` | Proje (takim) | Evet |
| `.claude/settings.local.json` | Proje (kisisel) | Hayir |

Hook'lar `$CLAUDE_PROJECT_DIR` degiskeni ile calisir. Bu degisken Claude Code tarafindan
otomatik olarak mevcut proje dizinine isaret eder. Projedeki `hooks/` dizini yoksa
`test -f` kontrolu sayesinde sessizce atlanir, hata vermez.

### Otomatik Hook Listesi

| Event | Hook | Ne Yapar |
|-------|------|----------|
| **SessionStart** | `init.sh` | Proje tipi, git durumu, swarm bilgisi gosterir |
| **SessionStart** | `memory.sh` | Onceki oturum ogrenimlerini yukler |
| **SessionStart** | `swarm.sh status` | Swarm durumunu gosterir |
| **PreToolUse** (Edit/Write) | `validate.sh` | Hassas dosya kontrolu (.env, secrets) |
| **PreToolUse** (Edit/Write) | `prisma-validate.sh` | Prisma schema kurallari |
| **PreToolUse** (Edit/Write) | `nestjs-pattern-check.sh` | Guard, organizationId, DTO kontrolu |
| **PreToolUse** (git commit) | `commit-check.sh` | TypeScript, test, secret taramasi |
| **PreToolUse** (rm -rf) | prompt | Onay sorar |
| **PreToolUse** (force push) | prompt | Onay sorar |
| **PostToolUse** (Edit/Write) | `format.sh` | Prettier, TODO/FIXME, any kontrolu |
| **Stop** | `memory.sh` | Oturum ogrenimlerini kaydeder |

### Dogrulama

Herhangi bir proje dizininde Claude Code'u ac:

```bash
cd ~/projects/my-project
claude
```

Oturum basladiginda su ciktiyi gormelisin:

```
[KUARK] Initializing session...
Project Type: nestjs
Branch: main
[KUARK] No swarm state. Initialize with: bash hooks/swarm.sh init [project-name]
```

---

## 3. Senaryo 1: Sifirdan Yeni Proje Baslatma

> "Sifirdan yeni bir SaaS projesi baslatacagiz"

### Adim 1: Proje Dizinini Olustur

```bash
mkdir ~/projects/musteri-sadakat
cd ~/projects/musteri-sadakat
git init
claude
```

### Adim 2: Product Owner'i Cagir

Claude Code acildiktan sonra:

```
Sen: "proje baslat: Musteri Sadakat Programi"
```

Bu komut `product-owner` agent'ini aktive eder. Agent sana sorular soracak:

```
Product Owner:
  1. Bu proje ne problemi cozuyor?
  2. Hedef kullanici kim?
  3. MVP'de mutlaka ne olmali?
  4. Multi-tenant gerekli mi?
  5. Hangi uygulamalar gerekli? (api, web, admin, worker)
  6. Odeme entegrasyonu gerekli mi?
```

Sorulari yanitla. Product Owner user story'leri yazacak ve Project Manager'a devredecek.

### Adim 3: Swarm'i Baslat

Product Owner gereksinimleri netlestidiginde:

```
Sen: "swarm'i baslat ve Sprint 1'i planla"
```

Arka planda calisacak komutlar:

```bash
bash hooks/swarm.sh init "musteri-sadakat" "monorepo"
bash hooks/swarm.sh sprint start "Sprint 1" "MVP: Temel puan sistemi"
```

### Adim 4: Task'lari Olustur

Project Manager task'lari olusturur:

```bash
bash hooks/swarm.sh task create "Prisma schema tasarimi" "database-engineer" "high" "US-001"
bash hooks/swarm.sh task create "Auth modulu" "nestjs-developer" "high" "US-002"
bash hooks/swarm.sh task create "Puan modulu" "nestjs-developer" "high" "US-003"
bash hooks/swarm.sh task create "Dashboard sayfasi" "nextjs-developer" "medium" "US-004"
```

### Adim 5: Gelistirmeye Basla

Simdi sirayla her agent'i cagirabilirsin:

```
Sen: "database-engineer: TASK-001 puan sistemi icin Prisma schema tasarla"
```

Database engineer calisir, bitirince:

```
Sen: "nestjs-developer: TASK-002 auth modulunu implement et"
```

Her agent calismasini bitirdiginde otomatik olarak:
- Task durumu guncellenir
- Handoff log'u yazilir
- Sonraki agent icin context hazirlanir

### Adim 6: Durumu Kontrol Et

Istedigin zaman:

```
Sen: "swarm durumunu goster"
```

veya direkt:

```bash
bash hooks/swarm.sh status
bash hooks/swarm.sh task list
bash hooks/swarm.sh sprint status
```

---

## 4. Senaryo 2: Mevcut Projeye Swarm Ekleme

> "Calisan bir NestJS projemiz var, swarm ile yonetmeye baslamak istiyoruz"

### Adim 1: Mevcut Projeye Git

```bash
cd ~/projects/crm-kuark-pro
claude
```

Oturum basladiginda proje tipi otomatik tanilanir:

```
[KUARK] Initializing session...
Project Type: nestjs
Kuark Patterns: multi-tenant bullmq prisma jwt-auth
Branch: develop
[KUARK] No swarm state. Initialize with: bash hooks/swarm.sh init [project-name]
```

### Adim 2: Swarm'i Baslat

```
Sen: "bu mevcut projeye swarm ekle"
```

veya direkt:

```bash
bash hooks/swarm.sh init "crm-kuark-pro" "nestjs"
```

Cikti:

```
[SWARM] Initializing swarm for: crm-kuark-pro
[SWARM] Initialized successfully
  ├ project.json
  ├ backlog.json
  ├ current-sprint.json
  ├ tasks/
  ├ sprints/
  ├ communications/
  ├ handoffs/outputs/
  └ context/
```

### Adim 3: Mevcut Durumu Tanimla

```
Sen: "analyst: mevcut projenin yapisini analiz et ve backlog olustur"
```

Analyst mevcut kodu inceleyerek:
- Mevcut modulleri listeler
- Eksik ozellikleri tespit eder
- Backlog onerisi sunar

### Adim 4: Sprint Planla

```
Sen: "project-manager: backlog'dan Sprint 1'i planla"
```

Project Manager:
- Oncelikli task'lari secer
- Agent'lara atar
- Sprint'i baslatir

### Onemli Not

Mevcut projede swarm baslatirken:
- `.swarm/` dizini `.gitignore`'a otomatik eklenir
- Mevcut kod degismez, sadece yonetim katmani eklenir
- Mevcut branch yapiniz korunur
- Hook'lar zaten her dosya yaziminda calisiyor, ekstra bir sey yapmaniza gerek yok

---

## 5. Senaryo 3: Mevcut Swarm Projesine Yeni Oturum Baslatma

> "Dun calistigim proje, bugun yeni bir Claude Code oturumu actim. Ne yapmaliyim?"

### Ne Olur?

Yeni oturum basladiginda `config.json` hook'lari otomatik calisir:

```
[KUARK] Initializing session...
Project Type: nestjs
Kuark Patterns: multi-tenant bullmq prisma jwt-auth
Branch: feature/TASK-003-puan-modulu
[KUARK] Swarm state detected
Project: crm-kuark-pro (active)
Sprint: Sprint 1 (active)
Tasks: 8 total | 2 active | 3 done
Active Agent: nestjs-developer
[KUARK] Previous session learnings loaded
```

### Yapman Gereken: Context'i Yenile

```
Sen: "swarm durumunu kontrol et, nereden kalmistik?"
```

Sistem otomatik olarak:
1. `.swarm/project.json` - Proje bilgisini okur
2. `.swarm/current-sprint.json` - Sprint durumunu okur
3. `.swarm/tasks/` - Acik task'lari listeler
4. `.swarm/context/active-agent.json` - Son calisan agent'i gosterir
5. `.swarm/handoffs/` - Son handoff'lari gosterir

### Ciktisi:

```
[SWARM] Project: crm-kuark-pro (active)
  Sprint: Sprint 1 (active)
  Tasks: 8 total | 2 active | 3 done
  Active Agent: nestjs-developer
  Last Handoff: database-engineer -> nestjs-developer
```

### Devam Et

Kaldgin yerden devam et:

```
Sen: "nestjs-developer: TASK-003 puan modulunu bitir, database-engineer schema'yi tamamlamisti"
```

Agent otomatik olarak:
- Onceki handoff'u okur
- Task dosyasindaki kabul kriterlerini kontrol eder
- Kaldigi yerden devam eder

---

## 6. Senaryo 4: Yeni Ozellik Gelistirme

> "Sprint icinde yeni bir ozellik gelistirmek istiyorum"

### Tam Zincir: Bildirim Modulu Ornegi

```
Sen: "yeni ozellik: push bildirim sistemi ekle"
```

#### Adim 1: Product Owner - Gereksinim

```
PO: "Bildirim sistemi icin su sorularim var:
  1. Hangi kanallar? (email, SMS, push)
  2. Sablonlar olacak mi?
  3. Kullanici tercihleri yonetilebilir mi?"

Sen: "Email ve push. Sablonlar olsun. Kullanici bildirimleri kapatabilsin."

PO: User story'leri yazdi:
  US-010: Bildirim gonderme servisi
  US-011: Bildirim tercihleri yonetimi
  US-012: Email sablon sistemi
```

#### Adim 2: Project Manager - Task Dagitimi

```bash
# PM otomatik olusturur:
bash hooks/swarm.sh task create "Notification Prisma modeli" "database-engineer" "high" "US-010"
bash hooks/swarm.sh task create "Notification NestJS modulu" "nestjs-developer" "high" "US-010"
bash hooks/swarm.sh task create "Notification BullMQ processor" "queue-developer" "high" "US-010"
bash hooks/swarm.sh task create "Bildirim tercihleri API" "nestjs-developer" "medium" "US-011"
bash hooks/swarm.sh task create "Bildirim tercihleri UI" "nextjs-developer" "medium" "US-011"
bash hooks/swarm.sh task create "Email sablon servisi" "nestjs-developer" "medium" "US-012"
```

#### Adim 3: Gelistirme Zinciri

```
Sen: "database-engineer: TASK-005 notification modeli icin Prisma schema olustur"
```

Database engineer calisir:
```
✅ Notification model olusturuldu
✅ NotificationPreference model olusturuldu
✅ organizationId eklendi
✅ Indexler tanimlandi
✅ prisma validate gecti
→ Handoff: database-engineer → nestjs-developer
```

```
Sen: "nestjs-developer: TASK-006 notification NestJS modulunu implement et"
```

NestJS developer calisir:
```
✅ notification.module.ts olusturuldu
✅ notification.controller.ts - JwtAuthGuard + FullAccessGuard
✅ notification.service.ts - organizationId filtreleme
✅ DTO'lar olusturuldu (class-validator)
✅ Swagger documentation eklendi
✅ tsc --noEmit gecti
→ Handoff: nestjs-developer → queue-developer
```

```
Sen: "queue-developer: TASK-007 notification BullMQ processor yaz"
```

```
Sen: "qa-engineer: notification modulu icin testleri yaz"
```

```
Sen: "security-engineer: notification modulu guvenlik denetimi yap"
```

#### Adim 4: Durum Kontrolu

```
Sen: "sprint durumunu goster"
```

```
[SWARM] Sprint: Sprint 1 (active)
  Goal: MVP: Temel puan sistemi
  Tasks: 5 planned | 2 active | 1 review | 4 done
```

---

## 7. Senaryo 5: Bug Fix

> "Production'da bir bug bulduk, acil duzeltmemiz lazim"

### Hizli Bug Fix Zinciri

```
Sen: "bug fix: kullanicilar baska organizasyonun verilerini gorebiliyor"
```

#### Adim 1: PM Task Olusturur

```bash
bash hooks/swarm.sh task create "organizationId leak fix" "nestjs-developer" "critical" "BUG-001"
```

#### Adim 2: Developer Duzeltir

```
Sen: "nestjs-developer: TASK-012 organizationId leak bugini duzelt. Kullanicilar baska
     organizasyonun verilerini gorebiliyor."
```

NestJS developer:
- Tum service dosyalarini tarar
- organizationId filtreleme eksik olan query'leri bulur
- Duzeltir
- Test yazar

```bash
bash hooks/swarm.sh task update TASK-012 review
bash hooks/swarm.sh handoff nestjs-developer qa-engineer TASK-012 "organizationId leak duzeltildi, 3 servis etkilendi"
```

#### Adim 3: QA Dogrular

```
Sen: "qa-engineer: TASK-012 organizationId fix'ini dogrula"
```

QA engineer:
- Multi-tenant izolasyon testleri yazar
- Mevcut testleri calistirir
- Regression olmadini dogrular

```bash
bash hooks/swarm.sh task update TASK-012 done
bash hooks/swarm.sh handoff qa-engineer project-manager TASK-012 "Testler gecti, %94 coverage"
```

### Bug Fix Zinciri (Kisa)

```
project-manager → nestjs-developer → qa-engineer → project-manager
```

---

## 8. Senaryo 6: Database Degisikligi

> "Mevcut modele yeni alanlar eklememiz gerekiyor"

```
Sen: "database-engineer: Customer modeline loyaltyPoints ve tier alanlari ekle"
```

### Zincir

```
architect (gerekirse review) → database-engineer → nestjs-developer → qa-engineer
```

#### Database Engineer:

```
✅ Customer modeline loyaltyPoints (Int, default 0) eklendi
✅ Customer modeline tier (Enum: BRONZE, SILVER, GOLD, PLATINUM) eklendi
✅ Index eklendi: @@index([organizationId, tier])
✅ Migration olusturuldu: add_loyalty_fields
✅ prisma validate gecti
→ Handoff: database-engineer → nestjs-developer
```

#### NestJS Developer:

```
Sen: "nestjs-developer: customer servisini yeni loyalty alanlari icin guncelle"
```

- DTO'lari gunceller
- Servis metotlarini gunceller
- Swagger'i gunceller
- Handoff: nestjs-developer → qa-engineer

---

## 9. Senaryo 7: 3rd Party API Entegrasyonu

> "iyzico odeme entegrasyonu yapmamiz gerekiyor"

```
Sen: "iyzico odeme entegrasyonu arastir ve implement et"
```

### Zincir

```
api-researcher → architect → nestjs-developer → qa-engineer
```

#### Adim 1: API Researcher

```
Sen: "api-researcher: iyzico odeme API'sini arastir, Kuark entegrasyonu icin rapor hazirla"
```

API Researcher:
- iyzico API dokumantasyonunu inceler
- Sandbox/production farklarini belgeler
- Rate limit ve guvenlik gereksinimlerini cikarir
- Entegrasyon rehberi hazirlar

#### Adim 2: Architect

```
Sen: "architect: iyzico entegrasyonu icin mimari karar ver (ADR yaz)"
```

Architect:
- Payment modulu yerlesimini belirler
- Webhook stratejisini tasarlar
- ADR yazar

#### Adim 3: NestJS Developer

```
Sen: "nestjs-developer: iyzico odeme modulunu implement et"
```

---

## 10. Senaryo 8: Sprint Bitirme ve Yeni Sprint

> "Sprint 1 bitti, Sprint 2'ye gecmek istiyorum"

### Sprint 1'i Bitir

```
Sen: "project-manager: Sprint 1 retrospective yap ve Sprint 2'yi planla"
```

#### Adim 1: Retrospective

```bash
bash hooks/swarm.sh sprint status
```

```
[SWARM] Sprint: Sprint 1 (active)
  Goal: MVP: Temel puan sistemi
  Tasks: 0 planned | 0 active | 0 review | 8 done
```

Tum task'lar bittiyse:

```bash
bash hooks/swarm.sh sprint end
```

```
[SWARM] Ended: Sprint 1
```

Sprint dosyasi `.swarm/sprints/Sprint-1.json` olarak arsivlenir.

#### Adim 2: Yeni Sprint Baslat

```bash
bash hooks/swarm.sh sprint start "Sprint 2" "Bildirim sistemi ve raporlama"
```

#### Adim 3: Yeni Task'lari Olustur

```
Sen: "project-manager: Sprint 2 icin backlog'dan task'lari dagit"
```

---

## 11. Senaryo 9: Bir Sey Ters Giderse (Rollback)

### Durum 1: Test Basarisiz Oldu

QA engineer testleri geciremediyse:

```bash
# Task'i rework'e gonder
bash hooks/swarm.sh task update TASK-003 in-progress
bash hooks/swarm.sh handoff qa-engineer nestjs-developer TASK-003 "3 test basarisiz: token expiry, role check, rate limit"
```

```
Sen: "nestjs-developer: TASK-003 QA'den geri dondu, su sorunlari duzelt: [sorunlar]"
```

### Durum 2: Guvenlik Acigi Bulundu

```bash
bash hooks/swarm.sh task update TASK-003 blocked
bash hooks/swarm.sh handoff security-engineer nestjs-developer TASK-003 "CRITICAL: SQL injection acigi bulundu"
```

### Durum 3: Tamamen Geri Almak Istiyorum

```bash
# Git ile kod degisikliklerini geri al
git stash push -m "rollback:TASK-003:hata"

# Task'i baslangica dondur
bash hooks/swarm.sh task update TASK-003 planned
```

### Durum 4: Sprint Iptal

```bash
# Sprint'i bitir
bash hooks/swarm.sh sprint end

# Tamamlanmamis task'lari sifirla
# (bunu project-manager agent'indan iste)

# Yeni sprint baslat
bash hooks/swarm.sh sprint start "Sprint 1-B" "Revize edilmis hedef"
```

---

## 12. Agent Rehberi - Kimden Ne Istenir?

### Hangi Kelime Hangi Agent'i Aktive Eder?

| Soyledigin | Aktive Olan Agent | Ne Yapar |
|------------|-------------------|----------|
| "proje baslat", "backlog" | product-owner | Gereksinim toplar, user story yazar |
| "sprint planla", "task dagit" | project-manager | Sprint planlar, task olusturur |
| "analiz et", "user story" | analyst | Gereksinimleri detaylandirir |
| "mimari tasarla", "ADR" | architect | Mimari kararlar alir |
| "NestJS modul", "controller", "servis" | nestjs-developer | Backend API yazar |
| "sayfa olustur", "component" | nextjs-developer | Frontend yazar |
| "Prisma schema", "migration" | database-engineer | Database tasarlar |
| "BullMQ", "background job" | queue-developer | Arkaplan is yazar |
| "test yaz", "coverage" | qa-engineer | Test yazar ve calistirir |
| "guvenlik", "audit", "RBAC" | security-engineer | Guvenlik denetler |
| "Docker", "deploy", "CI/CD" | devops-engineer | Deployment hazirlar |
| "API arastir", "iyzico" | api-researcher | 3rd party API arastirir |
| "dokumantasyon", "README" | documentation | Dokuman yazar |
| "Python", "FastAPI" | python-developer | Python servisi yazar |

### Agent Cagirma Ornekleri

```
# Dogru - spesifik ve net
"nestjs-developer: authentication modulu icin JWT refresh token endpoint'i ekle"

# Dogru - task referansli
"qa-engineer: TASK-005 notification modulu icin unit ve integration testlerini yaz"

# Dogru - genel istek (sistem dogru agent'i secer)
"Prisma schema'ya NotificationTemplate modeli ekle"
  → database-engineer otomatik aktive olur

# Dogru - zincir baslat
"proje baslat: E-ticaret marketplace"
  → product-owner aktive olur, sorular sorar, PM'e devreder
```

---

## 13. Komut Referansi

### Proje Yonetimi

```bash
# Swarm baslat
bash hooks/swarm.sh init "proje-adi"
bash hooks/swarm.sh init "proje-adi" "monorepo"    # tip belirterek

# Durum
bash hooks/swarm.sh status

# Sifirla (dikkat: tum state silinir!)
bash hooks/swarm.sh reset "proje-adi"
```

### Task Yonetimi

```bash
# Olustur
bash hooks/swarm.sh task create "Baslik" "agent-adi" "oncelik" "US-XXX"
# Ornekler:
bash hooks/swarm.sh task create "Auth modulu" "nestjs-developer" "high" "US-001"
bash hooks/swarm.sh task create "Dashboard" "nextjs-developer" "medium" "US-004"

# Durum guncelle
bash hooks/swarm.sh task update TASK-001 in-progress
bash hooks/swarm.sh task update TASK-001 review
bash hooks/swarm.sh task update TASK-001 done
bash hooks/swarm.sh task update TASK-001 blocked

# Listele
bash hooks/swarm.sh task list
```

### Sprint Yonetimi

```bash
# Baslat
bash hooks/swarm.sh sprint start "Sprint 1" "Sprint hedefi"

# Durum
bash hooks/swarm.sh sprint status

# Bitir (arsivler)
bash hooks/swarm.sh sprint end
```

### Agent Handoff

```bash
# Gecis logla
bash hooks/swarm.sh handoff nestjs-developer qa-engineer TASK-001 "Auth tamamlandi"
bash hooks/swarm.sh handoff qa-engineer security-engineer TASK-001 "Testler gecti"
bash hooks/swarm.sh handoff security-engineer devops-engineer TASK-001 "Guvenlik onaylandi"

# Agent iletisimi
echo '{"from":"project-manager","to":"nestjs-developer","type":"assignment","content":"Auth modulu"}' | bash hooks/swarm.sh communicate
```

### Task Durum Gecisleri

```
planned ──→ in-progress ──→ review ──→ done
                 ↑              │
                 └──────────────┘  (rework/geri gonderme)
                 ↑
            blocked (engel durumu)
```

---

## 14. Yapilmasi ve Yapilmamasi Gerekenler

### YAPIN

- Her oturum basinda `"swarm durumunu kontrol et"` deyin
- Task baslamadan once durumu `in-progress` yapin
- Her agent gecisinde handoff loglayin
- Sprint sonunda retrospective yapin
- Bug fix icin ayri task olusturun
- Kritik isler icin `"critical"` oncelik kullanin
- Database degisikliklerinde once architect'e danisin
- Production oncesi security-engineer denetiminden gecirin

### YAPMAYIN

- Agent'lari atlayarak ilerlemyin (ornegin QA'siz production'a cikmayin)
- `swarm reset` komutunu dusunmeden calistirmayin (tum state silinir)
- Task olusturmadan dogrudan kodlamaya baslamayin
- Handoff loglamadan agent degistirmeyin
- Sprint bitmeden yeni sprint baslatmayin (once `sprint end`)
- `.swarm/` dizinini manuel olarak editlemyin
- `force push` yapmayin (hook uyari verir ama yine de dikkat)

---

## 15. Sik Sorulan Sorular

### S: Tek bir agent cagirmak istiyorum, tum zinciri baslatmak zorunda miyim?

H: Hayir. Direkt agent'i cagirabilirsin:
```
"nestjs-developer: su servis dosyasina pagination ekle"
```
Sadece izole bir degisiklik icin tum zincir gerekli degil. Zincir yeni ozellik veya buyuk degisiklikler icindir.

### S: .swarm/ dizinini git'e commit etmeli miyim?

H: Hayir. `swarm init` komutu otomatik olarak `.gitignore`'a ekler. `.swarm/` dizini yerel gelistirme state'idir, takimla paylasılmaz.

### S: Birden fazla kisi ayni projede swarm kullanabilir mi?

H: Her kisinin kendi `.swarm/` state'i olur. Takim koordinasyonu icin:
- Git branch'leri kullanin (feature/TASK-XXX-baslik)
- Task numaralarini commit mesajlarinda kullanin
- Sprint planlamasi takimca yapilir

### S: Agent yanlis bir sey yapti, nasil geri alirim?

H: Uc secenek:
1. `git stash` veya `git reset` ile kod degisikliklerini geri al
2. `bash hooks/swarm.sh task update TASK-XXX planned` ile task'i sifirla
3. Farkli bir agent'a `"bu dosyadaki degisiklikleri geri al"` de

### S: Hook'lar calismiyor, ne yapayim?

H: Kontrol et:
```bash
# Hook dosyalari calistirilabilir mi?
ls -la ~/kuark-system/hooks/

# jq yuklu mu?
which jq

# config.json dogru mu?
cat ~/kuark-system/config.json | jq .
```

### S: Yeni bir agent ekleyebilir miyim?

H: Evet. `agents/` altina yeni dizin olustur:
```
agents/yeni-agent/SKILL.md
```
SKILL.md'de frontmatter (name, description, tetikleyiciler) ve agent talimatlari olmali.
Sonra CLAUDE.md'deki Agent Reference tablosuna ekle.

### S: Sadece backend (NestJS) gelistiriyorum, frontend agent'larina ihtiyacim yok. Sorun olur mu?

H: Hayir. Sadece ihtiyacin olan agent'lari cagir. Kullanmadiklarin aktive olmaz.

### S: Sprint olmadan task yonetimi yapabilir miyim?

H: Evet. Sprint baslatmadan task olusturup yonetebilirsin:
```bash
bash hooks/swarm.sh init "proje"
bash hooks/swarm.sh task create "Baslik" "agent" "high"
# Sprint komutlarini kullanmana gerek yok
```

---

## Hizli Baslangic Kontrol Listesi

Yeni ekip uyesi icin:

```
[ ] Claude Code CLI kuruldu
[ ] jq yuklendi (brew install jq)
[ ] kuark-system reposu clonlandi
[ ] Hook dosyalari chmod +x ile calistirilabilir yapildi
[ ] Claude Code acildiginda [KUARK] ciktisi gorunuyor
[ ] "swarm durumunu kontrol et" komutunu denedim
[ ] Ilk task'imi olusturdum
[ ] Bir agent'i basariyla cagirdim
```
