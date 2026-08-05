---
description: Belirli task'ı uygun Kuark sub-agent'ına dispatch et (paralel destekli)
argument-hint: <TASK-ID> [TASK-ID...]
---

# /kuark-dispatch $ARGUMENTS

Bir veya daha fazla task'ı paralel sub-agent dispatch ile çalıştır.

## KRİTİK: Kullanıcı seçimi — yapılandırılmış girdi

Argüman boşsa, dispatch öncesi onay vb. için platform protokolünü kullan (`user-input-protocol.md`):
Claude → `AskUserQuestion`; Cursor/Codex → numaralı seçenekler. Free-text yasak.
Task seçiminde mümkünse multi-select; options olarak `kuark tasks --status planned` çıktısından TASK-ID + title ver.

## Adımlar

1. **Argümanları parse et**: Boşluk-ayraçlı TASK-ID listesi. Boşsa:
   - `kuark tasks --status planned` çıktısını oku
   - Yapılandırılmış multi-select ile task seçtir (Claude: AskUserQuestion; Cursor: numaralı liste)
   - Her option: `TASK-XXX: <title>` + assignee/priority

2. **Her task için**:
   - `kuark task show TASK-XXX` ile assignee + detayları al
   - Önceki handoff DRAFT'ı varsa oku, yoksa task ile birlikte yeni context inşa et
   - Task'ı `in-progress` yap: `kuark task update TASK-XXX in-progress`

3. **Paralel dispatch** (tüm çağrıları **aynı mesajda** yap):
   ```
   # Claude Code
   Agent(subagent_type="kuark-<assignee1>", prompt="TASK-XXX: ...")
   # Cursor (model tier: high=Grok, fast=composer)
   Task(subagent_type="kuark-<assignee1>", model="cursor-grok-4.5-high-fast", prompt="TASK-XXX: ...")
   ```
   Prompt'ta ver: title, HOFF-DRAFT path, ilgili DEC-*.md, dashboard.md.
   Bitince DRAFT handoff yazmasını iste. Bağımsız task'lar için birden fazla çağrıyı aynı turn'de yap.

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
