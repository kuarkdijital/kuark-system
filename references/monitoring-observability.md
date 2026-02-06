# Monitoring & Observability

> Logging, metriks ve alerting stratejileri

## Uc Sutun

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   LOGGING   │  │   METRICS   │  │   TRACING   │
│  (ne oldu)  │  │ (ne kadar)  │  │  (nerede)   │
└─────────────┘  └─────────────┘  └─────────────┘
```

---

## 1. Structured Logging

### NestJS Logger Pattern
```typescript
import { Logger } from '@nestjs/common';

@Injectable()
export class FeatureService {
  private readonly logger = new Logger(FeatureService.name);

  async create(organizationId: string, dto: CreateFeatureDto) {
    this.logger.log({
      action: 'feature.create',
      organizationId,
      data: { name: dto.name },
    });

    try {
      const result = await this.prisma.feature.create({...});
      this.logger.log({
        action: 'feature.created',
        organizationId,
        featureId: result.id,
      });
      return result;
    } catch (error) {
      this.logger.error({
        action: 'feature.create.failed',
        organizationId,
        error: error.message,
        stack: error.stack,
      });
      throw error;
    }
  }
}
```

### Log Seviyeleri

| Seviye | Kullanim | Ornek |
|--------|----------|-------|
| `error` | Beklenmeyen hatalar, sistem arızaları | DB baglanti hatasi, unhandled exception |
| `warn` | Potansiyel sorunlar, degraded performance | Yavas query, rate limit yaklasimi |
| `log` | Onemli is akislari | Kullanici login, odeme islemi |
| `debug` | Gelistirme detaylari | Cache hit/miss, query suresi |
| `verbose` | Her sey | Request/response body |

### Log Formati (JSON)
```json
{
  "timestamp": "2024-01-15T10:00:00.000Z",
  "level": "log",
  "context": "FeatureService",
  "action": "feature.created",
  "organizationId": "org-123",
  "userId": "user-456",
  "featureId": "feat-789",
  "duration": 45,
  "requestId": "req-abc"
}
```

### Loglanmamasi Gerekenler
- Parolalar, token'lar, API key'ler
- Kredi karti bilgileri
- Kisisel saglik verileri
- Session ID'leri (maskelenmeli)

---

## 2. Health Checks

### NestJS Health Module
```typescript
import { TerminusModule } from '@nestjs/terminus';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private prisma: PrismaHealthIndicator,
    private redis: RedisHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.prisma.pingCheck('database'),
      () => this.redis.pingCheck('redis'),
    ]);
  }

  @Get('ready')
  @HealthCheck()
  readiness() {
    return this.health.check([
      () => this.prisma.pingCheck('database'),
      () => this.redis.pingCheck('redis'),
      () => this.bullmq.isHealthy('queue'),
    ]);
  }
}
```

### Health Endpoint'leri

| Endpoint | Amac | Kullanan |
|----------|------|----------|
| `/health` | Liveness probe | Container orchestrator |
| `/health/ready` | Readiness probe | Load balancer |
| `/health/startup` | Startup probe | Deployment |

---

## 3. Request Tracking

### Correlation ID Middleware
```typescript
@Injectable()
export class CorrelationIdMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const correlationId = req.headers['x-correlation-id'] || randomUUID();
    req['correlationId'] = correlationId;
    res.setHeader('x-correlation-id', correlationId);
    next();
  }
}
```

### Request Logger Interceptor
```typescript
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const { method, url, correlationId } = req;
    const start = Date.now();

    return next.handle().pipe(
      tap(() => {
        const duration = Date.now() - start;
        this.logger.log({
          action: 'http.request',
          method,
          url,
          correlationId,
          duration,
          status: context.switchToHttp().getResponse().statusCode,
          organizationId: req.user?.organizationId,
        });
      }),
    );
  }
}
```

---

## 4. Audit Logging

### Audit Interceptor
```typescript
@Injectable()
export class AuditInterceptor implements NestInterceptor {
  constructor(private prisma: PrismaService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const { method, url } = req;

    // Sadece mutating islemleri logla
    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
      return next.handle().pipe(
        tap(async () => {
          await this.prisma.auditLog.create({
            data: {
              action: `${method} ${url}`,
              userId: req.user?.sub,
              organizationId: req.user?.organizationId,
              resource: this.extractResource(url),
              details: this.sanitize(req.body),
              ipAddress: req.ip,
              userAgent: req.headers['user-agent'],
            },
          });
        }),
      );
    }

    return next.handle();
  }

  private sanitize(body: Record<string, unknown>) {
    const sanitized = { ...body };
    const sensitiveFields = ['password', 'token', 'secret', 'creditCard'];
    for (const field of sensitiveFields) {
      if (field in sanitized) sanitized[field] = '***';
    }
    return sanitized;
  }

  private extractResource(url: string): string {
    return url.split('/')[2] || 'unknown';
  }
}
```

### Audit Log Model (Prisma)
```prisma
model AuditLog {
  id             String   @id @default(cuid())
  action         String
  userId         String
  organizationId String
  resource       String
  details        Json?
  ipAddress      String?
  userAgent      String?
  createdAt      DateTime @default(now())

  @@index([organizationId])
  @@index([userId])
  @@index([resource])
  @@index([createdAt])
}
```

---

## 5. Performance Metrikleri

### Takip Edilecek Metrikler

| Metrik | Hedef | Alarm |
|--------|-------|-------|
| Response time (p95) | < 200ms | > 500ms |
| Error rate | < 0.1% | > 1% |
| Database query time (p95) | < 50ms | > 200ms |
| Redis latency | < 5ms | > 20ms |
| BullMQ job wait time | < 30s | > 120s |
| Memory usage | < 512MB | > 768MB |
| CPU usage | < 60% | > 85% |

### Slow Query Detection
```typescript
@Injectable()
export class PrismaSlowQueryMiddleware {
  private readonly logger = new Logger('PrismaSlowQuery');

  constructor(private prisma: PrismaService) {
    this.prisma.$use(async (params, next) => {
      const start = Date.now();
      const result = await next(params);
      const duration = Date.now() - start;

      if (duration > 100) {
        this.logger.warn({
          action: 'slow_query',
          model: params.model,
          operation: params.action,
          duration,
        });
      }

      return result;
    });
  }
}
```

---

## 6. Railway Monitoring

### Railway Logging
Railway otomatik olarak stdout/stderr'i toplar:
```bash
# railway.toml
[deploy]
healthcheckPath = "/health"
healthcheckTimeout = 30
```

### Environment Variables
```env
# Log level
LOG_LEVEL=log

# Health check
HEALTH_CHECK_ENABLED=true

# Metrics
METRICS_ENABLED=true
```

---

## 7. Alerting Kurallari

### Kritik (Aninda Bildirim)
- Application crash / restart
- Database baglanti hatasi
- Redis baglanti hatasi
- Error rate > 5%
- Health check basarisiz

### Uyari (15 dakika icinde)
- Response time p95 > 500ms
- Memory > 768MB
- Disk usage > 80%
- Failed BullMQ jobs > 10/saat

### Bilgi (Gunluk Rapor)
- Daily error summary
- Slow query report
- Cache hit ratio
- BullMQ job statistics
