# NestJS Skill Module

> Backend API development with NestJS for Kuark projects

## Triggers

- module, controller, service, guard
- NestJS, pipe, interceptor, middleware
- API endpoint, CRUD, REST
- "module oluştur", "servis yaz", "controller ekle"

## Technology Stack

- NestJS 10+
- TypeScript strict mode
- Prisma ORM
- BullMQ for queues
- JWT authentication (Passport)
- class-validator, class-transformer
- @nestjs/swagger

## Core Patterns

### Module Structure
```
src/modules/[feature]/
├── [feature].module.ts
├── [feature].controller.ts
├── [feature].service.ts
├── dto/
│   ├── create-[feature].dto.ts
│   ├── update-[feature].dto.ts
│   └── query-[feature].dto.ts
├── processors/
│   └── [feature].processor.ts
├── guards/
│   └── [feature].guard.ts (if needed)
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

### Controller Template (Kuark Pattern)
```typescript
import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { FullAccessGuard } from '../auth/guards/full-access.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { FeatureService } from './feature.service';
import { CreateFeatureDto, UpdateFeatureDto, QueryFeatureDto } from './dto';

interface JwtPayload {
  sub: string;
  email: string;
  organizationId: string;
  role: string;
}

@ApiTags('Features')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, FullAccessGuard)
@Controller('features')
export class FeatureController {
  private readonly logger = new Logger(FeatureController.name);

  constructor(private readonly featureService: FeatureService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new feature' })
  @ApiResponse({ status: 201, description: 'Feature created successfully' })
  async create(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateFeatureDto,
  ) {
    return this.featureService.create(user.organizationId, dto, user.sub);
  }

  @Get()
  @ApiOperation({ summary: 'Get all features' })
  @ApiQuery({ name: 'page', type: Number, required: false })
  @ApiQuery({ name: 'limit', type: Number, required: false })
  async findAll(
    @CurrentUser() user: JwtPayload,
    @Query() query: QueryFeatureDto,
  ) {
    return this.featureService.findAll(user.organizationId, query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a feature by ID' })
  @ApiResponse({ status: 200, description: 'Feature found' })
  @ApiResponse({ status: 404, description: 'Feature not found' })
  async findOne(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.featureService.findOne(id, user.organizationId);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update a feature' })
  @ApiResponse({ status: 200, description: 'Feature updated successfully' })
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: UpdateFeatureDto,
  ) {
    return this.featureService.update(id, user.organizationId, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a feature' })
  @ApiResponse({ status: 204, description: 'Feature deleted successfully' })
  async delete(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.featureService.delete(id, user.organizationId);
  }
}
```

### Service Template (Kuark Pattern)
```typescript
import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PrismaService } from '@/prisma/prisma.service';
import { CreateFeatureDto, UpdateFeatureDto, QueryFeatureDto } from './dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class FeatureService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue('feature') private readonly featureQueue: Queue,
  ) {}

  async create(organizationId: string, dto: CreateFeatureDto, userId?: string) {
    return this.prisma.feature.create({
      data: {
        ...dto,
        organizationId,
        createdBy: userId,
      },
    });
  }

  async findAll(organizationId: string, query: QueryFeatureDto) {
    const { page = 1, limit = 20, search, status } = query;

    const where: Prisma.FeatureWhereInput = {
      organizationId,
      deletedAt: null,
      ...(status && { status }),
      ...(search && {
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
        ],
      }),
    };

    const [data, total] = await Promise.all([
      this.prisma.feature.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.feature.count({ where }),
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

  async findOne(id: string, organizationId: string) {
    const item = await this.prisma.feature.findFirst({
      where: { id, organizationId, deletedAt: null },
    });

    if (!item) {
      throw new NotFoundException('Feature not found');
    }

    return item;
  }

  async update(id: string, organizationId: string, dto: UpdateFeatureDto) {
    await this.findOne(id, organizationId);

    return this.prisma.feature.update({
      where: { id },
      data: dto,
    });
  }

  async delete(id: string, organizationId: string) {
    await this.findOne(id, organizationId);

    // Soft delete
    return this.prisma.feature.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }
}
```

### DTO Templates
```typescript
// create-feature.dto.ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  IsEnum,
  MinLength,
  MaxLength,
} from 'class-validator';
import { FeatureStatus } from '@prisma/client';

export class CreateFeatureDto {
  @ApiProperty({ example: 'Feature Name' })
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  name: string;

  @ApiPropertyOptional({ example: 'Feature description' })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @ApiPropertyOptional({ enum: FeatureStatus })
  @IsOptional()
  @IsEnum(FeatureStatus)
  status?: FeatureStatus;
}

// update-feature.dto.ts
import { PartialType } from '@nestjs/swagger';
import { CreateFeatureDto } from './create-feature.dto';

export class UpdateFeatureDto extends PartialType(CreateFeatureDto) {}

// query-feature.dto.ts
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsNumber, IsString, IsEnum, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';
import { FeatureStatus } from '@prisma/client';

export class QueryFeatureDto {
  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  page?: number;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(100)
  limit?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ enum: FeatureStatus })
  @IsOptional()
  @IsEnum(FeatureStatus)
  status?: FeatureStatus;
}
```

## Required Patterns

### Guards
- JwtAuthGuard: Always required on controllers
- FullAccessGuard: Required for protected operations
- RolesGuard: For role-based access control

### organizationId
- MUST be in every service method as first parameter
- MUST be in every Prisma query's where clause
- Get from @CurrentUser() decorator

### Error Handling
```typescript
// Use NestJS exceptions
throw new NotFoundException('Resource not found');
throw new BadRequestException('Invalid input');
throw new UnauthorizedException('Not authenticated');
throw new ForbiddenException('Not authorized');
```

### Logging
```typescript
private readonly logger = new Logger(FeatureService.name);

this.logger.log(`Processing feature ${id}`);
this.logger.warn(`Unusual condition: ${condition}`);
this.logger.error(`Failed to process: ${error.message}`, error.stack);
```

## Validation Checklist

- [ ] JwtAuthGuard applied
- [ ] FullAccessGuard applied
- [ ] organizationId in all queries
- [ ] DTOs with class-validator
- [ ] Swagger decorators
- [ ] Soft delete pattern
- [ ] Pagination on list endpoints
- [ ] Error handling
- [ ] Logger usage
