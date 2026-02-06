# Prisma Skill Module

> Database design and Prisma ORM for Kuark projects

## Triggers

- schema, migration, model, Prisma
- database, relation, index, constraint
- PostgreSQL, query, N+1
- "schema tasarla", "migration yaz", "model oluştur"

## Technology Stack

- Prisma ORM
- PostgreSQL 16+
- TimescaleDB (for time-series data)
- Redis (caching)

## Schema Standards

### Model Template
```prisma
model Feature {
  id             String    @id @default(cuid())
  name           String
  description    String?
  status         FeatureStatus @default(ACTIVE)

  // Multi-tenant: REQUIRED for all business models
  organizationId String
  organization   Organization @relation(fields: [organizationId], references: [id])

  // Audit fields: REQUIRED
  createdAt      DateTime  @default(now())
  updatedAt      DateTime  @updatedAt
  deletedAt      DateTime?  // Soft delete

  // Creator tracking
  createdBy      String?
  createdByUser  User?     @relation("FeatureCreatedBy", fields: [createdBy], references: [id])

  // Relations
  items          FeatureItem[]

  // Indexes: REQUIRED for performance
  @@index([organizationId])
  @@index([organizationId, status])
  @@index([organizationId, createdAt])
  @@index([deletedAt])
}

enum FeatureStatus {
  ACTIVE
  INACTIVE
  ARCHIVED
}
```

### Required Fields for Business Models

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String @id @default(cuid()) | ✅ | Primary key |
| organizationId | String | ✅ | Multi-tenant |
| createdAt | DateTime @default(now()) | ✅ | Creation timestamp |
| updatedAt | DateTime @updatedAt | ✅ | Update timestamp |
| deletedAt | DateTime? | ✅ | Soft delete |
| createdBy | String? | Recommended | Creator tracking |

### Models Exempt from organizationId

These core models don't need organizationId:
- Organization
- User
- Account
- Session
- VerificationToken
- RefreshToken

## Relation Patterns

### One-to-Many
```prisma
model Organization {
  id       String    @id @default(cuid())
  name     String
  features Feature[]
}

model Feature {
  id             String       @id @default(cuid())
  organizationId String
  organization   Organization @relation(fields: [organizationId], references: [id])
}
```

### Many-to-Many
```prisma
model Feature {
  id   String @id @default(cuid())
  tags FeatureTag[]
}

model Tag {
  id       String @id @default(cuid())
  name     String @unique
  features FeatureTag[]
}

model FeatureTag {
  featureId String
  tagId     String
  feature   Feature @relation(fields: [featureId], references: [id], onDelete: Cascade)
  tag       Tag     @relation(fields: [tagId], references: [id], onDelete: Cascade)

  @@id([featureId, tagId])
  @@index([tagId])
}
```

### Self-Relation (Hierarchy)
```prisma
model Category {
  id       String     @id @default(cuid())
  name     String
  parentId String?
  parent   Category?  @relation("CategoryHierarchy", fields: [parentId], references: [id])
  children Category[] @relation("CategoryHierarchy")

  organizationId String
  organization   Organization @relation(fields: [organizationId], references: [id])

  @@index([organizationId])
  @@index([parentId])
}
```

## Index Strategies

### Required Indexes
```prisma
// Always index organizationId
@@index([organizationId])

// Index for common queries
@@index([organizationId, status])
@@index([organizationId, createdAt])

// Index for soft delete queries
@@index([deletedAt])

// Composite unique
@@unique([organizationId, slug])
```

### Index for Search
```prisma
// Full-text search (PostgreSQL)
@@index([name, description], type: Brin)
```

## Query Patterns

### Soft Delete Filter
```typescript
// ALWAYS filter deleted records
const activeItems = await prisma.feature.findMany({
  where: {
    organizationId,
    deletedAt: null,  // Required
  },
});
```

### Pagination
```typescript
async findAll(organizationId: string, page = 1, limit = 20) {
  const [data, total] = await Promise.all([
    prisma.feature.findMany({
      where: { organizationId, deletedAt: null },
      skip: (page - 1) * limit,
      take: limit,
      orderBy: { createdAt: 'desc' },
    }),
    prisma.feature.count({
      where: { organizationId, deletedAt: null },
    }),
  ]);

  return {
    data,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
}
```

### Include Relations (Avoid N+1)
```typescript
// GOOD: Include relations
const features = await prisma.feature.findMany({
  where: { organizationId },
  include: {
    items: true,
    createdByUser: { select: { id: true, name: true } },
  },
});

// BAD: N+1 query
const features = await prisma.feature.findMany({ where: { organizationId } });
for (const feature of features) {
  const items = await prisma.featureItem.findMany({
    where: { featureId: feature.id },
  }); // ❌ N+1 problem
}
```

### Select Fields (Performance)
```typescript
// Select only needed fields
const names = await prisma.feature.findMany({
  where: { organizationId },
  select: {
    id: true,
    name: true,
    status: true,
  },
});
```

### Transaction
```typescript
// Use transactions for multiple operations
const result = await prisma.$transaction(async (tx) => {
  const feature = await tx.feature.create({
    data: { name, organizationId },
  });

  await tx.featureItem.createMany({
    data: items.map((item) => ({
      featureId: feature.id,
      ...item,
    })),
  });

  return feature;
});
```

## Migration Commands

```bash
# Generate migration from schema changes
npx prisma migrate dev --name add_feature_model

# Apply migrations in production
npx prisma migrate deploy

# Reset database (development only)
npx prisma migrate reset

# Generate Prisma client
npx prisma generate

# Open Prisma Studio
npx prisma studio

# Validate schema
npx prisma validate

# Format schema
npx prisma format
```

## Data Types

| Use Case | Prisma Type | PostgreSQL |
|----------|-------------|------------|
| ID | String @id @default(cuid()) | TEXT |
| Money | Decimal @db.Decimal(10,2) | DECIMAL(10,2) |
| Timestamp | DateTime | TIMESTAMPTZ |
| JSON | Json | JSONB |
| UUID | String @default(uuid()) | UUID |
| Big Integer | BigInt | BIGINT |

## Validation Checklist

- [ ] organizationId on all business models
- [ ] createdAt and updatedAt timestamps
- [ ] deletedAt for soft delete
- [ ] Index on organizationId
- [ ] Index on frequently queried fields
- [ ] Composite indexes for common queries
- [ ] Relations properly defined
- [ ] Cascade delete where appropriate
- [ ] Enum types for status fields
