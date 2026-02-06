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
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiQuery,
} from '@nestjs/swagger';

import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { FullAccessGuard } from '../../auth/guards/full-access.guard';
import { CurrentUser } from '../../auth/decorators/current-user.decorator';
import { JwtPayload } from '../../auth/interfaces/jwt-payload.interface';

import { FeatureService } from './feature.service';
import { CreateFeatureDto } from './dto/create-feature.dto';
import { UpdateFeatureDto } from './dto/update-feature.dto';
import { QueryFeatureDto } from './dto/query-feature.dto';

@ApiTags('Features')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, FullAccessGuard)
@Controller('features')
export class FeatureController {
  constructor(private readonly featureService: FeatureService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new feature' })
  @ApiResponse({
    status: HttpStatus.CREATED,
    description: 'Feature created successfully',
  })
  @ApiResponse({ status: HttpStatus.BAD_REQUEST, description: 'Validation error' })
  @ApiResponse({ status: HttpStatus.UNAUTHORIZED, description: 'Unauthorized' })
  async create(
    @CurrentUser() user: JwtPayload,
    @Body() createFeatureDto: CreateFeatureDto,
  ) {
    return this.featureService.create(
      user.organizationId,
      createFeatureDto,
      user.sub,
    );
  }

  @Get()
  @ApiOperation({ summary: 'Get all features' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'search', required: false, type: String })
  @ApiResponse({ status: HttpStatus.OK, description: 'List of features' })
  async findAll(
    @CurrentUser() user: JwtPayload,
    @Query() query: QueryFeatureDto,
  ) {
    return this.featureService.findAll(user.organizationId, query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a feature by ID' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Feature details' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Feature not found' })
  async findOne(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.featureService.findOne(id, user.organizationId);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update a feature' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Feature updated' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Feature not found' })
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() updateFeatureDto: UpdateFeatureDto,
  ) {
    return this.featureService.update(
      id,
      user.organizationId,
      updateFeatureDto,
      user.sub,
    );
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a feature (soft delete)' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Feature deleted' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Feature not found' })
  async remove(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.featureService.remove(id, user.organizationId, user.sub);
  }
}
