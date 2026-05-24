---
description: Kuark multi-agent proje başlatma — PO→PM→Architect dispatch zinciri
argument-hint: [proje-adı]
---

# /kuark-proje-baslat $ARGUMENTS

Yeni bir Kuark projesi başlat. Sub-agent dispatch zincirini yürüt — sen (main Claude) **orchestrator**'sın ve **tek ledger writer**'sın.

## Adım 0: Hazırlık

```bash
if [ ! -d .swarm ]; then
  kuark init "${ARGUMENTS:-$(basename $PWD)}"
fi
kuark status
```

## Adım 1: Product Owner Dispatch

`kuark-product-owner` sub-agent'ını çağır (Agent tool ile). Prompt:

> Yeni bir Kuark projesi başlatıyoruz. Kullanıcıyla AskUserQuestion ile etkileşimli wizard yürüt:
>
> 1. **Vizyon**: Bu proje hangi sorunu çözüyor, kim için?
> 2. **Kimlik**: İsim, marka, hedef kitle
> 3. **Teknik yapı**: Backend (NestJS varsayılan), Frontend (Next.js varsayılan), DB, Queue
> 4. **Uygulamalar**: Hangi modüller (auth, payment, admin, ...)
> 5. **Entegrasyonlar**: 3rd party API'ler (iyzico, banka POS, ...)
> 6. **Deploy hedefi**: Railway / Hadron / Docker / başka
> 7. **MVP scope**: İlk versiyonda mutlaka olması gerekenler
>
> Topladığın bilgilerden 5-15 user story üret (US-001, US-002, ...). Her biri:
> - id, title, story (As a... I want... so that...)
> - priority: must_have | should_have | could_have | wont_have
> - effort: XS|S|M|L|XL
> - acceptance_criteria (3-7 madde)
>
> **ÇIKTI**: `.swarm/handoffs/HOFF-DRAFT-product-owner-$(date +%s).md` dosyasına şu yapıda yaz:
> - Project metadata (name, description, stack, integrations)
> - Stories array (yukarıdaki format)
> - PM için context: hangi story'ler aciliyetli, hangi bağımlılıklar var
>
> Bana (orchestrator) dönüş özeti: dosya yolu + 3 cümle özet.

## Adım 2: Orchestrator olarak formalize et

Sub-agent dönünce:
1. DRAFT'ı oku
2. Her story için: `kuark story add "title" priority effort`
3. Project metadata için gerekirse ledger event'i (manual ekleme):
   ```bash
   # PO'nun döndürdüğü stack bilgisini state'e işlemek için yapacağın iş yok —
   # kuark init zaten project.init event'i yazdı. İlerideki sürümlerde
   # project.update event tipi eklenecek; şimdilik DRAFT dosyasında saklanır.
   ```
4. Kullanıcıya özet: kaç story oluşturuldu

## Adım 3: Project Manager Dispatch

`kuark-project-manager` sub-agent'ını çağır. Prompt:

> Backlog hazır. `.swarm/views/dashboard.md` ve `kuark story list` ile inceleyebilirsin.
>
> Görevin:
> 1. İlk sprint için hedef belirle (genelde must_have story'lerden 3-5 tanesi)
> 2. Her story için 1-N task üret. Task = bir sub-agent'ın 1-3 saatte bitirebileceği iş
> 3. Her task için:
>    - title (eylem cümlesi)
>    - assignee (kuark-<agent> isimlerinden biri)
>    - priority (critical | high | medium | low)
>    - story (US-XXX)
> 4. Task'ları **doğru sırayla** üret. Tipik akış:
>    - database-engineer (schema)
>    - architect (ADR'ler)
>    - nestjs-developer (backend module)
>    - ui-ux-designer (wireframe)
>    - nextjs-developer (frontend)
>    - qa-engineer (test)
>    - security-engineer (audit)
>    - devops-engineer (deploy)
>
> **ÇIKTI**: `.swarm/handoffs/HOFF-DRAFT-project-manager-$(date +%s).md`:
> - Sprint name + goal
> - Tasks array: [{title, assignee, priority, story, depends_on: [TASK-XXX], notes}]
>
> Bana dönüş özeti: sprint adı/hedefi, task sayısı, kritik path.

## Adım 4: Orchestrator olarak yine formalize et

1. PM DRAFT'ı oku
2. `kuark sprint start "Sprint X" "goal"`
3. Her task için sırayla: `kuark task create "title" assignee priority US-XXX`
4. Handoff'u ledger'a kaydet: `kuark handoff product-owner project-manager --summary "..."`
5. Sonra: `kuark handoff project-manager architect --summary "Sprint X planlandı, N task hazır"`

## Adım 5: Architect Dispatch (paralel hazırlığı)

`kuark-architect` sub-agent'ını çağır. Prompt:

> Sprint planlandı. `kuark task list` ile tasklara bak, `.swarm/views/dashboard.md`'yi oku.
>
> Görevin: kritik mimari kararları al ve ADR yaz.
> - Auth stratejisi (JWT + refresh? session?)
> - Multi-tenant strategy (organizationId her query'de)
> - Cache layer (Redis pattern)
> - Queue strategy (BullMQ kullanım pattern'leri)
> - Deploy strategy (Railway/Hadron specifics)
>
> Her karar için:
> - Topic, Outcome, Rationale, Alternatives, Consequences
>
> **ÇIKTI**: `.swarm/decisions/DEC-DRAFT-<topic-slug>.md` dosyaları + bir handoff DRAFT
>
> Bana dönüş özeti: kaç karar alındı, paralel başlatılabilecek task'lar listesi.

## Adım 6: Orchestrator — paralel dispatch hazırlığı

1. Architect DRAFT'larını formalize: her biri için `kuark decide "topic" "outcome" "rationale"`
2. Architect handoff: `kuark handoff architect orchestrator --summary "..."`
3. Kullanıcıya rapor ver: hangi task'lar paralel başlatılabilir
4. Kullanıcı onayı al — sonra Adım 7'ye geç (paralel dispatch)

## Adım 7: Paralel Sub-Agent Dispatch

Architect'in işaret ettiği bağımsız task'ları **aynı mesajda** birden fazla Agent tool çağrısıyla başlat:

```
Agent(subagent_type="kuark-database-engineer", prompt="TASK-001: Schema tasarla...")
Agent(subagent_type="kuark-api-researcher",   prompt="TASK-002: iyzico entegrasyonu araştır...")
Agent(subagent_type="kuark-ui-ux-designer",   prompt="TASK-003: Login wireframe...")
```

Her biri kendi DRAFT handoff'unu yazıp dönecek. Sen formalize et, ardından next-wave dispatch.

## Kritik Kurallar

- **Sen tek ledger writer'sın.** Sub-agent'lar yalnız DRAFT yazar; sen `kuark ...` ile formalize edersin.
- **Her event'ten sonra** `kuark status` özeti kullanıcıya yardımcıdır.
- Sub-agent çağrısı sonrası dönüşü **TaskUpdate** ile takip et.
- Eğer kullanıcı "duraklat" derse: aktif task'ları `kuark task update TASK-XXX blocked` yap.
