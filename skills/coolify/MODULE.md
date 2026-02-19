# Coolify Skill Module

> Coolify self-hosted PaaS ile deploy, servis yonetimi ve otomasyon

## Triggers

- coolify, deploy coolify, coolify deploy
- self-hosted deploy, coolify servis
- "coolify'a deploy et", "coolify kur", "coolify servisi olustur"

## Technology Stack

```
Coolify v4 (Self-hosted PaaS)
├── REST API (Bearer Token auth)
├── Git entegrasyonu (GitHub App / Deploy Key / Webhook)
├── Build Packs: Dockerfile, Nixpacks, docker-compose, static
├── Reverse Proxy: Traefik (otomatik SSL)
└── Docker Engine (container runtime)
```

---

## API Kimlik Dogrulama

### Token Olusturma
1. Coolify dashboard > **Keys & Tokens** > **API tokens**
2. Token adini gir, **Create New Token** tikla
3. Token sadece bir kez gosterilir - hemen kopyala

### Kullanim
```bash
# Tum isteklerde Bearer token gerekli
curl -s -X GET "https://coolify.example.com/api/v1/projects" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/json"
```

### Token Yetkileri
| Yetki | Middleware | Aciklama |
|-------|-----------|----------|
| `read` | `api.ability:read` | Kaynaklari okuma |
| `write` | `api.ability:write` | Olusturma, guncelleme, silme |
| `deploy` | `api.ability:deploy` | Deploy tetikleme ve restart |

### Ortam Degiskenleri (Kuark Projesi)
```bash
# .env veya Coolify env vars
COOLIFY_API_URL=https://coolify.example.com/api/v1
COOLIFY_TOKEN=your-api-token
COOLIFY_SERVER_UUID=server-uuid
COOLIFY_PROJECT_UUID=project-uuid
```

---

## API Endpoint Referansi

### Base URL
```
https://<coolify-domain>/api/v1/...
```

### Projeler

| Method | Path | Aciklama |
|--------|------|----------|
| `GET` | `/projects` | Tum projeleri listele |
| `POST` | `/projects` | Yeni proje olustur |
| `GET` | `/projects/{uuid}` | Proje detayi |
| `PATCH` | `/projects/{uuid}` | Proje guncelle |
| `DELETE` | `/projects/{uuid}` | Proje sil |
| `GET` | `/projects/{uuid}/environments` | Proje ortamlarini listele |
| `POST` | `/projects/{uuid}/environments` | Yeni ortam olustur |

### Uygulama Olusturma

| Method | Path | Kaynak Tipi |
|--------|------|-------------|
| `POST` | `/applications/public` | Public git repo |
| `POST` | `/applications/private-github-app` | GitHub App ile private repo |
| `POST` | `/applications/private-deploy-key` | SSH deploy key ile private repo |
| `POST` | `/applications/dockerfile` | Inline Dockerfile |
| `POST` | `/applications/dockerimage` | Docker registry image |
| `POST` | `/applications/dockercompose` | Docker Compose |

### Uygulama Yonetimi

| Method | Path | Aciklama |
|--------|------|----------|
| `GET` | `/applications` | Tum uygulamalari listele |
| `GET` | `/applications/{uuid}` | Uygulama detayi |
| `PATCH` | `/applications/{uuid}` | Uygulama guncelle |
| `DELETE` | `/applications/{uuid}` | Uygulama sil |
| `GET/POST` | `/applications/{uuid}/start` | Baslat/deploy |
| `GET/POST` | `/applications/{uuid}/restart` | Restart (zero-downtime) |
| `GET/POST` | `/applications/{uuid}/stop` | Durdur |
| `GET` | `/applications/{uuid}/logs` | Container loglari |

### Deploy Tetikleme

| Method | Path | Aciklama |
|--------|------|----------|
| `GET/POST` | `/deploy` | UUID veya tag ile deploy tetikle |
| `GET` | `/deployments` | Aktif deployment'lari listele |
| `GET` | `/deployments/{uuid}` | Deployment detayi |
| `POST` | `/deployments/{uuid}/cancel` | Deployment iptal |
| `GET` | `/deployments/applications/{uuid}` | Uygulama deploy gecmisi |

**Deploy Parametreleri:**
- `uuid` - Uygulama UUID (virgul ile birden fazla)
- `tag` - Tag adi
- `force` - Cache'siz yeniden build
- `pr` - Pull Request ID

### Environment Variables

| Method | Path | Aciklama |
|--------|------|----------|
| `GET` | `/applications/{uuid}/envs` | Env var'lari listele |
| `POST` | `/applications/{uuid}/envs` | Tek env var olustur |
| `PATCH` | `/applications/{uuid}/envs` | Tek env var guncelle |
| `PATCH` | `/applications/{uuid}/envs/bulk` | Toplu olustur/guncelle |
| `DELETE` | `/applications/{uuid}/envs/{env_uuid}` | Env var sil |

### Servisler (Docker Compose / One-Click)

| Method | Path | Aciklama |
|--------|------|----------|
| `GET` | `/services` | Servisleri listele |
| `POST` | `/services` | Servis olustur |
| `GET/POST` | `/services/{uuid}/start` | Servisi baslat |
| `GET/POST` | `/services/{uuid}/stop` | Servisi durdur |
| `GET/POST` | `/services/{uuid}/restart` | Servisi restart et |

### Sunucular

| Method | Path | Aciklama |
|--------|------|----------|
| `GET` | `/servers` | Sunuculari listele |
| `GET` | `/servers/{uuid}` | Sunucu detayi |
| `GET` | `/servers/{uuid}/validate` | Baglanti dogrula |
| `GET` | `/servers/{uuid}/resources` | Sunucudaki kaynaklar |

### Sistem

| Method | Path | Aciklama |
|--------|------|----------|
| `GET` | `/version` | Coolify versiyonu |
| `GET` | `/health` | Saglik kontrolu (auth gereksiz) |

---

## Build Pack Secenekleri

| Deger | Aciklama | Kullanim |
|-------|----------|----------|
| `dockerfile` | Repo'daki Dockerfile kullanir | Tam kontrol, Kuark projeleri icin onerilir |
| `nixpacks` | Otomatik Dockerfile olusturur | Hizli deploy, minimal config |
| `dockercompose` | docker-compose.yml kullanir | Multi-servis mimariler |
| `static` | Statik web sunucu (Nginx/Caddy) | HTML/CSS/JS, SPA, static export |

---

## Dockerfile Sablonlari

### NestJS API (Multi-stage)
```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy package files
COPY package.json pnpm-lock.yaml ./
COPY prisma ./prisma/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Generate Prisma client
RUN pnpm prisma generate

# Build application
RUN pnpm build

# Prune dev dependencies
RUN pnpm prune --prod

# Production stage
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nestjs

# Copy built application
COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/prisma ./prisma
COPY --from=builder --chown=nestjs:nodejs /app/package.json ./

USER nestjs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Prisma migrate + start
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
```

### Next.js Frontend (Standalone)
```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build arguments for environment
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

# Build application (requires output: 'standalone' in next.config)
RUN pnpm build

# Production stage
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy built application
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

CMD ["node", "server.js"]
```

**Not:** `next.config.js` icinde `output: 'standalone'` ayari ZORUNLU:
```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
}
module.exports = nextConfig
```

### BullMQ Worker
```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@latest --activate

COPY package.json pnpm-lock.yaml ./
COPY prisma ./prisma/

RUN pnpm install --frozen-lockfile

COPY . .

RUN pnpm prisma generate
RUN pnpm build
RUN pnpm prune --prod

# Production stage
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 worker

COPY --from=builder --chown=worker:nodejs /app/dist ./dist
COPY --from=builder --chown=worker:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=worker:nodejs /app/prisma ./prisma
COPY --from=builder --chown=worker:nodejs /app/package.json ./

USER worker

# Worker icin port expose YOK
# Health check: process alive kontrolu
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "process.exit(0)" || exit 1

# Worker entrypoint (API ile ayni codebase, farkli baslatma)
CMD ["node", "dist/worker.js"]
```

**Not:** Worker ayni NestJS codebase icerisinde ayri bir entrypoint kullanir. Ornek `src/worker.ts`:
```typescript
import { NestFactory } from '@nestjs/core';
import { WorkerModule } from './worker.module';

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(WorkerModule);
  console.log('Worker started');
}
bootstrap();
```

---

## docker-compose Sablonlari

### Development (docker-compose.yml)
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: ${PROJECT_NAME:-kuark}-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: ${PROJECT_NAME:-kuark}
    ports:
      - '5432:5432'
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U postgres']
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: ${PROJECT_NAME:-kuark}-redis
    restart: unless-stopped
    ports:
      - '6379:6379'
    volumes:
      - redis_data:/data
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 10s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio:latest
    container_name: ${PROJECT_NAME:-kuark}-minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin123
    ports:
      - '9000:9000'
      - '9001:9001'
    volumes:
      - minio_data:/data
    healthcheck:
      test: ['CMD', 'mc', 'ready', 'local']
      interval: 10s
      timeout: 5s
      retries: 5

  minio-init:
    image: minio/mc:latest
    container_name: ${PROJECT_NAME:-kuark}-minio-init
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: >
      /bin/sh -c "
      mc alias set myminio http://minio:9000 minioadmin minioadmin123;
      mc mb myminio/${PROJECT_NAME:-kuark} --ignore-existing;
      mc anonymous set public myminio/${PROJECT_NAME:-kuark};
      exit 0;
      "

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: ${PROJECT_NAME:-kuark}-pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@kuark.com
      PGADMIN_DEFAULT_PASSWORD: admin123
    ports:
      - '5050:80'
    depends_on:
      - postgres
    profiles:
      - tools

volumes:
  postgres_data:
  redis_data:
  minio_data:

networks:
  default:
    name: ${PROJECT_NAME:-kuark}-network
```

### Production (docker-compose.prod.yml)
```yaml
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: apps/api/Dockerfile
    container_name: ${PROJECT_NAME:-kuark}-api
    restart: unless-stopped
    ports:
      - '3001:3000'
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - JWT_SECRET=${JWT_SECRET}
      - JWT_EXPIRES_IN=${JWT_EXPIRES_IN:-1d}
      - S3_ENDPOINT=${S3_ENDPOINT}
      - S3_ACCESS_KEY=${S3_ACCESS_KEY}
      - S3_SECRET_KEY=${S3_SECRET_KEY}
      - S3_BUCKET=${S3_BUCKET}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ['CMD', 'wget', '--no-verbose', '--tries=1', '--spider', 'http://localhost:3000/health']
      interval: 30s
      timeout: 10s
      start_period: 10s
      retries: 3

  web:
    build:
      context: .
      dockerfile: apps/web/Dockerfile
      args:
        - NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
    container_name: ${PROJECT_NAME:-kuark}-web
    restart: unless-stopped
    ports:
      - '3000:3000'
    environment:
      - NODE_ENV=production
    depends_on:
      - api
    healthcheck:
      test: ['CMD', 'wget', '--no-verbose', '--tries=1', '--spider', 'http://localhost:3000/']
      interval: 30s
      timeout: 10s
      start_period: 10s
      retries: 3

  worker:
    build:
      context: .
      dockerfile: apps/api/Dockerfile.worker
    container_name: ${PROJECT_NAME:-kuark}-worker
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ['CMD', 'node', '-e', 'process.exit(0)']
      interval: 30s
      timeout: 10s
      start_period: 5s
      retries: 3

  postgres:
    image: postgres:16-alpine
    container_name: ${PROJECT_NAME:-kuark}-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U ${POSTGRES_USER}']
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: ${PROJECT_NAME:-kuark}-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    healthcheck:
      test: ['CMD', 'redis-cli', '-a', '${REDIS_PASSWORD}', 'ping']
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  redis_data:

networks:
  default:
    name: ${PROJECT_NAME:-kuark}-production
```

---

## Coolify REST API Kullanim Ornekleri

### Proje Olusturma
```bash
# Proje olustur
curl -s -X POST "$COOLIFY_API_URL/projects" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-kuark-project",
    "description": "Kuark monorepo projesi"
  }'
```

### Ortam Olusturma
```bash
# Production ortami olustur
curl -s -X POST "$COOLIFY_API_URL/projects/$PROJECT_UUID/environments" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "production"
  }'
```

### NestJS API Uygulamasi Olusturma (Private GitHub App)
```bash
curl -s -X POST "$COOLIFY_API_URL/applications/private-github-app" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_uuid": "'$PROJECT_UUID'",
    "server_uuid": "'$SERVER_UUID'",
    "environment_name": "production",
    "github_app_uuid": "'$GITHUB_APP_UUID'",
    "git_repository": "org/repo",
    "git_branch": "main",
    "build_pack": "dockerfile",
    "dockerfile_location": "/apps/api/Dockerfile",
    "ports_exposes": "3000",
    "domains": "api.example.com",
    "is_auto_deploy_enabled": true,
    "health_check_enabled": true,
    "health_check_path": "/health",
    "health_check_port": 3000,
    "instant_deploy": false
  }'
```

### Next.js Frontend Uygulamasi Olusturma
```bash
curl -s -X POST "$COOLIFY_API_URL/applications/private-github-app" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_uuid": "'$PROJECT_UUID'",
    "server_uuid": "'$SERVER_UUID'",
    "environment_name": "production",
    "github_app_uuid": "'$GITHUB_APP_UUID'",
    "git_repository": "org/repo",
    "git_branch": "main",
    "build_pack": "dockerfile",
    "dockerfile_location": "/apps/web/Dockerfile",
    "ports_exposes": "3000",
    "domains": "app.example.com",
    "is_auto_deploy_enabled": true,
    "instant_deploy": false
  }'
```

### BullMQ Worker Uygulamasi Olusturma
```bash
curl -s -X POST "$COOLIFY_API_URL/applications/private-github-app" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_uuid": "'$PROJECT_UUID'",
    "server_uuid": "'$SERVER_UUID'",
    "environment_name": "production",
    "github_app_uuid": "'$GITHUB_APP_UUID'",
    "git_repository": "org/repo",
    "git_branch": "main",
    "build_pack": "dockerfile",
    "dockerfile_location": "/apps/api/Dockerfile.worker",
    "ports_exposes": "",
    "is_auto_deploy_enabled": true,
    "instant_deploy": false
  }'
```

### Deploy Tetikleme
```bash
# Tek uygulama deploy
curl -s -X GET "$COOLIFY_API_URL/deploy?uuid=$APP_UUID" \
  -H "Authorization: Bearer $COOLIFY_TOKEN"

# Force rebuild (cache'siz)
curl -s -X GET "$COOLIFY_API_URL/deploy?uuid=$APP_UUID&force=true" \
  -H "Authorization: Bearer $COOLIFY_TOKEN"

# Birden fazla uygulama ayni anda deploy
curl -s -X GET "$COOLIFY_API_URL/deploy?uuid=$API_UUID,$WEB_UUID,$WORKER_UUID" \
  -H "Authorization: Bearer $COOLIFY_TOKEN"

# Tag ile deploy (tum tag'li uygulamalar)
curl -s -X GET "$COOLIFY_API_URL/deploy?tag=production" \
  -H "Authorization: Bearer $COOLIFY_TOKEN"
```

### Deployment Durumu Sorgulama
```bash
# Son 5 deployment
curl -s -X GET "$COOLIFY_API_URL/deployments/applications/$APP_UUID?skip=0&take=5" \
  -H "Authorization: Bearer $COOLIFY_TOKEN"

# Belirli deployment detayi
curl -s -X GET "$COOLIFY_API_URL/deployments/$DEPLOYMENT_UUID" \
  -H "Authorization: Bearer $COOLIFY_TOKEN"
```

### Environment Variable Yonetimi
```bash
# Env var listele
curl -s -X GET "$COOLIFY_API_URL/applications/$APP_UUID/envs" \
  -H "Authorization: Bearer $COOLIFY_TOKEN"

# Tek env var ekle
curl -s -X POST "$COOLIFY_API_URL/applications/$APP_UUID/envs" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "DATABASE_URL",
    "value": "postgresql://user:pass@host:5432/db",
    "is_build_time": false,
    "is_preview": false
  }'

# Toplu env var guncelle
curl -s -X PATCH "$COOLIFY_API_URL/applications/$APP_UUID/envs/bulk" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": [
      {"key": "NODE_ENV", "value": "production", "is_build_time": false},
      {"key": "DATABASE_URL", "value": "postgresql://...", "is_build_time": false},
      {"key": "REDIS_URL", "value": "redis://...", "is_build_time": false},
      {"key": "JWT_SECRET", "value": "your-secret", "is_build_time": false}
    ]
  }'
```

### Container Log Okuma
```bash
# Son 100 satir log
curl -s -X GET "$COOLIFY_API_URL/applications/$APP_UUID/logs?tail=100" \
  -H "Authorization: Bearer $COOLIFY_TOKEN"

# Son 1 saat loglari
curl -s -X GET "$COOLIFY_API_URL/applications/$APP_UUID/logs?since=3600" \
  -H "Authorization: Bearer $COOLIFY_TOKEN"
```

---

## Coolify Git Entegrasyonu

### GitHub App Entegrasyonu (Onerilen)

1. **Coolify Dashboard > Settings > GitHub Apps**
2. **"Add GitHub App"** tikla
3. GitHub'a yonlendirilirsin, App'i olustur/yetkilendir
4. Coolify'a donunce **GitHub App UUID** alinir

### Uygulama Olusturma Sonrasi Auto-Deploy

Coolify'da uygulama olusturulurken:
- `is_auto_deploy_enabled: true` ayari yapilir
- GitHub'dan push geldiginde Coolify otomatik deploy eder
- Branch bazli: `main` → production, `develop` → development

### Manuel Webhook (Diger Git Provider'lar)

GitLab, Bitbucket, Gitea, Forgejo icin:

1. Coolify'da uygulama ayarlari > **Webhooks** sekmesi
2. **Deploy Webhook URL** kopyala:
   ```
   https://coolify.example.com/api/v1/deploy?uuid=APP_UUID
   ```
3. Git provider webhook ayarlarina ekle
4. Push event'lerini sec
5. Webhook secret ayarla (opsiyonel):
   ```bash
   curl -s -X PATCH "$COOLIFY_API_URL/applications/$APP_UUID" \
     -H "Authorization: Bearer $COOLIFY_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"manual_webhook_secret_gitlab": "your-webhook-secret"}'
   ```

### Branch Stratejisi

| Branch | Coolify Ortam | Domain | Auto-Deploy |
|--------|---------------|--------|-------------|
| `main` | production | app.example.com | Evet |
| `develop` | development | dev.app.example.com | Evet (istege bagli) |

---

## Environment Yonetimi

### Ortak Degiskenler (Tum Servisler)

```bash
# Database
DATABASE_URL=postgresql://user:password@host:5432/dbname

# Redis
REDIS_URL=redis://:password@host:6379

# JWT
JWT_SECRET=<strong-random-secret>
JWT_EXPIRES_IN=1d
```

### API-Ozel Degiskenler

```bash
NODE_ENV=production
PORT=3000

# Storage (S3/MinIO)
S3_ENDPOINT=https://s3.example.com
S3_ACCESS_KEY=access-key
S3_SECRET_KEY=secret-key
S3_BUCKET=bucket-name
```

### Web-Ozel Degiskenler (Build-time)

```bash
# Bu degiskenler build sirasinda gerekli (is_build_time: true)
NEXT_PUBLIC_API_URL=https://api.example.com
NEXT_PUBLIC_APP_URL=https://app.example.com
```

### Worker-Ozel Degiskenler

```bash
NODE_ENV=production
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
# Worker-specific
WORKER_CONCURRENCY=5
WORKER_MAX_RETRIES=3
```

### Dev vs Prod Farklari

| Degisken | Development | Production |
|----------|-------------|------------|
| `NODE_ENV` | development | production |
| `DATABASE_URL` | localhost:5432 | Coolify managed / external |
| `REDIS_URL` | localhost:6379 | Coolify managed / external |
| `JWT_SECRET` | dev-secret | Strong random (32+ char) |
| `NEXT_PUBLIC_API_URL` | http://localhost:3001 | https://api.example.com |

---

## Coolify Uzerinde Kuark Projesi Kurulumu (Adim Adim)

### 1. Proje ve Ortam Olustur
```bash
# Proje olustur
PROJECT=$(curl -s -X POST "$COOLIFY_API_URL/projects" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-project"}')

PROJECT_UUID=$(echo $PROJECT | jq -r '.uuid')

# Production ortami olustur
curl -s -X POST "$COOLIFY_API_URL/projects/$PROJECT_UUID/environments" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "production"}'
```

### 2. Veritabani ve Redis (Coolify One-Click veya Harici)

Coolify Dashboard uzerinden:
- **New Resource > Database > PostgreSQL 16** olustur
- **New Resource > Database > Redis 7** olustur
- Connection string'leri al

### 3. API Servisi Olustur
```bash
curl -s -X POST "$COOLIFY_API_URL/applications/private-github-app" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_uuid": "'$PROJECT_UUID'",
    "server_uuid": "'$SERVER_UUID'",
    "environment_name": "production",
    "github_app_uuid": "'$GITHUB_APP_UUID'",
    "git_repository": "org/repo",
    "git_branch": "main",
    "build_pack": "dockerfile",
    "dockerfile_location": "/apps/api/Dockerfile",
    "ports_exposes": "3000",
    "domains": "api.example.com",
    "is_auto_deploy_enabled": true,
    "health_check_enabled": true,
    "health_check_path": "/health"
  }'
```

### 4. Web Servisi Olustur
```bash
curl -s -X POST "$COOLIFY_API_URL/applications/private-github-app" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_uuid": "'$PROJECT_UUID'",
    "server_uuid": "'$SERVER_UUID'",
    "environment_name": "production",
    "github_app_uuid": "'$GITHUB_APP_UUID'",
    "git_repository": "org/repo",
    "git_branch": "main",
    "build_pack": "dockerfile",
    "dockerfile_location": "/apps/web/Dockerfile",
    "ports_exposes": "3000",
    "domains": "app.example.com",
    "is_auto_deploy_enabled": true
  }'
```

### 5. Worker Servisi Olustur
```bash
curl -s -X POST "$COOLIFY_API_URL/applications/private-github-app" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_uuid": "'$PROJECT_UUID'",
    "server_uuid": "'$SERVER_UUID'",
    "environment_name": "production",
    "github_app_uuid": "'$GITHUB_APP_UUID'",
    "git_repository": "org/repo",
    "git_branch": "main",
    "build_pack": "dockerfile",
    "dockerfile_location": "/apps/api/Dockerfile.worker",
    "ports_exposes": "",
    "is_auto_deploy_enabled": true
  }'
```

### 6. Environment Variable'lari Ayarla
```bash
# API servisi icin
curl -s -X PATCH "$COOLIFY_API_URL/applications/$API_UUID/envs/bulk" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": [
      {"key": "NODE_ENV", "value": "production", "is_build_time": false},
      {"key": "DATABASE_URL", "value": "postgresql://...", "is_build_time": false},
      {"key": "REDIS_URL", "value": "redis://...", "is_build_time": false},
      {"key": "JWT_SECRET", "value": "your-secret", "is_build_time": false},
      {"key": "JWT_EXPIRES_IN", "value": "1d", "is_build_time": false}
    ]
  }'

# Web servisi icin (build-time env'ler)
curl -s -X PATCH "$COOLIFY_API_URL/applications/$WEB_UUID/envs/bulk" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": [
      {"key": "NEXT_PUBLIC_API_URL", "value": "https://api.example.com", "is_build_time": true},
      {"key": "NEXT_PUBLIC_APP_URL", "value": "https://app.example.com", "is_build_time": true}
    ]
  }'
```

### 7. Deploy Tetikle
```bash
# Tum servisleri deploy et
curl -s -X GET "$COOLIFY_API_URL/deploy?uuid=$API_UUID,$WEB_UUID,$WORKER_UUID" \
  -H "Authorization: Bearer $COOLIFY_TOKEN"
```

---

## Otomasyon Script'i

### deploy.sh - Hizli Deploy Script
```bash
#!/bin/bash
set -euo pipefail

# Coolify deploy script for Kuark projects
# Usage: ./deploy.sh [api|web|worker|all] [--force]

COOLIFY_API_URL="${COOLIFY_API_URL:?COOLIFY_API_URL required}"
COOLIFY_TOKEN="${COOLIFY_TOKEN:?COOLIFY_TOKEN required}"

# Servis UUID'leri (.env dosyasindan veya parametre olarak)
API_UUID="${COOLIFY_API_UUID:-}"
WEB_UUID="${COOLIFY_WEB_UUID:-}"
WORKER_UUID="${COOLIFY_WORKER_UUID:-}"

SERVICE="${1:-all}"
FORCE_FLAG=""
[[ "${2:-}" == "--force" ]] && FORCE_FLAG="&force=true"

deploy() {
  local uuid=$1
  local name=$2
  echo "Deploying $name..."

  RESPONSE=$(curl -s -X GET "$COOLIFY_API_URL/deploy?uuid=$uuid$FORCE_FLAG" \
    -H "Authorization: Bearer $COOLIFY_TOKEN")

  echo "$RESPONSE" | jq .
}

check_status() {
  local uuid=$1
  local name=$2
  echo "Status for $name:"

  curl -s -X GET "$COOLIFY_API_URL/deployments/applications/$uuid?take=1" \
    -H "Authorization: Bearer $COOLIFY_TOKEN" | jq '.[0] | {status, created_at, git_commit_sha}'
}

case "$SERVICE" in
  api)
    deploy "$API_UUID" "API"
    ;;
  web)
    deploy "$WEB_UUID" "Web"
    ;;
  worker)
    deploy "$WORKER_UUID" "Worker"
    ;;
  all)
    deploy "$API_UUID" "API"
    deploy "$WEB_UUID" "Web"
    deploy "$WORKER_UUID" "Worker"
    ;;
  status)
    check_status "$API_UUID" "API"
    check_status "$WEB_UUID" "Web"
    check_status "$WORKER_UUID" "Worker"
    ;;
  *)
    echo "Usage: $0 [api|web|worker|all|status] [--force]"
    exit 1
    ;;
esac
```

---

## Validation Checklist

### Deploy Oncesi Kontrol Listesi

**Dockerfile:**
- [ ] Multi-stage build kullaniliyor
- [ ] Non-root user tanimli
- [ ] Health check konfigurasyonu var
- [ ] .dockerignore dosyasi mevcut
- [ ] Prisma generate build asamasinda calistiriliyor
- [ ] pnpm prune --prod ile dev dependency'ler temizleniyor

**Coolify Konfigurasyonu:**
- [ ] Proje ve ortam olusturuldu
- [ ] Uygulama dogru build pack ile olusturuldu (dockerfile)
- [ ] Git repo ve branch bagli
- [ ] Auto-deploy aktif (is_auto_deploy_enabled)
- [ ] Domain atanmis ve SSL aktif
- [ ] Health check path ve port dogru

**Environment Variables:**
- [ ] DATABASE_URL ayarli
- [ ] REDIS_URL ayarli
- [ ] JWT_SECRET guclu ve unique
- [ ] NODE_ENV=production
- [ ] NEXT_PUBLIC_* degiskenleri is_build_time: true
- [ ] Hassas bilgiler is_shown_once: true

**Network & Security:**
- [ ] Port mapping dogru (API: 3000, Web: 3000)
- [ ] Worker icin port expose yok
- [ ] Servisler arasi network erisimi var
- [ ] SSL sertifikasi otomatik (Traefik/Let's Encrypt)

**Post-Deploy:**
- [ ] Health check endpoint cevap veriyor
- [ ] Prisma migration basarili
- [ ] Container loglari temiz
- [ ] API endpoint'leri calisiyor
- [ ] Frontend sayfalari yukluyor
- [ ] Worker job'lari isleniyor

### Hata Kodlari

| HTTP Kodu | Anlami | Cozum |
|-----------|--------|-------|
| 400 | Gecersiz istek/token | Token ve parametreleri kontrol et |
| 401 | Kimlik dogrulanamadi | Token gecerliligi kontrol et |
| 403 | Yetersiz yetki | Token yetkilerini kontrol et |
| 404 | Kaynak bulunamadi | UUID'yi kontrol et |
| 409 | Domain cakismasi | `force_domain_override: true` kullan |
| 422 | Validasyon hatasi | Zorunlu alanlari kontrol et |
| 429 | Rate limit | Deploy kuyrugu dolu, bekle |

---

## .dockerignore Sablonu

```
node_modules
.next
dist
.git
.gitignore
*.md
.env*
.swarm
.vscode
.idea
coverage
test
tests
__tests__
*.test.ts
*.spec.ts
docker-compose*.yml
.dockerignore
Dockerfile*
```

---

## Iletisim

### ← Tum Takimlardan
- Deployment talepleri
- Altyapi gereksinimleri

### → Security Engineer
- SSL/TLS konfigurasyonu
- Network izolasyonu

### → Project Manager
- Deploy durumu raporlari
- Altyapi blocker'lari

---

## Kisilik

- **Otomasyon Odakli**: Tekrarli islemleri scriptleştir
- **Guvenilir**: Production-ready, test edilmis
- **Izlenebilir**: Loglar, health check'ler, monitoring
- **Hizli**: Optimize build'ler, cache stratejisi
