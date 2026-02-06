import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

import { PrismaService } from '../../prisma/prisma.service';
import { CreateFeatureDto } from './dto/create-feature.dto';
import { UpdateFeatureDto } from './dto/update-feature.dto';
import { QueryFeatureDto } from './dto/query-feature.dto';

@Injectable()
export class FeatureService {
  private readonly logger = new Logger(FeatureService.name);

  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue('feature') private readonly featureQueue: Queue,
  ) {}

  async create(
    organizationId: string,
    dto: CreateFeatureDto,
    userId: string,
  ) {
    const feature = await this.prisma.feature.create({
      data: {
        ...dto,
        organizationId,
        createdBy: userId,
        updatedBy: userId,
      },
    });

    this.logger.log(`Feature created: ${feature.id}`);

    // Optional: Queue a background job
    await this.featureQueue.add('feature-created', {
      featureId: feature.id,
      organizationId,
      userId,
    });

    return feature;
  }

  async findAll(organizationId: string, query: QueryFeatureDto) {
    const { page = 1, limit = 20, search, status } = query;
    const skip = (page - 1) * limit;

    const where = {
      organizationId,
      deletedAt: null,
      ...(search && {
        OR: [
          { name: { contains: search, mode: 'insensitive' as const } },
          { description: { contains: search, mode: 'insensitive' as const } },
        ],
      }),
      ...(status && { status }),
    };

    const [data, total] = await Promise.all([
      this.prisma.feature.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
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
    const feature = await this.prisma.feature.findFirst({
      where: {
        id,
        organizationId,
        deletedAt: null,
      },
    });

    if (!feature) {
      throw new NotFoundException('Feature not found');
    }

    return feature;
  }

  async update(
    id: string,
    organizationId: string,
    dto: UpdateFeatureDto,
    userId: string,
  ) {
    // Verify ownership
    await this.findOne(id, organizationId);

    const feature = await this.prisma.feature.update({
      where: { id },
      data: {
        ...dto,
        updatedBy: userId,
      },
    });

    this.logger.log(`Feature updated: ${feature.id}`);

    return feature;
  }

  async remove(id: string, organizationId: string, userId: string) {
    // Verify ownership
    await this.findOne(id, organizationId);

    // Soft delete
    const feature = await this.prisma.feature.update({
      where: { id },
      data: {
        deletedAt: new Date(),
        deletedBy: userId,
      },
    });

    this.logger.log(`Feature soft deleted: ${feature.id}`);

    return { success: true, message: 'Feature deleted successfully' };
  }
}
