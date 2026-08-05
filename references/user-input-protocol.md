# User Input Protocol (Multi-Platform)

Kuark wizard ve netleştirme adımlarında kullanıcıdan girdi **her zaman yapılandırılmış** alınır: 2–4 seçenek + "Other" / serbest metin çıkışı.

## Platform matrisi

| Platform | Araç | Davranış |
|----------|------|----------|
| **Claude Code** | `AskUserQuestion` | Zorunlu. Free-text chat sorusu yasak. `multiSelect` gerektiğinde aç. |
| **Cursor** | Numaralı seçenek listesi | Chat'te `1)`, `2)`, `3)`, `Other` formatında sor. Kullanıcı numarayla veya kısa etiketle cevaplar. `AskQuestion` tool varsa onu tercih et. |
| **Codex** | Numaralı seçenek listesi | Cursor ile aynı: 2–4 seçenek + Other. Free-text yalnızca "Other" veya açık uçlu yaratıcı girdide. |

## Ortak kurallar

1. Her adımda **tek karar** sor (birden fazla konu varsa sırayla).
2. Seçenekler somut ve ledger'a yazılabilir olsun.
3. Open-ended (bug tanımı vb.) istisna; yine de 2–4 olası seçenek + Other sun.
4. Sub-agent prompt'larında bu protokolü **açıkça** belirt.

## Cursor örnek formatı

```
Deploy hedefi hangisi olsun?
1) Railway
2) Hadron (self-hosted) — önerilen
3) Docker (manuel)
Other) yazın
```
