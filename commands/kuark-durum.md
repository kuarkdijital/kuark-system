---
description: Kuark proje durumu — özet + dashboard
---

# /kuark-durum

Proje durumunu kullanıcıya göster.

## Adımlar

```bash
kuark status
echo
echo "── Recent activity ──"
kuark log --tail 10
echo
echo "── Active sprint tasks ──"
kuark tasks
```

Çıktıyı **olduğu gibi** kullanıcıya ilet. Markdown render edilecek.

Ek olarak (kullanıcı isterse): `cat .swarm/views/dashboard.md` tam dashboard'u gösterir.
