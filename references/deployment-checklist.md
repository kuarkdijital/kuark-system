# Kuark Deployment Checklist

> Railway + Docker deployment guide

## Pre-Deployment Checklist

### Code Quality
- [ ] All TypeScript errors resolved (`npx tsc --noEmit`)
- [ ] All tests passing (`pnpm test`)
- [ ] No lint errors (`pnpm lint`)
- [ ] Prisma schema valid (`npx prisma validate`)
- [ ] No console.log in production code
- [ ] No TODO/FIXME comments blocking release

### Security
- [ ] All secrets in environment variables
- [ ] No hardcoded credentials
- [ ] API keys not in codebase
- [ ] .env files in .gitignore
- [ ] CORS configured properly
- [ ] Rate limiting enabled
- [ ] Helmet middleware active
- [ ] JWT secrets are strong (32+ chars)

### Database
- [ ] Migrations tested locally
- [ ] Seed data prepared (if needed)
- [ ] Indexes on frequently queried columns
- [ ] organizationId indexed on all tables
- [ ] Connection pooling configured

### API
- [ ] All endpoints documented (Swagger)
- [ ] Health endpoint working (`/health`)
- [ ] Error responses follow standard format
- [ ] Pagination on list endpoints
- [ ] Request validation on all inputs

### Frontend
- [ ] Build completes without errors
- [ ] Environment variables set for build
- [ ] Assets optimized (images, fonts)
- [ ] Loading states implemented
- [ ] Error boundaries in place

---

## Railway Deployment

### Initial Setup

1. **Create Railway Project**
   ```bash
   # Install Railway CLI
   npm install -g @railway/cli

   # Login
   railway login

   # Create project
   railway init
   ```

2. **Add Services**
   - PostgreSQL (from Railway template)
   - Redis (from Railway template)
   - API service (from GitHub repo)
   - Web service (from GitHub repo)

### Environment Variables

#### API Service
```env
# Database (auto-linked from Railway PostgreSQL)
DATABASE_URL=${{Postgres.DATABASE_URL}}

# Redis (auto-linked from Railway Redis)
REDIS_URL=${{Redis.REDIS_URL}}

# App
NODE_ENV=production
PORT=3000
API_VERSION=v1

# JWT
JWT_SECRET=<generate-strong-secret>
JWT_EXPIRES_IN=1d

# CORS
ALLOWED_ORIGINS=https://app.kuark.com

# Storage (if using external S3)
S3_ENDPOINT=<endpoint>
S3_ACCESS_KEY=<access-key>
S3_SECRET_KEY=<secret-key>
S3_BUCKET=kuark-production
S3_REGION=eu-west-1
```

#### Web Service
```env
# API
NEXT_PUBLIC_API_URL=https://api.kuark.com

# App
NEXT_PUBLIC_APP_URL=https://app.kuark.com
```

### Railway Configuration Files

#### railway.json (API)
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "pnpm prisma migrate deploy && node dist/main.js",
    "healthcheckPath": "/health",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
```

#### nixpacks.toml (API)
```toml
[phases.setup]
nixPkgs = ["nodejs-20_x"]

[phases.install]
cmds = ["corepack enable", "corepack prepare pnpm@latest --activate", "pnpm install --frozen-lockfile"]

[phases.build]
cmds = ["pnpm prisma generate", "pnpm build"]

[start]
cmd = "pnpm prisma migrate deploy && node dist/main.js"
```

#### railway.json (Web)
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "healthcheckPath": "/api/health",
    "healthcheckTimeout": 300
  }
}
```

### Deploy Commands
```bash
# Deploy specific service
railway up --service api
railway up --service web

# Deploy all
railway up
```

---

## Docker Deployment

### Build Images
```bash
# Build API
docker build -f apps/api/Dockerfile -t kuark-api:latest .

# Build Web
docker build -f apps/web/Dockerfile \
  --build-arg NEXT_PUBLIC_API_URL=https://api.kuark.com \
  -t kuark-web:latest .
```

### Push to Registry
```bash
# Tag for registry
docker tag kuark-api:latest registry.example.com/kuark-api:latest
docker tag kuark-web:latest registry.example.com/kuark-web:latest

# Push
docker push registry.example.com/kuark-api:latest
docker push registry.example.com/kuark-web:latest
```

### Production docker-compose
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  api:
    image: registry.example.com/kuark-api:latest
    restart: always
    environment:
      NODE_ENV: production
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      JWT_SECRET: ${JWT_SECRET}
    ports:
      - '3001:3000'
    healthcheck:
      test: ['CMD', 'wget', '--spider', 'http://localhost:3000/health']
      interval: 30s
      timeout: 10s
      retries: 3

  web:
    image: registry.example.com/kuark-web:latest
    restart: always
    environment:
      NODE_ENV: production
    ports:
      - '3000:3000'
    depends_on:
      - api

  nginx:
    image: nginx:alpine
    restart: always
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
    ports:
      - '80:80'
      - '443:443'
    depends_on:
      - api
      - web
```

---

## Post-Deployment Checklist

### Verification
- [ ] Health endpoints responding
- [ ] Database migrations applied
- [ ] API endpoints accessible
- [ ] Frontend loading correctly
- [ ] Auth flow working
- [ ] File uploads working (if applicable)
- [ ] Background jobs processing (if applicable)

### Monitoring
- [ ] Application logs visible
- [ ] Error tracking configured (Sentry)
- [ ] Uptime monitoring enabled
- [ ] Performance metrics tracked
- [ ] Database metrics visible

### Security Verification
- [ ] HTTPS enabled and redirecting
- [ ] Security headers present
- [ ] CORS working as expected
- [ ] Rate limiting active
- [ ] No sensitive data in logs

---

## Rollback Procedure

### Railway
```bash
# View deployment history
railway deployments

# Rollback to previous
railway rollback
```

### Docker
```bash
# Pull previous version
docker pull registry.example.com/kuark-api:previous

# Update compose
docker-compose -f docker-compose.prod.yml up -d

# Or manual rollback
docker stop kuark-api
docker run -d --name kuark-api registry.example.com/kuark-api:previous
```

### Database
```bash
# If migration needs rollback
npx prisma migrate resolve --rolled-back <migration-name>
```

---

## Emergency Contacts

| Role | Contact |
|------|---------|
| DevOps Lead | devops@kuark.com |
| Database Admin | dba@kuark.com |
| Security | security@kuark.com |

---

## Quick Commands Reference

```bash
# Railway
railway status              # Check service status
railway logs                # View logs
railway logs --service api  # Service-specific logs
railway variables           # List env vars
railway up                  # Deploy

# Docker
docker ps                   # Running containers
docker logs kuark-api       # View logs
docker stats                # Resource usage
docker-compose logs -f      # Follow compose logs

# Database
npx prisma migrate status   # Check migration status
npx prisma migrate deploy   # Run pending migrations
npx prisma db seed          # Run seeds
```
