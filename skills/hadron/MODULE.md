# Hadron Skill Module

> Hadron (Dokploy fork) self-hosted PaaS ile deploy, servis yonetimi ve otomasyon

## Triggers

- hadron, deploy hadron, hadron deploy
- hadron servis, hadron uygulama
- "hadron'a deploy et", "hadron kur", "hadron servisi olustur"

## Technology Stack

```
Hadron (Dokploy Fork - Self-hosted PaaS)
├── REST API (x-api-key auth, tRPC-based)
├── Git entegrasyonu (GitHub, GitLab, Bitbucket, Gitea, Custom Git)
├── Build Packs: Dockerfile, Nixpacks, Railpack, Buildpacks, Static
├── Reverse Proxy: Traefik (otomatik SSL via Let's Encrypt)
├── Container Orchestration: Docker Swarm / Docker Compose
├── Database Yonetimi: PostgreSQL, MySQL, MariaDB, MongoDB, Redis
└── Monitoring: CPU, Memory, Disk, Network metrikleri
```

---

## API Kimlik Dogrulama

### API Key Olusturma
1. Hadron dashboard > **Settings** > **Profile** > **API/CLI**
2. **Generate** butonu ile API key olustur
3. Key sadece bir kez gosterilir - hemen kopyala

### Kullanim
```bash
# Tum isteklerde x-api-key header gerekli
curl -s -X GET "https://hadron.example.com/api/project.all" \
  -H "accept: application/json" \
  -H "x-api-key: YOUR-API-KEY"
```

### Swagger Erisimi
```
https://hadron.example.com/swagger
```

### Ortam Degiskenleri (Kuark Projesi)
```bash
# .env veya CI/CD secrets
HADRON_API_URL=https://hadron.example.com/api
HADRON_API_KEY=your-api-key
HADRON_SERVER_ID=server-id        # Remote server ise
HADRON_PROJECT_ID=project-id
```

---

## API Endpoint Referansi

### API Pattern
Hadron (Dokploy) tRPC tabanlidir. REST endpoint'leri su formatta:
- **Queries (oku):** `GET /api/{router}.{procedure}`
- **Mutations (yaz):** `POST /api/{router}.{procedure}`

### Projeler

| Method | Endpoint | Parametreler | Aciklama |
|--------|----------|-------------|----------|
| `POST` | `/project.create` | name*, description? | Yeni proje olustur |
| `GET` | `/project.one` | projectId* | Proje detayi |
| `GET` | `/project.all` | - | Tum projeler |
| `POST` | `/project.remove` | projectId* | Proje sil |
| `POST` | `/project.update` | projectId*, name?, description? | Proje guncelle |

### Uygulama Olusturma ve Yonetim

| Method | Endpoint | Parametreler | Aciklama |
|--------|----------|-------------|----------|
| `POST` | `/application.create` | name*, environmentId*, appName?, serverId? | Uygulama olustur |
| `GET` | `/application.one` | applicationId* | Uygulama detayi |
| `POST` | `/application.update` | applicationId* + diger alanlar | Uygulama guncelle |
| `POST` | `/application.delete` | applicationId* | Uygulama sil |
| `POST` | `/application.deploy` | applicationId*, title?, description? | Deploy tetikle |
| `POST` | `/application.redeploy` | applicationId* | Yeniden deploy |
| `POST` | `/application.stop` | applicationId* | Durdur |
| `POST` | `/application.start` | applicationId* | Baslat |
| `POST` | `/application.reload` | applicationId*, appName* | Reload |
| `POST` | `/application.killBuild` | applicationId* | Build iptal |
| `POST` | `/application.cancelDeployment` | applicationId* | Deploy iptal |

### Git Provider Konfigurasyonu

| Method | Endpoint | Kaynak Tipi |
|--------|----------|-------------|
| `POST` | `/application.saveGithubProvider` | GitHub repo (repository, branch, owner, githubId) |
| `POST` | `/application.saveGitlabProvider` | GitLab repo |
| `POST` | `/application.saveBitbucketProvider` | Bitbucket repo |
| `POST` | `/application.saveGiteaProvider` | Gitea repo |
| `POST` | `/application.saveGitProvider` | Custom Git URL (customGitUrl, customGitBranch) |
| `POST` | `/application.saveDockerProvider` | Docker image (dockerImage, registryUrl) |
| `POST` | `/application.disconnectGitProvider` | Git baglantisini kopar |

### Build Konfigurasyonu

| Method | Endpoint | Parametreler |
|--------|----------|-------------|
| `POST` | `/application.saveBuildType` | applicationId*, buildType*, dockerfile?, dockerContextPath?, dockerBuildStage? |

**Build Type'lar:**

| Deger | Aciklama | Kullanim |
|-------|----------|----------|
| `dockerfile` | Repo'daki Dockerfile kullanir | Tam kontrol, Kuark projeleri icin onerilir |
| `nixpacks` | Otomatik Dockerfile olusturur | Hizli deploy, minimal config |
| `railpack` | Nixpacks'in yeni versiyonu | Node.js, Python, Go, PHP |
| `heroku_buildpacks` | Heroku buildpack'leri | Heroku uyumlu projeler |
| `paketo_buildpacks` | Cloud-native buildpack'ler | Modern standartlar |
| `static` | Nginx ile statik sunucu | HTML/CSS/JS, SPA |

### Environment Variable Yonetimi

| Method | Endpoint | Parametreler |
|--------|----------|-------------|
| `POST` | `/application.saveEnvironment` | applicationId*, env*, buildArgs*, buildSecrets*, createEnvFile* |

**Variable Referanslari:**
- `${{project.VAR}}` - Proje seviyesi degisken
- `${{environment.VAR}}` - Ortam seviyesi degisken
- `${{VAR}}` - Servis seviyesi degisken

### Docker Compose Servisleri

| Method | Endpoint | Parametreler |
|--------|----------|-------------|
| `POST` | `/compose.create` | name*, environmentId*, composeType?, composeFile? |
| `GET` | `/compose.one` | composeId* |
| `POST` | `/compose.update` | composeId*, composeFile?, sourceType?, branch? |
| `POST` | `/compose.deploy` | composeId* |
| `POST` | `/compose.redeploy` | composeId* |
| `POST` | `/compose.stop` | composeId* |
| `POST` | `/compose.start` | composeId* |
| `POST` | `/compose.delete` | composeId*, deleteVolumes* |
| `GET` | `/compose.loadServices` | composeId*, type(cache/fetch) |

### Domain ve SSL

| Method | Endpoint | Parametreler |
|--------|----------|-------------|
| `POST` | `/domain.create` | host*, applicationId?, composeId?, certificateType?, port?, https? |
| `GET` | `/domain.byApplicationId` | applicationId* |
| `POST` | `/domain.update` | domainId*, host* + opsiyonel alanlar |
| `POST` | `/domain.delete` | domainId* |
| `POST` | `/domain.generateDomain` | appName*, serverId? |
| `POST` | `/domain.validateDomain` | domain*, serverIp? |

**Certificate Type'lar:** `"letsencrypt"`, `"none"`, `"custom"`

### Veritabani Yonetimi

Her veritabani tipi (postgres, mysql, mariadb, mongo, redis) ayni pattern'i takip eder:

| Method | Endpoint Pattern | Aciklama |
|--------|-----------------|----------|
| `POST` | `/{db}.create` | Veritabani olustur |
| `GET` | `/{db}.one` | Detay goruntule |
| `POST` | `/{db}.start` | Baslat |
| `POST` | `/{db}.stop` | Durdur |
| `POST` | `/{db}.deploy` | Deploy et |
| `POST` | `/{db}.rebuild` | Yeniden olustur |
| `POST` | `/{db}.remove` | Sil |
| `POST` | `/{db}.saveEnvironment` | Env var ayarla |
| `POST` | `/{db}.saveExternalPort` | Dis port ayarla |

### Sunucu Yonetimi

| Method | Endpoint | Parametreler |
|--------|----------|-------------|
| `POST` | `/server.create` | name*, ipAddress*, port*, username*, sshKeyId*, serverType* |
| `GET` | `/server.one` | serverId* |
| `GET` | `/server.all` | - |
| `POST` | `/server.setup` | serverId* |
| `GET` | `/server.validate` | serverId* |
| `POST` | `/server.remove` | serverId* |

### Deployment Takibi

| Method | Endpoint | Parametreler |
|--------|----------|-------------|
| `GET` | `/deployment.all` | applicationId* |
| `GET` | `/deployment.allByCompose` | composeId* |
| `GET` | `/deployment.allByServer` | serverId* |
| `POST` | `/deployment.killProcess` | deploymentId* |

### Yedekleme

| Method | Endpoint | Parametreler |
|--------|----------|-------------|
| `POST` | `/backup.create` | schedule*, prefix*, destinationId*, database*, databaseType* |
| `POST` | `/backup.manualBackupPostgres` | backupId* |
| `POST` | `/backup.manualBackupMySql` | backupId* |
| `POST` | `/backup.manualBackupMongo` | backupId* |
| `POST` | `/backup.remove` | backupId* |

### Sertifika Yonetimi

| Method | Endpoint | Parametreler |
|--------|----------|-------------|
| `POST` | `/certificates.create` | sertifika verileri |
| `GET` | `/certificates.all` | - |
| `POST` | `/certificates.remove` | certificateId* |

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

RUN corepack enable && corepack prepare pnpm@latest --activate

COPY package.json pnpm-lock.yaml ./

RUN pnpm install --frozen-lockfile

COPY . .

# Build arguments for environment
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

# Build (requires output: 'standalone' in next.config)
RUN pnpm build

# Production stage
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

CMD ["node", "server.js"]
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
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "process.exit(0)" || exit 1

CMD ["node", "dist/worker.js"]
```

---

## Hadron REST API Kullanim Ornekleri

### Proje Olusturma
```bash
# Proje olustur
curl -s -X POST "$HADRON_API_URL/project.create" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-kuark-project",
    "description": "Kuark monorepo projesi"
  }'
```

### NestJS API Uygulamasi Olusturma
```bash
# 1. Uygulama olustur
APP_RESPONSE=$(curl -s -X POST "$HADRON_API_URL/application.create" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "kuark-api",
    "environmentId": "'$ENV_ID'",
    "description": "Kuark NestJS API",
    "serverId": "'$SERVER_ID'"
  }')

APP_ID=$(echo $APP_RESPONSE | jq -r '.applicationId')

# 2. Git provider ayarla (GitHub)
curl -s -X POST "$HADRON_API_URL/application.saveGithubProvider" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "applicationId": "'$APP_ID'",
    "repository": "org/repo",
    "branch": "main",
    "owner": "org",
    "buildPath": "/apps/api",
    "githubId": "'$GITHUB_ID'"
  }'

# 3. Build type ayarla (Dockerfile)
curl -s -X POST "$HADRON_API_URL/application.saveBuildType" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "applicationId": "'$APP_ID'",
    "buildType": "dockerfile",
    "dockerfile": "apps/api/Dockerfile",
    "dockerContextPath": "."
  }'

# 4. Environment variable'lari ayarla
curl -s -X POST "$HADRON_API_URL/application.saveEnvironment" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "applicationId": "'$APP_ID'",
    "env": "NODE_ENV=production\nDATABASE_URL=postgresql://user:pass@host:5432/db\nREDIS_URL=redis://:password@host:6379\nJWT_SECRET=your-strong-secret\nJWT_EXPIRES_IN=1d",
    "buildArgs": "",
    "buildSecrets": "",
    "createEnvFile": false
  }'

# 5. Domain ayarla
curl -s -X POST "$HADRON_API_URL/domain.create" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "host": "api.example.com",
    "applicationId": "'$APP_ID'",
    "port": 3000,
    "https": true,
    "certificateType": "letsencrypt"
  }'

# 6. Deploy
curl -s -X POST "$HADRON_API_URL/application.deploy" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "applicationId": "'$APP_ID'"
  }'
```

### Deploy Tetikleme
```bash
# Tek uygulama deploy
curl -s -X POST "$HADRON_API_URL/application.deploy" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"applicationId": "'$APP_ID'"}'

# Redeploy (mevcut imajdan)
curl -s -X POST "$HADRON_API_URL/application.redeploy" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"applicationId": "'$APP_ID'"}'
```

---

## Veritabani Olusturma

### PostgreSQL
```bash
curl -s -X POST "$HADRON_API_URL/postgres.create" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "kuark-db",
    "databaseName": "kuark",
    "databaseUser": "kuark_user",
    "databasePassword": "strong-password",
    "environmentId": "'$ENV_ID'"
  }'
```

### Redis
```bash
curl -s -X POST "$HADRON_API_URL/redis.create" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "kuark-redis",
    "databasePassword": "redis-password",
    "environmentId": "'$ENV_ID'"
  }'
```

---

## Git Entegrasyonu ve Auto-Deploy

### GitHub Entegrasyonu
1. Hadron Dashboard > **Git Providers** > GitHub
2. GitHub App olustur veya mevcut App'i bagla
3. Uygulama olusturulurken githubId belirt
4. Auto-deploy: Push event'lerinde otomatik deploy

### Webhook ile Manuel Entegrasyon
```bash
curl -s -X POST "$HADRON_API_URL/application.saveGitProvider" \
  -H "x-api-key: $HADRON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "applicationId": "'$APP_ID'",
    "customGitUrl": "https://github.com/org/repo.git",
    "customGitBranch": "main",
    "customGitBuildPath": "/apps/api"
  }'
```

### Branch Stratejisi

| Branch | Hadron Ortam | Domain | Auto-Deploy |
|--------|-------------|--------|-------------|
| `main` | production | app.example.com | Evet |
| `develop` | staging | staging.app.example.com | Evet |

---

## Environment Yonetimi

### Ortak Degiskenler (Tum Servisler)
```bash
DATABASE_URL=postgresql://user:password@host:5432/dbname
REDIS_URL=redis://:password@host:6379
JWT_SECRET=<strong-random-secret>
JWT_EXPIRES_IN=1d
```

### API-Ozel Degiskenler
```bash
NODE_ENV=production
PORT=3000
S3_ENDPOINT=https://s3.example.com
S3_ACCESS_KEY=access-key
S3_SECRET_KEY=secret-key
S3_BUCKET=bucket-name
```

### Web-Ozel Degiskenler (Build-time)
```bash
# buildArgs alaninda verilmeli
NEXT_PUBLIC_API_URL=https://api.example.com
NEXT_PUBLIC_APP_URL=https://app.example.com
```

---

## Otomasyon Script'i

### deploy.sh - Hizli Deploy Script
```bash
#!/bin/bash
set -euo pipefail

# Hadron deploy script for Kuark projects
# Usage: ./deploy.sh [api|web|worker|all|status]

HADRON_API_URL="${HADRON_API_URL:?HADRON_API_URL required}"
HADRON_API_KEY="${HADRON_API_KEY:?HADRON_API_KEY required}"

API_ID="${HADRON_API_ID:-}"
WEB_ID="${HADRON_WEB_ID:-}"
WORKER_ID="${HADRON_WORKER_ID:-}"

SERVICE="${1:-all}"

deploy() {
  local app_id=$1
  local name=$2
  echo "Deploying $name..."
  curl -s -X POST "$HADRON_API_URL/application.deploy" \
    -H "x-api-key: $HADRON_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"applicationId": "'$app_id'"}' | jq .
}

check_status() {
  local app_id=$1
  local name=$2
  echo "Status for $name:"
  curl -s -X GET "$HADRON_API_URL/deployment.all?applicationId=$app_id" \
    -H "x-api-key: $HADRON_API_KEY" | jq '.[0] | {status, createdAt}'
}

case "$SERVICE" in
  api)     deploy "$API_ID" "API" ;;
  web)     deploy "$WEB_ID" "Web" ;;
  worker)  deploy "$WORKER_ID" "Worker" ;;
  all)
    deploy "$API_ID" "API"
    deploy "$WEB_ID" "Web"
    deploy "$WORKER_ID" "Worker"
    ;;
  status)
    check_status "$API_ID" "API"
    check_status "$WEB_ID" "Web"
    check_status "$WORKER_ID" "Worker"
    ;;
  *)
    echo "Usage: $0 [api|web|worker|all|status]"
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

**Hadron Konfigurasyonu:**
- [ ] Proje olusturuldu
- [ ] Uygulama dogru build type ile olusturuldu (dockerfile)
- [ ] Git repo ve branch bagli
- [ ] Domain atanmis ve SSL aktif (letsencrypt)
- [ ] Health check dogru

**Environment Variables:**
- [ ] DATABASE_URL ayarli
- [ ] REDIS_URL ayarli
- [ ] JWT_SECRET guclu ve unique
- [ ] NODE_ENV=production
- [ ] NEXT_PUBLIC_* degiskenleri buildArgs'ta

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
| 400 | Gecersiz istek | Parametreleri kontrol et |
| 401 | Kimlik dogrulanamadi | API key gecerliligi kontrol et |
| 403 | Yetersiz yetki | API key yetkilerini kontrol et |
| 404 | Kaynak bulunamadi | ID'yi kontrol et |
| 409 | Cakisma | Kaynak zaten mevcut |
| 422 | Validasyon hatasi | Zorunlu alanlari kontrol et |

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

### <- Tum Takimlardan
- Deployment talepleri
- Altyapi gereksinimleri

### -> Security Engineer
- SSL/TLS konfigurasyonu
- Network izolasyonu

### -> Project Manager
- Deploy durumu raporlari
- Altyapi blocker'lari

---

## Kisilik

- **Otomasyon Odakli**: Tekrarli islemleri scriptlestir
- **Guvenilir**: Production-ready, test edilmis
- **Izlenebilir**: Loglar, health check'ler, monitoring
- **Hizli**: Optimize build'ler, cache stratejisi
