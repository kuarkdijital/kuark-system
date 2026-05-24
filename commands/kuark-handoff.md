---
description: Aktif ajandan başka bir ajana structured handoff yap
argument-hint: <to-agent> [TASK-ID]
---

# /kuark-handoff $ARGUMENTS

Aktif ajandan `$ARGUMENTS`'taki ilk argümana handoff yap.

## Adımlar

1. **Aktif ajanı oku**:
   ```bash
   FROM=$(kuark agent current)
   echo "From: $FROM"
   ```

2. **Argümanları parse et**: `$ARGUMENTS` formatı `<to-agent> [TASK-ID]`. Boşluksa kullanıcıya AskUserQuestion ile sor.

3. **Aktif sub-agent'a DRAFT handoff yazdır** (eğer henüz yoksa):
   - `ls -t .swarm/handoffs/HOFF-DRAFT-*.md 2>/dev/null` ile kontrol et
   - Yoksa, çıkış ajanını Agent tool ile çağır ve handoff DRAFT yazmasını iste

4. **DRAFT'ı oku ve özeti çıkar**

5. **Ledger event'i yaz**:
   ```bash
   kuark handoff $FROM <to-agent> --task <TASK-ID> --summary "..." --payload <draft-path>
   ```
   - `--payload` ile DRAFT'ı kalıcı handoff dosyası olarak işaretle
   - Hedef ajan otomatik active agent olur

6. **Yeni ajanı dispatch et**:
   ```
   Agent(subagent_type="kuark-<to-agent>", prompt="""
   Handoff payload: <path>
   Task: <TASK-ID>
   Görevin: payload'u oku ve devam et.
   """)
   ```

7. **Kullanıcıya özet**: `kuark status` ve son handoff bilgisi.

## Örnek

```
/kuark-handoff nestjs-developer TASK-005
```

Sonuç: Aktif ajan (architect) → nestjs-developer'a handoff. Ledger'da HOFF-XXX event'i, .swarm/handoffs/HOFF-XXX.md dosyası, nestjs-developer dispatch.
