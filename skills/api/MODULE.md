# API Skill Module

> REST API design and implementation for Kuark projects

## Triggers

- endpoint, REST, DTO, validation
- response, request, HTTP
- Swagger, OpenAPI
- "API tasarla", "endpoint oluştur", "response format"

## Technology Stack

- NestJS
- @nestjs/swagger
- class-validator
- class-transformer

## Response Format

### Standard Response
```typescript
// Success response
{
  "data": { ... },
  "meta": {
    "timestamp": "2024-01-01T00:00:00.000Z"
  }
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
  "details": {
    "field": ["error message"]
  },
  "timestamp": "2024-01-01T00:00:00.000Z",
  "path": "/api/features"
}
```

### Response Interceptor
```typescript
// common/interceptors/response.interceptor.ts
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
  meta?: {
    timestamp: string;
  };
}

@Injectable()
export class ResponseInterceptor<T> implements NestInterceptor<T, Response<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<Response<T>> {
    return next.handle().pipe(
      map((data) => ({
        data,
        meta: {
          timestamp: new Date().toISOString(),
        },
      })),
    );
  }
}
```

### Error Filter
```typescript
// common/filters/all-exceptions.filter.ts
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

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof HttpException
        ? exception.getResponse()
        : 'Internal server error';

    // Log error
    this.logger.error(
      `${request.method} ${request.url}`,
      exception instanceof Error ? exception.stack : '',
    );

    response.status(status).json({
      statusCode: status,
      message: typeof message === 'object' ? (message as any).message : message,
      error: HttpStatus[status],
      details: typeof message === 'object' ? (message as any).details : undefined,
      timestamp: new Date().toISOString(),
      path: request.url,
    });
  }
}
```

## HTTP Status Codes

| Code | Use Case |
|------|----------|
| 200 OK | Successful GET, PUT, PATCH |
| 201 Created | Successful POST creating resource |
| 204 No Content | Successful DELETE |
| 400 Bad Request | Validation errors |
| 401 Unauthorized | Missing/invalid authentication |
| 403 Forbidden | Authenticated but not authorized |
| 404 Not Found | Resource doesn't exist |
| 409 Conflict | Duplicate resource |
| 422 Unprocessable | Business logic error |
| 500 Internal Error | Server error |

## Swagger Documentation

### Controller Decorators
```typescript
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
  ApiParam,
  ApiBody,
} from '@nestjs/swagger';

@ApiTags('Features')
@ApiBearerAuth()
@Controller('features')
export class FeatureController {
  @Get()
  @ApiOperation({ summary: 'Get all features' })
  @ApiQuery({ name: 'page', type: Number, required: false, description: 'Page number' })
  @ApiQuery({ name: 'limit', type: Number, required: false, description: 'Items per page' })
  @ApiQuery({ name: 'search', type: String, required: false })
  @ApiResponse({ status: 200, description: 'List of features', type: [FeatureResponse] })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async findAll(@Query() query: QueryFeatureDto) {}

  @Get(':id')
  @ApiOperation({ summary: 'Get feature by ID' })
  @ApiParam({ name: 'id', description: 'Feature ID' })
  @ApiResponse({ status: 200, description: 'Feature found', type: FeatureResponse })
  @ApiResponse({ status: 404, description: 'Feature not found' })
  async findOne(@Param('id') id: string) {}

  @Post()
  @ApiOperation({ summary: 'Create a new feature' })
  @ApiBody({ type: CreateFeatureDto })
  @ApiResponse({ status: 201, description: 'Feature created', type: FeatureResponse })
  @ApiResponse({ status: 400, description: 'Validation error' })
  async create(@Body() dto: CreateFeatureDto) {}
}
```

### DTO Decorators
```typescript
import { ApiProperty, ApiPropertyOptional, PartialType, OmitType, PickType } from '@nestjs/swagger';

export class FeatureResponse {
  @ApiProperty({ example: 'cuid123456' })
  id: string;

  @ApiProperty({ example: 'Feature Name' })
  name: string;

  @ApiPropertyOptional({ example: 'Description text' })
  description?: string;

  @ApiProperty({ enum: ['ACTIVE', 'INACTIVE'], example: 'ACTIVE' })
  status: string;

  @ApiProperty({ example: '2024-01-01T00:00:00.000Z' })
  createdAt: Date;
}

export class CreateFeatureDto {
  @ApiProperty({ example: 'Feature Name', minLength: 2, maxLength: 200 })
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  name: string;

  @ApiPropertyOptional({ example: 'Description' })
  @IsOptional()
  @IsString()
  description?: string;
}

// Derived DTOs
export class UpdateFeatureDto extends PartialType(CreateFeatureDto) {}

export class CreateFeatureMinimalDto extends PickType(CreateFeatureDto, ['name']) {}

export class UpdateFeatureNameDto extends OmitType(UpdateFeatureDto, ['description']) {}
```

### Swagger Setup
```typescript
// main.ts
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const config = new DocumentBuilder()
    .setTitle('Kuark API')
    .setDescription('Kuark API Documentation')
    .setVersion('1.0')
    .addBearerAuth()
    .addTag('Auth', 'Authentication endpoints')
    .addTag('Features', 'Feature management')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document, {
    swaggerOptions: {
      persistAuthorization: true,
    },
  });

  await app.listen(3000);
}
```

## Validation Patterns

### Query DTO
```typescript
export class QueryFeatureDto {
  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 20, minimum: 1, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;

  @ApiPropertyOptional({ enum: FeatureStatus })
  @IsOptional()
  @IsEnum(FeatureStatus)
  status?: FeatureStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  endDate?: string;

  @ApiPropertyOptional({ enum: ['createdAt', 'name', 'status'] })
  @IsOptional()
  @IsEnum(['createdAt', 'name', 'status'])
  sortBy?: string = 'createdAt';

  @ApiPropertyOptional({ enum: ['asc', 'desc'] })
  @IsOptional()
  @IsEnum(['asc', 'desc'])
  sortOrder?: 'asc' | 'desc' = 'desc';
}
```

### Custom Validators
```typescript
// common/validators/is-cuid.validator.ts
import {
  registerDecorator,
  ValidationOptions,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';

@ValidatorConstraint({ async: false })
export class IsCuidConstraint implements ValidatorConstraintInterface {
  validate(value: any): boolean {
    if (typeof value !== 'string') return false;
    // CUID pattern: starts with 'c' followed by 24 alphanumeric chars
    return /^c[a-z0-9]{24}$/.test(value);
  }

  defaultMessage(): string {
    return 'Value must be a valid CUID';
  }
}

export function IsCuid(validationOptions?: ValidationOptions) {
  return function (object: Object, propertyName: string) {
    registerDecorator({
      target: object.constructor,
      propertyName: propertyName,
      options: validationOptions,
      constraints: [],
      validator: IsCuidConstraint,
    });
  };
}

// Usage
export class FeatureIdDto {
  @IsCuid({ message: 'Invalid feature ID format' })
  id: string;
}
```

## API Versioning

```typescript
// main.ts
import { VersioningType } from '@nestjs/common';

app.enableVersioning({
  type: VersioningType.URI,
  defaultVersion: '1',
});

// Controller
@Controller({
  path: 'features',
  version: '1',
})
export class FeatureV1Controller {}

@Controller({
  path: 'features',
  version: '2',
})
export class FeatureV2Controller {}

// Routes: /v1/features, /v2/features
```

## Validation Checklist

- [ ] Standard response format
- [ ] Error responses with details
- [ ] Correct HTTP status codes
- [ ] Swagger documentation complete
- [ ] DTO validation with class-validator
- [ ] Query params documented
- [ ] Pagination implemented
- [ ] Sorting implemented
- [ ] Search implemented
- [ ] API versioning (if needed)
