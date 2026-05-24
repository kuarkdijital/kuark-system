---
description: Aktif Kuark ajanını değiştir (manuel override)
argument-hint: <agent-name>
---

# /kuark-agent $ARGUMENTS

Aktif ajanı `$ARGUMENTS`'taki isime ayarla.

## KRİTİK: Kullanıcı seçimi AskUserQuestion ile

Argüman boşsa kullanıcıya **mutlaka `AskUserQuestion` tool'u ile** sor. Free-text chat sorusu kullanma. Ajan listesini option olarak ver (4'erli gruplar halinde — UI 4 option limit'i var, multiSelect=false). Mantıklı gruplandırma:
- "Planning & Review": product-owner, project-manager, analyst, architect
- "Backend & Data": nestjs-developer, database-engineer, queue-developer, python-developer
- "Frontend & Design": nextjs-developer, ui-ux-designer
- "Quality & Ops": qa-engineer, security-engineer, devops-engineer, hadron-engineer
- "Diğer": api-researcher, documentation

Önce hangi gruba geçeceğini sor, sonra grup içinden seçtir.

## Adımlar

1. Argüman boşsa: yukarıdaki AskUserQuestion akışını yürüt.

2. `kuark agent set <name>` çalıştır.

3. Önemli: bu sadece ledger event'i. Gerçek iş için **Agent tool ile sub-agent dispatch** yapman gerekir:
   ```
   Agent(subagent_type="kuark-<name>", prompt="...")
   ```

4. Kullanıcıya `AskUserQuestion` ile sor: "Şimdi ne yapmak istersiniz?" options: "Yeni task oluştur", "Mevcut bir task'a devam et", "Sadece durum gör", "Başka bir ajana geç".

## Valid Ajanlar

product-owner, project-manager, analyst, architect, nestjs-developer, nextjs-developer, database-engineer, queue-developer, python-developer, qa-engineer, security-engineer, devops-engineer, hadron-engineer, ui-ux-designer, api-researcher, documentation, orchestrator
