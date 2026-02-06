# Caching Strategy

> Redis tabanli cache pattern'lari ve invalidation stratejileri

## Tech Stack

- **Redis 7+** - Primary cache store
- **@nestjs/cache-manager** - NestJS cache integration
- **ioredis** - Redis client

## Cache Katmanlari

```
Client (Browser) → CDN/Edge → API Gateway → Application Cache (Redis) → Database
```

| Katman | TTL | Kullanim |
|--------|-----|----------|
| Browser Cache | 5-60 min | Static assets, API responses |
| Redis Cache | 1-60 min | Sik erislilen query sonuclari |
| In-Memory | 1-5 min | Config, permission lists |

## NestJS Cache Implementasyonu

### Module Setup
```typescript
import { CacheModule } from '@nestjs/cache-manager';
import { redisStore } from 'cache-manager-redis-yet';

@Module({
  imports: [
    CacheModule.registerAsync({
      useFactory: async () => ({
        store: await redisStore({
          socket: {
            host: process.env.REDIS_HOST,
            port: parseInt(process.env.REDIS_PORT, 10),
          },
          ttl: 60 * 1000, // 1 minute default
        }),
      }),
    }),
  ],
})
export class AppModule {}
```

### Service-Level Caching
```typescript
@Injectable()
export class FeatureService {
  constructor(
    private prisma: PrismaService,
    @Inject(CACHE_MANAGER) private cache: Cache,
  ) {}

  async findAll(organizationId: string) {
    const cacheKey = `features:${organizationId}:list`;

    // Check cache first
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;

    // Query database
    const [data, total] = await Promise.all([
      this.prisma.feature.findMany({
        where: { organizationId, deletedAt: null },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.feature.count({
        where: { organizationId, deletedAt: null },
      }),
    ]);

    const result = { data, pagination: { total } };

    // Cache result
    await this.cache.set(cacheKey, result, 5 * 60 * 1000); // 5 min

    return result;
  }

  async create(organizationId: string, dto: CreateFeatureDto, userId: string) {
    const feature = await this.prisma.feature.create({
      data: { ...dto, organizationId, createdBy: userId },
    });

    // Invalidate list cache
    await this.invalidateCache(organizationId);

    return feature;
  }

  private async invalidateCache(organizationId: string) {
    await this.cache.del(`features:${organizationId}:list`);
  }
}
```

## Cache Key Convention

```
{entity}:{organizationId}:{identifier}

Ornekler:
  features:org-123:list          # Liste cache
  features:org-123:feat-456      # Tekil kayit cache
  features:org-123:count         # Sayi cache
  permissions:org-123:user-789   # Kullanici permission cache
  config:org-123:settings        # Organizasyon ayarlari
```

**Kural:** Cache key'de her zaman `organizationId` olmali (multi-tenant izolasyon).

## Invalidation Stratejileri

### 1. Write-Through (Onerilen)
```
Write -> Update Cache -> Update DB
```
- Tutarlilik yuksek
- Yazma maliyeti biraz artar

### 2. Cache-Aside (Mevcut Pattern)
```
Read: Cache miss -> DB -> Cache set
Write: DB -> Cache delete
```
- Basit implementasyon
- Kisa sureli tutarsizlik olabilir

### 3. Event-Based Invalidation
```typescript
// Feature olusturulunca event firlatilir
this.eventEmitter.emit('feature.created', { organizationId });

// Listener cache'i temizler
@OnEvent('feature.created')
async handleFeatureCreated(payload: { organizationId: string }) {
  await this.cache.del(`features:${payload.organizationId}:list`);
}
```

## Neleri Cache'lememeli

- Kullanici oturumu / auth token'lar (Redis session store kullan)
- Sik degisen veriler (real-time dashboard metrikleri)
- Buyuk binary veriler (dosyalar, resimler)
- Hassas kisisel veriler (PII)

## Neleri Cache'lemeli

| Veri | TTL | Neden |
|------|-----|-------|
| Permission listesi | 5 min | Her request'te sorgulanir |
| Organization ayarlari | 10 min | Nadiren degisir |
| Feature listeleri | 5 min | Sik okunan, az yazilan |
| Dashboard istatistikleri | 1 min | Agregasyon pahali |
| Enum/lookup tablolari | 30 min | Neredeyse hic degismez |

## BullMQ ile Cache Warming

```typescript
@Processor('cache')
export class CacheWarmProcessor extends WorkerHost {
  async process(job: Job<{ organizationId: string }>) {
    const { organizationId } = job.data;

    // Pre-populate frequently accessed data
    await this.featureService.findAll(organizationId);
    await this.permissionService.getPermissions(organizationId);
  }
}
```

## Monitoring

```typescript
// Cache hit/miss oranini logla
const cached = await this.cache.get(cacheKey);
if (cached) {
  this.logger.debug(`Cache HIT: ${cacheKey}`);
} else {
  this.logger.debug(`Cache MISS: ${cacheKey}`);
}
```
