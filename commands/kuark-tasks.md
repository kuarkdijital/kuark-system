---
description: Tüm Kuark task'larını ve durumlarını göster
argument-hint: [--status X] [--agent Y]
---

# /kuark-tasks $ARGUMENTS

Kuark proje state'ini göster.

## Adımlar

1. `kuark status` — özet
2. `kuark tasks $ARGUMENTS` — filtered task tablosu
3. Eğer ek detay isteniyorsa: `cat .swarm/views/dashboard.md` ve `cat .swarm/views/by-agent.md`

Sonuçları kullanıcıya **olduğu gibi** göster (parsing yapma, tablolar zaten markdown).

## Örnekler

```
/kuark-tasks
/kuark-tasks --status in-progress
/kuark-tasks --agent nestjs-developer
```
