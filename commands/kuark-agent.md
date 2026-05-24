---
description: Aktif Kuark ajanını değiştir (manuel override)
argument-hint: <agent-name>
---

# /kuark-agent $ARGUMENTS

Aktif ajanı `$ARGUMENTS`'taki isime ayarla.

## Adımlar

1. Argüman boşsa: `kuark agent list` ile valid isimleri göster ve AskUserQuestion ile seçtir.

2. `kuark agent set <name>` çalıştır.

3. Önemli: bu sadece ledger event'i. Gerçek iş için **Agent tool ile sub-agent dispatch** yapman gerekir:
   ```
   Agent(subagent_type="kuark-<name>", prompt="...")
   ```

4. Kullanıcıya: aktif ajan değişti, ne yapmak istediklerini sor.

## Valid Ajanlar

product-owner, project-manager, analyst, architect, nestjs-developer, nextjs-developer, database-engineer, queue-developer, python-developer, qa-engineer, security-engineer, devops-engineer, hadron-engineer, ui-ux-designer, api-researcher, documentation, orchestrator
