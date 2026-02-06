# Kuark Error Codes Reference

> Standardized error codes and HTTP status usage

## HTTP Status Codes

### Success (2xx)

| Code | Name | Usage |
|------|------|-------|
| 200 | OK | Successful GET, PUT, DELETE |
| 201 | Created | Successful POST (resource created) |
| 204 | No Content | Successful DELETE (no response body) |

### Client Errors (4xx)

| Code | Name | Usage |
|------|------|-------|
| 400 | Bad Request | Validation error, malformed request |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Authenticated but no permission |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Resource already exists, duplicate |
| 422 | Unprocessable Entity | Semantic validation error |
| 429 | Too Many Requests | Rate limit exceeded |

### Server Errors (5xx)

| Code | Name | Usage |
|------|------|-------|
| 500 | Internal Server Error | Unexpected server error |
| 502 | Bad Gateway | Upstream service error |
| 503 | Service Unavailable | Maintenance, overload |
| 504 | Gateway Timeout | Upstream timeout |

## Application Error Codes

### Authentication Errors (AUTH_xxx)

| Code | Message | HTTP Status |
|------|---------|-------------|
| AUTH_001 | Invalid credentials | 401 |
| AUTH_002 | Token expired | 401 |
| AUTH_003 | Token invalid | 401 |
| AUTH_004 | Account disabled | 403 |
| AUTH_005 | Password reset required | 403 |
| AUTH_006 | MFA required | 403 |
| AUTH_007 | MFA invalid | 401 |
| AUTH_008 | Session expired | 401 |

### Authorization Errors (AUTHZ_xxx)

| Code | Message | HTTP Status |
|------|---------|-------------|
| AUTHZ_001 | Insufficient permissions | 403 |
| AUTHZ_002 | Resource not owned | 403 |
| AUTHZ_003 | Organization mismatch | 403 |
| AUTHZ_004 | Role required | 403 |
| AUTHZ_005 | Feature not enabled | 403 |

### Validation Errors (VAL_xxx)

| Code | Message | HTTP Status |
|------|---------|-------------|
| VAL_001 | Required field missing | 400 |
| VAL_002 | Invalid format | 400 |
| VAL_003 | Value out of range | 400 |
| VAL_004 | Invalid enum value | 400 |
| VAL_005 | String too short | 400 |
| VAL_006 | String too long | 400 |
| VAL_007 | Invalid email | 400 |
| VAL_008 | Invalid phone | 400 |
| VAL_009 | Invalid URL | 400 |
| VAL_010 | Invalid date | 400 |

### Resource Errors (RES_xxx)

| Code | Message | HTTP Status |
|------|---------|-------------|
| RES_001 | Resource not found | 404 |
| RES_002 | Resource already exists | 409 |
| RES_003 | Resource in use | 409 |
| RES_004 | Resource deleted | 410 |
| RES_005 | Parent resource not found | 400 |
| RES_006 | Child resources exist | 409 |

### Business Logic Errors (BIZ_xxx)

| Code | Message | HTTP Status |
|------|---------|-------------|
| BIZ_001 | Operation not allowed | 400 |
| BIZ_002 | Limit exceeded | 400 |
| BIZ_003 | Invalid state transition | 400 |
| BIZ_004 | Dependency not satisfied | 400 |
| BIZ_005 | Insufficient balance | 400 |
| BIZ_006 | Payment required | 402 |

### External Service Errors (EXT_xxx)

| Code | Message | HTTP Status |
|------|---------|-------------|
| EXT_001 | External service unavailable | 503 |
| EXT_002 | External service timeout | 504 |
| EXT_003 | External service error | 502 |
| EXT_004 | Payment gateway error | 502 |
| EXT_005 | Email service error | 502 |
| EXT_006 | SMS service error | 502 |

### Rate Limiting Errors (RATE_xxx)

| Code | Message | HTTP Status |
|------|---------|-------------|
| RATE_001 | Too many requests | 429 |
| RATE_002 | API quota exceeded | 429 |
| RATE_003 | Daily limit reached | 429 |

## NestJS Implementation

### Custom Exception Classes
```typescript
// src/common/exceptions/business.exception.ts
import { HttpException, HttpStatus } from '@nestjs/common';

export class BusinessException extends HttpException {
  constructor(
    public readonly code: string,
    message: string,
    status: HttpStatus = HttpStatus.BAD_REQUEST,
  ) {
    super(
      {
        statusCode: status,
        error: code,
        message,
      },
      status,
    );
  }
}

// Usage
throw new BusinessException('BIZ_003', 'Cannot transition from DRAFT to DELETED');
```

### Exception Classes
```typescript
// src/common/exceptions/index.ts
import { HttpException, HttpStatus } from '@nestjs/common';

export class UnauthorizedException extends HttpException {
  constructor(code: string = 'AUTH_001', message: string = 'Unauthorized') {
    super({ statusCode: HttpStatus.UNAUTHORIZED, error: code, message }, HttpStatus.UNAUTHORIZED);
  }
}

export class ForbiddenException extends HttpException {
  constructor(code: string = 'AUTHZ_001', message: string = 'Forbidden') {
    super({ statusCode: HttpStatus.FORBIDDEN, error: code, message }, HttpStatus.FORBIDDEN);
  }
}

export class NotFoundException extends HttpException {
  constructor(resource: string = 'Resource') {
    super(
      { statusCode: HttpStatus.NOT_FOUND, error: 'RES_001', message: `${resource} not found` },
      HttpStatus.NOT_FOUND,
    );
  }
}

export class ConflictException extends HttpException {
  constructor(code: string = 'RES_002', message: string = 'Resource already exists') {
    super({ statusCode: HttpStatus.CONFLICT, error: code, message }, HttpStatus.CONFLICT);
  }
}

export class ValidationException extends HttpException {
  constructor(errors: { field: string; message: string }[]) {
    super(
      {
        statusCode: HttpStatus.BAD_REQUEST,
        error: 'VAL_001',
        message: 'Validation failed',
        errors,
      },
      HttpStatus.BAD_REQUEST,
    );
  }
}
```

### Service Usage
```typescript
// src/modules/features/feature.service.ts
import { NotFoundException, ConflictException, BusinessException } from '../../common/exceptions';

@Injectable()
export class FeatureService {
  async findOne(id: string, organizationId: string): Promise<Feature> {
    const feature = await this.prisma.feature.findFirst({
      where: { id, organizationId, deletedAt: null },
    });

    if (!feature) {
      throw new NotFoundException('Feature');
    }

    return feature;
  }

  async create(organizationId: string, dto: CreateFeatureDto): Promise<Feature> {
    // Check for duplicate
    const existing = await this.prisma.feature.findFirst({
      where: { organizationId, name: dto.name, deletedAt: null },
    });

    if (existing) {
      throw new ConflictException('RES_002', 'A feature with this name already exists');
    }

    return this.prisma.feature.create({ ... });
  }

  async updateStatus(id: string, organizationId: string, newStatus: Status): Promise<Feature> {
    const feature = await this.findOne(id, organizationId);

    // Validate state transition
    if (feature.status === 'DRAFT' && newStatus === 'DELETED') {
      throw new BusinessException('BIZ_003', 'Cannot delete a draft feature directly');
    }

    return this.prisma.feature.update({ ... });
  }
}
```

## Frontend Error Handling

```typescript
// lib/utils/error-handler.ts
import { toast } from 'sonner';

interface ApiError {
  statusCode: number;
  error: string;
  message: string;
  errors?: { field: string; message: string }[];
}

export function handleApiError(error: ApiError): void {
  // Handle by error code
  switch (error.error) {
    case 'AUTH_002':
    case 'AUTH_008':
      // Token expired - redirect to login
      window.location.href = '/login';
      return;

    case 'RATE_001':
      toast.error('Too many requests. Please wait a moment.');
      return;

    case 'VAL_001':
      // Validation errors - show field errors
      if (error.errors) {
        error.errors.forEach((e) => toast.error(`${e.field}: ${e.message}`));
      }
      return;

    default:
      toast.error(error.message);
  }
}
```

## Best Practices

1. **Use semantic error codes** - Makes debugging and localization easier
2. **Include error code in response** - Frontend can handle specific errors
3. **Log with error codes** - Easier to search and analyze
4. **Document all error codes** - Keep this reference updated
5. **Use appropriate HTTP status** - Follow REST conventions
6. **Never expose internal errors** - Sanitize 500 errors in production
