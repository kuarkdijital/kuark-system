# Kuark Monorepo Structure

> pnpm + Turborepo yapısı

## Directory Structure

```
kuark-project/
├── apps/                    # Applications
│   ├── api/                 # NestJS backend
│   │   ├── src/
│   │   │   ├── app.module.ts
│   │   │   ├── main.ts
│   │   │   ├── auth/        # Authentication module
│   │   │   ├── prisma/      # Prisma service
│   │   │   └── modules/     # Feature modules
│   │   │       ├── users/
│   │   │       ├── features/
│   │   │       └── ...
│   │   ├── test/
│   │   ├── prisma/
│   │   │   └── schema.prisma
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   └── web/                 # Next.js frontend
│       ├── app/             # App Router
│       │   ├── (auth)/      # Auth layout group
│       │   ├── (dashboard)/ # Dashboard layout group
│       │   ├── layout.tsx
│       │   └── page.tsx
│       ├── components/
│       │   ├── ui/          # shadcn/ui components
│       │   └── features/    # Feature-specific components
│       ├── lib/
│       │   ├── api/         # API client
│       │   ├── hooks/       # Custom hooks
│       │   └── utils/
│       ├── public/
│       ├── package.json
│       └── tsconfig.json
│
├── packages/                # Shared packages
│   ├── database/            # Prisma schema & client
│   │   ├── prisma/
│   │   │   └── schema.prisma
│   │   ├── src/
│   │   │   └── index.ts
│   │   └── package.json
│   │
│   ├── ui/                  # Shared UI components
│   │   ├── src/
│   │   │   ├── button.tsx
│   │   │   └── ...
│   │   └── package.json
│   │
│   ├── types/               # Shared TypeScript types
│   │   ├── src/
│   │   │   ├── api.ts
│   │   │   ├── user.ts
│   │   │   └── index.ts
│   │   └── package.json
│   │
│   └── utils/               # Shared utilities
│       ├── src/
│       │   ├── format.ts
│       │   └── validation.ts
│       └── package.json
│
├── docker/                  # Docker configurations
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   └── nginx/
│       └── nginx.conf
│
├── .github/                 # GitHub workflows
│   └── workflows/
│       ├── ci.yml
│       └── deploy.yml
│
├── package.json             # Root package.json
├── pnpm-workspace.yaml      # pnpm workspace config
├── turbo.json               # Turborepo config
├── .env.example             # Environment template
└── README.md
```

## Root Configuration

### package.json
```json
{
  "name": "kuark-project",
  "private": true,
  "scripts": {
    "dev": "turbo run dev",
    "build": "turbo run build",
    "lint": "turbo run lint",
    "test": "turbo run test",
    "clean": "turbo run clean",
    "db:generate": "pnpm --filter @kuark/database prisma generate",
    "db:migrate": "pnpm --filter @kuark/database prisma migrate dev",
    "db:push": "pnpm --filter @kuark/database prisma db push"
  },
  "devDependencies": {
    "turbo": "^2.0.0",
    "typescript": "^5.3.0"
  },
  "packageManager": "pnpm@8.15.0"
}
```

### pnpm-workspace.yaml
```yaml
packages:
  - 'apps/*'
  - 'packages/*'
```

### turbo.json
```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": [".env"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": ["coverage/**"]
    },
    "clean": {
      "cache": false
    }
  }
}
```

## Package References

### Internal Package Usage
```typescript
// apps/api/package.json
{
  "dependencies": {
    "@kuark/database": "workspace:*",
    "@kuark/types": "workspace:*",
    "@kuark/utils": "workspace:*"
  }
}

// apps/web/package.json
{
  "dependencies": {
    "@kuark/ui": "workspace:*",
    "@kuark/types": "workspace:*",
    "@kuark/utils": "workspace:*"
  }
}
```

### Import Example
```typescript
// In apps/api
import { prisma } from '@kuark/database';
import { UserType } from '@kuark/types';
import { formatDate } from '@kuark/utils';

// In apps/web
import { Button } from '@kuark/ui';
import { UserType } from '@kuark/types';
```

## Development Commands

```bash
# Install all dependencies
pnpm install

# Run all apps in development
pnpm dev

# Run specific app
pnpm --filter api dev
pnpm --filter web dev

# Build all
pnpm build

# Run tests
pnpm test

# Lint all
pnpm lint

# Database operations
pnpm db:generate
pnpm db:migrate

# Add dependency to specific app
pnpm --filter api add lodash
pnpm --filter web add @tanstack/react-query

# Add dev dependency
pnpm --filter api add -D @types/lodash
```

## Environment Variables

Each app has its own `.env`:
- `apps/api/.env` - API environment
- `apps/web/.env.local` - Web environment
- Root `.env` - Shared (Turborepo)

## Deployment

### Railway
- Each app deploys as separate service
- Use `nixpacks.toml` in each app
- Set `ROOT_DIR` to `apps/api` or `apps/web`

### Docker
```bash
# Build API
docker build -f apps/api/Dockerfile -t kuark-api .

# Build Web
docker build -f apps/web/Dockerfile -t kuark-web .

# Run with compose
docker-compose -f docker/docker-compose.prod.yml up -d
```

## Best Practices

1. **Shared Code** → Put in `packages/`
2. **App-Specific** → Keep in `apps/`
3. **Types** → Share via `@kuark/types`
4. **UI Components** → Share via `@kuark/ui`
5. **Database** → Single source in `@kuark/database`
6. **Utils** → Share common functions via `@kuark/utils`
