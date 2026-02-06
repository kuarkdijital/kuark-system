# TASK-XXX: [Baslik]

## Meta
- **User Story:** US-XXX
- **Atanan:** [ajan-adi]
- **Durum:** planned | in-progress | review | done | blocked
- **Oncelik:** critical | high | medium | low
- **Tahmini Effort:** XS | S | M | L | XL
- **Sprint:** Sprint N
- **Olusturma:** YYYY-MM-DDTHH:MM:SSZ
- **Guncelleme:** YYYY-MM-DDTHH:MM:SSZ

## Aciklama
[Detayli aciklama - ne yapilacak, neden yapilacak]

## Kabul Kriterleri
- [ ] Kriter 1
- [ ] Kriter 2
- [ ] Kriter 3

## Teknik Notlar
- Modul yolu: `apps/api/src/modules/[feature]/`
- Multi-tenant: organizationId filtreleme zorunlu
- Permission: [gerekli permission'lar]
- Bagimlilklar: [kullanilacak servisler]

## Bagimliliklar
- TASK-XXX: [aciklama] (blocker | related)

## Kuark Checklist

### Backend (NestJS)
- [ ] @UseGuards(JwtAuthGuard, FullAccessGuard) uygulandı
- [ ] organizationId tum query'lerde filtreleniyor
- [ ] DTO validation (class-validator) eklendi
- [ ] Swagger documentation (@ApiTags, @ApiOperation) eklendi
- [ ] Error handling (NotFoundException, BadRequestException) eklendi
- [ ] Logger kullanildi

### Frontend (Next.js)
- [ ] Server/Client component dogru secildi
- [ ] Loading state (Skeleton) mevcut
- [ ] Error state (ErrorDisplay) mevcut
- [ ] Empty state (EmptyState) mevcut
- [ ] Form validation (Zod + React Hook Form) eklendi
- [ ] Responsive tasarim

### Database (Prisma)
- [ ] organizationId alani mevcut
- [ ] createdAt, updatedAt alanlari mevcut
- [ ] deletedAt (soft delete) mevcut
- [ ] Indexler tanimli (organizationId, status)
- [ ] prisma validate gecti

### Genel
- [ ] TypeScript strict - sifir hata (tsc --noEmit)
- [ ] Testler yazildi ve geciyor
- [ ] Dokumantasyon guncellendi
- [ ] Code review yapildi

## Agent Handoff

### Onceki Agent
- **Agent:** [agent-adi]
- **Cikti:** [ne teslim etti]
- **Dosyalar:** [degistirilen/olusturulan dosyalar]

### Sonraki Agent
- **Agent:** [agent-adi]
- **Beklenen Input:** [ne bekliyor]
- **Notlar:** [dikkat edilecekler]

## Log
- YYYY-MM-DDTHH:MM:SSZ | created | [agent] | Task olusturuldu
- YYYY-MM-DDTHH:MM:SSZ | status_change | in-progress | [agent] basladi
- YYYY-MM-DDTHH:MM:SSZ | handoff | [from] -> [to] | [aciklama]
- YYYY-MM-DDTHH:MM:SSZ | status_change | done | Tamamlandi
