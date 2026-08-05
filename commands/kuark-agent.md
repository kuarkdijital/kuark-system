---
description: Aktif Kuark ajanını değiştir (manuel override)
argument-hint: <agent-name>
---

# /kuark-agent $ARGUMENTS

Aktif ajanı `$ARGUMENTS`'taki isime ayarla.

## KRİTİK: Kullanıcı seçimi — yapılandırılmış girdi

Argüman boşsa platform protokolü ile sor (`user-input-protocol.md`). Free-text yasak.
Ajan listesini option olarak ver (4'erli gruplar).
- "Planning & Review": product-owner, project-manager, analyst, architect
- "Backend & Data": nestjs-developer, database-engineer, queue-developer, python-developer
- "Frontend & Design": nextjs-developer, ui-ux-designer
- "Quality & Ops": qa-engineer, security-engineer, devops-engineer, hadron-engineer
- "Diğer": api-researcher, documentation

Önce hangi gruba geçeceğini sor, sonra grup içinden seçtir.

## Adımlar

1. Argüman boşsa: yukarıdaki yapılandırılmış seçim akışını yürüt.

2. `kuark agent set <name>` çalıştır.

3. Gerçek iş için sub-agent dispatch:
   ```
   # Claude Code
   Agent(subagent_type="kuark-<name>", prompt="...")
   # Cursor
   Task(subagent_type="kuark-<name>", model="<tier-slug>", prompt="...")
   ```

4. Kullanıcıya yapılandırılmış sor: "Şimdi ne yapmak istersiniz?"
   1) Yeni task oluştur  2) Mevcut task'a devam  3) Sadece durum gör  4) Başka ajana geç

## Valid Ajanlar

product-owner, project-manager, analyst, architect, nestjs-developer, nextjs-developer, database-engineer, queue-developer, python-developer, qa-engineer, security-engineer, devops-engineer, hadron-engineer, ui-ux-designer, api-researcher, documentation, orchestrator
