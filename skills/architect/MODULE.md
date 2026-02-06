# Architect Skill Module

> Architecture decisions and system design for Kuark projects

## Triggers

- architecture, design, ADR
- technology, decision, pattern
- system design, scalability
- "mimari tasarla", "teknoloji seç", "ADR yaz"

## Technology Stack

Kuark standard stack:

### Backend
- NestJS 10+ (TypeScript)
- Prisma ORM
- PostgreSQL 16+
- Redis 7+
- BullMQ

### Frontend
- Next.js 15+ (App Router)
- TanStack Query
- Zustand
- Tailwind CSS + shadcn/ui

### Infrastructure
- Docker (multi-stage)
- Railway / Nixpacks
- GitHub Actions

## Architecture Decision Record (ADR)

### ADR Template
```markdown
# ADR-001: [Title]

## Status
Proposed | Accepted | Deprecated | Superseded

## Context
What is the issue that we're seeing that is motivating this decision?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or more difficult to do because of this change?

### Positive
- ...

### Negative
- ...

### Neutral
- ...

## Alternatives Considered
What other options were evaluated?

### Option A: [Name]
- Pros: ...
- Cons: ...

### Option B: [Name]
- Pros: ...
- Cons: ...

## References
- [Link 1]
- [Link 2]
```

### Example ADR
```markdown
# ADR-001: Multi-tenant Architecture with organizationId

## Status
Accepted

## Context
Kuark SaaS products serve multiple organizations. We need data isolation between tenants while maintaining a single database for operational simplicity.

## Decision
Implement row-level multi-tenancy using `organizationId` field:
- Every business model includes `organizationId: String`
- Every query filters by `organizationId`
- Guards enforce organization context

## Consequences

### Positive
- Simple to implement and understand
- Single database reduces operational complexity
- Easy to scale vertically initially

### Negative
- All tenants share database resources
- Complex queries for cross-tenant analytics
- Need careful index planning

### Neutral
- Migration to database-per-tenant possible later

## Alternatives Considered

### Option A: Database per tenant
- Pros: Complete isolation, easier compliance
- Cons: Operational complexity, connection pooling issues

### Option B: Schema per tenant
- Pros: Good isolation, single connection
- Cons: Migration complexity, limited PostgreSQL tools
```

## Architecture Patterns

### Monorepo Structure
```
project/
├── apps/
│   ├── api/              # NestJS backend
│   ├── web/              # Next.js frontend
│   ├── admin/            # Admin panel
│   └── mobile/           # React Native (optional)
├── packages/
│   ├── database/         # Prisma schema & client
│   ├── config/           # Shared configs
│   ├── ui/               # Shared UI components
│   └── types/            # Shared TypeScript types
├── docker/
│   ├── docker-compose.yml
│   └── Dockerfile.*
├── pnpm-workspace.yaml
├── turbo.json
└── package.json
```

### Module Architecture (NestJS)
```
src/
├── main.ts
├── app.module.ts
├── common/               # Shared utilities
│   ├── decorators/
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   └── pipes/
├── config/               # Configuration
├── prisma/               # Database
└── modules/              # Feature modules
    ├── auth/
    ├── users/
    ├── organizations/
    └── [feature]/
```

### Frontend Architecture (Next.js)
```
app/
├── (auth)/               # Auth routes (no layout)
├── (dashboard)/          # Dashboard routes (with layout)
│   ├── layout.tsx
│   └── [feature]/
├── api/                  # API routes
└── layout.tsx            # Root layout

components/
├── ui/                   # Base components (shadcn)
├── [feature]/            # Feature components
└── shared/               # Shared components

lib/
├── api/                  # API client
├── hooks/                # Custom hooks
├── stores/               # Zustand stores
└── utils/                # Utilities
```

## Design Principles

### SOLID for NestJS
```
S - Single Responsibility
    Each service handles one domain
    Each controller handles one resource

O - Open/Closed
    Extend via decorators, not modification
    Use strategy pattern for variants

L - Liskov Substitution
    Interfaces for services
    Dependency injection

I - Interface Segregation
    Small, focused DTOs
    Specific service methods

D - Dependency Inversion
    Inject dependencies via constructor
    Use abstract classes for contracts
```

### Domain-Driven Design (Simplified)
```
Entities:       Prisma models
Value Objects:  DTOs, Enums
Aggregates:     Module services
Repositories:   Prisma queries in services
Services:       Business logic
Controllers:    HTTP interface
```

## Scalability Considerations

### Database
- [ ] Proper indexes on organizationId
- [ ] Composite indexes for common queries
- [ ] Read replicas for reporting
- [ ] Connection pooling (PgBouncer)

### API
- [ ] Rate limiting
- [ ] Caching with Redis
- [ ] Response compression
- [ ] Pagination everywhere

### Background Jobs
- [ ] BullMQ for async processing
- [ ] Batch processing for bulk operations
- [ ] Scheduled jobs for maintenance

### Frontend
- [ ] Server-side rendering (Next.js)
- [ ] Static generation where possible
- [ ] Image optimization
- [ ] Code splitting

## Security Architecture

### Authentication Flow
```
1. User submits credentials
2. Server validates and issues JWT
3. JWT contains: sub, email, organizationId, role
4. Client stores token (httpOnly cookie preferred)
5. Every request includes Authorization header
6. JwtAuthGuard validates token
7. FullAccessGuard validates organization
```

### Authorization Layers
```
Layer 1: JwtAuthGuard     - Is user authenticated?
Layer 2: FullAccessGuard  - Is organization valid?
Layer 3: RolesGuard       - Does user have required role?
Layer 4: Service          - Does user own the resource?
```

## Technology Selection Criteria

| Criteria | Weight | Evaluation |
|----------|--------|------------|
| Team familiarity | High | Can team use it effectively? |
| Community support | High | Active development? Good docs? |
| Performance | Medium | Meets requirements? |
| Maintenance | Medium | Long-term viability? |
| Cost | Medium | License, hosting costs? |
| Integration | Low | Works with existing stack? |

## Migration Strategy

### Database Changes
```
1. Add new field (nullable)
2. Deploy code that writes to new field
3. Backfill existing data
4. Make field required
5. Deploy code that reads from new field
6. Remove old field (if applicable)
```

### API Versioning
```
1. Keep v1 working
2. Create v2 with changes
3. Deprecation notice in v1
4. Migration period (3-6 months)
5. Remove v1
```

## Validation Checklist

- [ ] ADR written for significant decisions
- [ ] Multi-tenant pattern followed
- [ ] Proper module boundaries
- [ ] Security layers implemented
- [ ] Scalability considered
- [ ] Migration path defined
