---
description: Belirli task'ı uygun Kuark sub-agent'ına dispatch et (paralel destekli)
argument-hint: <TASK-ID> [TASK-ID...]
---

# /kuark-dispatch $ARGUMENTS

Bir veya daha fazla task'ı paralel sub-agent dispatch ile çalıştır.

## KRİTİK: Kullanıcı seçimi AskUserQuestion ile

Argüman boşsa, dispatch öncesi onay, bağımlılık çözümü gibi tüm kullanıcı etkileşimleri **`AskUserQuestion` tool'u ile**. Free-text chat sorusu yasak. Task seçiminde `multiSelect: true` kullan (birden çok task seçilebilsin), options olarak `kuark tasks --status planned` çıktısından TASK-ID + title pair'leri ver.

## Adımlar

1. **Argümanları parse et**: Boşluk-ayraçlı TASK-ID listesi. Boşsa:
   - `kuark tasks --status planned` çıktısını oku
   - `AskUserQuestion` ile (multiSelect=true) hangi task'ların dispatch edileceğini seçtir
   - Her option: label="TASK-XXX: <title kısaltma>", description="assignee, priority"

2. **Her task için**:
   - `kuark task show TASK-XXX` ile assignee + detayları al
   - Önceki handoff DRAFT'ı varsa oku, yoksa task ile birlikte yeni context inşa et
   - Task'ı `in-progress` yap: `kuark task update TASK-XXX in-progress`

3. **Paralel dispatch** (TÜM Agent tool çağrılarını **aynı mesajda** yap):
   ```
   Agent(subagent_type="kuark-<assignee1>", prompt="""
     TASK-XXX: <title>
     Handoff payload: .swarm/handoffs/HOFF-DRAFT-...md (eğer varsa)
     Architectural decisions: .swarm/decisions/DEC-*.md (ilgili olanları oku)
     Project context: .swarm/views/dashboard.md

     Görevin: task'ı baştan sona tamamla. Bitirince DRAFT handoff yaz.
   """)
   Agent(subagent_type="kuark-<assignee2>", prompt="...")
   ...
   ```

4. **Dönen sonuçlar için**:
   - Her sub-agent DRAFT handoff/decisions yazmış olmalı
   - Sen (orchestrator) DRAFT'ları formalize et:
     - `kuark task update TASK-XXX review` (veya done, eğer test geçtiyse)
     - `kuark decide ...` (her DRAFT decision için)
     - `kuark handoff <agent> <next> --task TASK-XXX --payload <path>` (sonraki ajana yönlendirme)

5. **Kullanıcıya özet**: tamamlanan, in-review, blocker'lar.

## Paralellik kuralı

Birbirinden bağımsız task'lar (örn. backend module + frontend page + DB migration) **aynı turn'de paralel dispatch**.
Bağımlı task'lar (örn. DB schema → API endpoint → frontend) **sıralı**.

Bağımlılık `.swarm/views/dashboard.md` veya architect handoff'unda belirtilmiş olmalı.
