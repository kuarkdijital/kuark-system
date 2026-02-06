# Kuark Code Conventions

> Production-grade standards for Kuark development team
> All developers must follow these conventions to ensure consistency

---

## 1. TypeScript Standards

### Strict Configuration
```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

### Type Requirements
```typescript
// REQUIRED: Explicit function signatures
function processUser(user: User, organizationId: string): ProcessedUser { }

// REQUIRED: Interface over type for objects
interface UserProfile {
  id: string;
  email: string;
  organizationId: string;
  createdAt: Date;
}

// REQUIRED: Discriminated unions for variants
type ApiResult<T> =
  | { success: true; data: T }
  | { success: false; error: string; code: string };
```

### Prohibited
```typescript
// BLOCKED: any type
const data: any = fetch();  // NO

// BLOCKED: Non-null assertion without check
user!.name;  // NO

// BLOCKED: Type assertion without validation
data as User;  // NO - use type guards

// BLOCKED: Missing return types
function calculate(x) { }  // NO
```

---

## 2. NestJS Module Pattern (Kuark-Specific)

### Module Structure
```
src/modules/[feature]/
├── [feature].module.ts
├── [feature].controller.ts
├── [feature].service.ts
├── dto/
│   ├── create-[feature].dto.ts
│   ├── update-[feature].dto.ts
│   └── [feature]-query.dto.ts
├── processors/
│   └── [feature].processor.ts  (if using BullMQ)
└── interfaces/
    └── [feature].interface.ts
```

### Module Template
```typescript
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { FeatureController } from './feature.controller';
import { FeatureService } from './feature.service';
import { FeatureProcessor } from './processors/feature.processor';

@Module({
  imports: [
    BullModule.registerQueue({ name: 'feature' }),
  ],
  controllers: [FeatureController],
  providers: [FeatureService, FeatureProcessor],
  exports: [FeatureService],
})
export class FeatureModule {}
```

### Controller Rules
```typescript
// REQUIRED: Guard stacking
@UseGuards(JwtAuthGuard, FullAccessGuard)
@Controller('features')
export class FeatureController {
  // REQUIRED: Always use @CurrentUser() for organizationId
  @Get()
  findAll(@CurrentUser() user: JwtPayload) {
    return this.service.findAll(user.organizationId);
  }

  // REQUIRED: organizationId in all operations
  @Get(':id')
  findOne(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.service.findOne(id, user.organizationId);
  }
}
```

### Service Rules
```typescript
@Injectable()
export class FeatureService {
  // REQUIRED: organizationId as first parameter
  async findAll(organizationId: string, options?: QueryOptions) {
    // REQUIRED: Always filter by organizationId
    return this.prisma.feature.findMany({
      where: { organizationId, deletedAt: null },
    });
  }

  async findOne(id: string, organizationId: string) {
    // REQUIRED: Check ownership
    const item = await this.prisma.feature.findFirst({
      where: { id, organizationId },
    });

    if (!item) {
      throw new NotFoundException('Feature not found');
    }

    return item;
  }
}
```

---

## 3. Next.js App Router Pattern

### Directory Structure
```
app/
├── (auth)/
│   ├── login/page.tsx
│   └── register/page.tsx
├── (dashboard)/
│   ├── layout.tsx
│   ├── page.tsx
│   └── [feature]/
│       ├── page.tsx
│       └── [id]/page.tsx
├── api/
│   └── [...proxy]/route.ts
└── layout.tsx
```

### Server Component (Default)
```typescript
// app/features/page.tsx
import { getFeatures } from '@/lib/api';

export default async function FeaturesPage() {
  const features = await getFeatures();

  return (
    <div>
      <h1>Features</h1>
      <FeatureList features={features} />
    </div>
  );
}
```

### Client Component
```typescript
'use client';

import { useState } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';

export function FeatureForm() {
  const [isOpen, setIsOpen] = useState(false);

  const { mutate, isPending } = useMutation({
    mutationFn: createFeature,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['features'] });
    },
  });

  // Component logic
}
```

### State Management Rules
```
Server data     → TanStack Query (useQuery/useMutation)
Global UI state → Zustand
Local UI state  → useState/useReducer
Form state      → React Hook Form + Zod
URL state       → nuqs or useSearchParams
```

### Mandatory State Handling
```typescript
export function DataList() {
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['features'],
    queryFn: getFeatures,
  });

  // ALL states required:
  if (isLoading) return <Skeleton />;
  if (error) return <ErrorDisplay onRetry={refetch} />;
  if (!data?.length) return <EmptyState onCreate={handleCreate} />;

  return <List items={data} />;
}
```

---

## 4. Database Conventions (Prisma)

### Model Template
```prisma
model Feature {
  id             String    @id @default(cuid())
  name           String
  description    String?
  status         FeatureStatus @default(ACTIVE)

  // Multi-tenant: REQUIRED
  organizationId String
  organization   Organization @relation(fields: [organizationId], references: [id])

  // Audit fields: REQUIRED
  createdAt      DateTime  @default(now())
  updatedAt      DateTime  @updatedAt
  deletedAt      DateTime?  // Soft delete

  // Creator tracking
  createdBy      String?

  // Indexes: REQUIRED for performance
  @@index([organizationId])
  @@index([organizationId, status])
  @@index([organizationId, createdAt])
}
```

### Query Patterns
```typescript
// REQUIRED: Include organizationId in ALL queries
const items = await prisma.feature.findMany({
  where: {
    organizationId,
    deletedAt: null,  // Soft delete filter
  },
  include: { relations: true },
  orderBy: { createdAt: 'desc' },
});

// REQUIRED: Paginate lists
const [data, total] = await Promise.all([
  prisma.feature.findMany({
    where: { organizationId },
    skip: (page - 1) * limit,
    take: limit,
  }),
  prisma.feature.count({ where: { organizationId } }),
]);

return {
  data,
  pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
};
```

### Soft Delete Pattern
```typescript
// Delete = Update deletedAt
async softDelete(id: string, organizationId: string) {
  return this.prisma.feature.update({
    where: { id, organizationId },
    data: { deletedAt: new Date() },
  });
}

// Always filter deleted records
const activeItems = await this.prisma.feature.findMany({
  where: { organizationId, deletedAt: null },
});
```

---

## 5. API Design

### Response Format
```typescript
// Success response
{
  "data": { ... },
  "meta": { "timestamp": "2024-01-01T00:00:00Z" }
}

// List response
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5
  }
}

// Error response
{
  "statusCode": 400,
  "message": "Validation failed",
  "error": "Bad Request",
  "details": { ... }
}
```

### DTO Validation
```typescript
import { IsString, IsEmail, MinLength, IsOptional, IsEnum } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateFeatureDto {
  @ApiProperty({ example: 'Feature Name' })
  @IsString()
  @MinLength(2)
  name: string;

  @ApiPropertyOptional({ example: 'Description' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ enum: FeatureStatus })
  @IsEnum(FeatureStatus)
  status: FeatureStatus;
}

export class UpdateFeatureDto extends PartialType(CreateFeatureDto) {}
```

---

## 6. Security Requirements

### Authentication (Every Protected Route)
```typescript
@UseGuards(JwtAuthGuard, FullAccessGuard)
@Controller('features')
export class FeatureController {
  // All routes protected by default
}
```

### Authorization (Resource Ownership)
```typescript
async findOne(id: string, organizationId: string) {
  const resource = await this.prisma.feature.findFirst({
    where: { id, organizationId },  // REQUIRED: Check organizationId
  });

  if (!resource) {
    throw new NotFoundException();  // Don't reveal existence
  }

  return resource;
}
```

### Input Validation
```typescript
// EVERY external input MUST be validated
@Post()
async create(
  @CurrentUser() user: JwtPayload,
  @Body(ValidationPipe) dto: CreateFeatureDto,  // Validated
) {
  return this.service.create(user.organizationId, dto);
}
```

### OWASP Checklist
- [ ] SQL Injection → Prisma ORM (parameterized)
- [ ] XSS → Sanitize output, CSP headers
- [ ] CSRF → Origin validation
- [ ] Auth bypass → JWT validation, organizationId check
- [ ] Sensitive data exposure → Field selection, audit logs

---

## 7. Queue/Background Jobs (BullMQ)

### Processor Pattern
```typescript
import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';

interface FeatureJobData {
  featureId: string;
  organizationId: string;
}

@Processor('feature')
export class FeatureProcessor extends WorkerHost {
  private readonly logger = new Logger(FeatureProcessor.name);

  async process(job: Job<FeatureJobData>): Promise<void> {
    const { featureId, organizationId } = job.data;

    this.logger.log(`Processing ${featureId} for org ${organizationId}`);

    try {
      // Process logic
      await job.updateProgress(50);

      // More processing
      await job.updateProgress(100);
    } catch (error) {
      this.logger.error(`Failed: ${error.message}`);
      throw error;  // Re-throw for retry
    }
  }

  @OnWorkerEvent('completed')
  onCompleted(job: Job) {
    this.logger.log(`Job ${job.id} completed`);
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, error: Error) {
    this.logger.error(`Job ${job.id} failed: ${error.message}`);
  }
}
```

### Job Options
```typescript
await this.queue.add(
  'process-feature',
  { featureId, organizationId },
  {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
    removeOnComplete: true,
    removeOnFail: false,
  },
);
```

---

## 8. Testing Standards

### Coverage Requirements
```
Minimum coverage: 80%
Critical paths: 100%
Edge cases: documented and tested
```

### Test Structure
```typescript
describe('FeatureService', () => {
  let service: FeatureService;
  let prisma: PrismaService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        FeatureService,
        { provide: PrismaService, useValue: mockPrismaService },
      ],
    }).compile();

    service = module.get(FeatureService);
    prisma = module.get(PrismaService);
  });

  describe('findAll', () => {
    it('should return features for organization', async () => {
      const orgId = 'org-123';
      const mockFeatures = [{ id: '1', name: 'Test' }];
      mockPrismaService.feature.findMany.mockResolvedValue(mockFeatures);

      const result = await service.findAll(orgId);

      expect(result.data).toEqual(mockFeatures);
      expect(prisma.feature.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { organizationId: orgId },
        }),
      );
    });
  });
});
```

### E2E Test
```typescript
describe('Features (e2e)', () => {
  it('/features (GET) should return 401 without auth', () => {
    return request(app.getHttpServer())
      .get('/features')
      .expect(401);
  });

  it('/features (GET) should return features', () => {
    return request(app.getHttpServer())
      .get('/features')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect((res) => {
        expect(res.body.data).toBeDefined();
      });
  });
});
```

---

## 9. Git Workflow

### Commit Messages
```
feat: add user authentication with JWT
fix: resolve login redirect loop for expired tokens
refactor: extract validation logic to shared module
docs: update API documentation for campaigns
test: add feature service unit tests
chore: update dependencies to latest versions
perf: optimize database queries with indexes
```

### Branch Naming
```
feature/TASK-123-user-authentication
fix/TASK-456-login-redirect
refactor/TASK-789-validation-logic
hotfix/critical-security-patch
```

### PR Template
```markdown
## Summary
- Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] E2E tests pass
- [ ] Manual testing completed

## Checklist
- [ ] organizationId filtering applied
- [ ] Guards applied to routes
- [ ] DTO validation added
- [ ] Swagger documentation updated
```

---

## 10. Docker Standards

### Multi-stage Build (NestJS)
```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./

EXPOSE 3000
CMD ["node", "dist/main.js"]
```

### Multi-stage Build (Next.js)
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

EXPOSE 3000
CMD ["node", "server.js"]
```

### docker-compose.yml
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: kuark
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
    ports:
      - '6379:6379'
    volumes:
      - redis_data:/data
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  redis_data:
```

---

## Quick Reference

| Category | Rule |
|----------|------|
| Types | No `any`, explicit signatures |
| Guards | JwtAuthGuard + FullAccessGuard |
| Queries | Always filter by organizationId |
| DTOs | class-validator on all inputs |
| Components | All 4 states handled |
| Database | Soft delete, indexes |
| Errors | User feedback, server logs |
| Security | Auth on every route |
| Tests | 80% minimum coverage |
| Docker | Multi-stage builds |
