# Kuark API Response Format

> Standardized API response format for all endpoints

## Success Responses

### Single Resource
```typescript
// GET /api/v1/features/:id
{
  "data": {
    "id": "clx1234567890",
    "name": "Feature Name",
    "description": "Description",
    "status": "ACTIVE",
    "organizationId": "org_abc123",
    "createdAt": "2024-01-15T10:30:00.000Z",
    "updatedAt": "2024-01-15T10:30:00.000Z"
  }
}
```

### List Response (Paginated)
```typescript
// GET /api/v1/features
{
  "data": [
    {
      "id": "clx1234567890",
      "name": "Feature 1",
      // ...
    },
    {
      "id": "clx0987654321",
      "name": "Feature 2",
      // ...
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}
```

### Create Response
```typescript
// POST /api/v1/features
// Status: 201 Created
{
  "data": {
    "id": "clx1234567890",
    "name": "New Feature",
    // ... created resource
  }
}
```

### Update Response
```typescript
// PUT /api/v1/features/:id
// Status: 200 OK
{
  "data": {
    "id": "clx1234567890",
    "name": "Updated Feature",
    // ... updated resource
  }
}
```

### Delete Response
```typescript
// DELETE /api/v1/features/:id
// Status: 200 OK
{
  "success": true,
  "message": "Feature deleted successfully"
}
```

## Error Responses

### Validation Error (400)
```typescript
{
  "statusCode": 400,
  "error": "Bad Request",
  "message": "Validation failed",
  "errors": [
    {
      "field": "name",
      "message": "Name must be at least 2 characters"
    },
    {
      "field": "email",
      "message": "Invalid email format"
    }
  ]
}
```

### Unauthorized (401)
```typescript
{
  "statusCode": 401,
  "error": "Unauthorized",
  "message": "Invalid or expired token"
}
```

### Forbidden (403)
```typescript
{
  "statusCode": 403,
  "error": "Forbidden",
  "message": "You do not have permission to access this resource"
}
```

### Not Found (404)
```typescript
{
  "statusCode": 404,
  "error": "Not Found",
  "message": "Feature not found"
}
```

### Conflict (409)
```typescript
{
  "statusCode": 409,
  "error": "Conflict",
  "message": "A feature with this name already exists"
}
```

### Rate Limited (429)
```typescript
{
  "statusCode": 429,
  "error": "Too Many Requests",
  "message": "Rate limit exceeded. Try again in 60 seconds",
  "retryAfter": 60
}
```

### Internal Server Error (500)
```typescript
{
  "statusCode": 500,
  "error": "Internal Server Error",
  "message": "An unexpected error occurred",
  "requestId": "req_abc123xyz"  // For support/debugging
}
```

## NestJS Implementation

### Response Interceptor
```typescript
// src/common/interceptors/response.interceptor.ts
import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface Response<T> {
  data: T;
}

@Injectable()
export class ResponseInterceptor<T> implements NestInterceptor<T, Response<T>> {
  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<Response<T>> {
    return next.handle().pipe(
      map((data) => {
        // If data already has 'data' key, return as-is
        if (data?.data !== undefined || data?.pagination !== undefined) {
          return data;
        }
        // Wrap in data object
        return { data };
      }),
    );
  }
}
```

### Exception Filter
```typescript
// src/common/filters/http-exception.filter.ts
import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'An unexpected error occurred';
    let errors: any[] | undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse() as any;
      message = exceptionResponse.message || exception.message;
      errors = exceptionResponse.errors;
    }

    const errorResponse = {
      statusCode: status,
      error: HttpStatus[status],
      message,
      ...(errors && { errors }),
      ...(status === 500 && { requestId: request.headers['x-request-id'] }),
    };

    // Log server errors
    if (status >= 500) {
      this.logger.error(
        `${request.method} ${request.url}`,
        exception instanceof Error ? exception.stack : exception,
      );
    }

    response.status(status).json(errorResponse);
  }
}
```

### Pagination Helper
```typescript
// src/common/helpers/pagination.helper.ts
export interface PaginationParams {
  page?: number;
  limit?: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export function createPaginatedResponse<T>(
  data: T[],
  total: number,
  params: PaginationParams,
): PaginatedResponse<T> {
  const page = params.page || 1;
  const limit = params.limit || 20;

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

## Frontend Usage

### API Client
```typescript
// lib/api/client.ts
import { toast } from 'sonner';

interface ApiResponse<T> {
  data: T;
}

interface PaginatedApiResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

interface ApiError {
  statusCode: number;
  error: string;
  message: string;
  errors?: { field: string; message: string }[];
}

async function handleResponse<T>(response: Response): Promise<T> {
  if (!response.ok) {
    const error: ApiError = await response.json();

    // Handle validation errors
    if (error.errors) {
      throw new Error(error.errors.map(e => e.message).join(', '));
    }

    throw new Error(error.message);
  }

  return response.json();
}

export const api = {
  get: async <T>(url: string): Promise<T> => {
    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${getToken()}` },
    });
    return handleResponse<T>(response);
  },

  post: async <T>(url: string, data: unknown): Promise<T> => {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${getToken()}`,
      },
      body: JSON.stringify(data),
    });
    return handleResponse<T>(response);
  },

  // ... put, delete
};
```

### React Query Usage
```typescript
// lib/hooks/use-features.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/client';

export function useFeatures(params?: { page?: number; limit?: number }) {
  return useQuery({
    queryKey: ['features', params],
    queryFn: () => api.get<PaginatedApiResponse<Feature>>('/api/v1/features', params),
  });
}

export function useCreateFeature() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateFeatureDto) =>
      api.post<ApiResponse<Feature>>('/api/v1/features', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['features'] });
    },
  });
}
```

## Best Practices

1. **Always wrap single resources** in `{ data: ... }`
2. **Include pagination metadata** for list endpoints
3. **Use HTTP status codes correctly** (201 for create, 204 for no content)
4. **Include field-level errors** for validation failures
5. **Log server errors** with request ID for debugging
6. **Never expose stack traces** in production responses
