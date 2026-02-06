import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';

import { PrismaService } from '../../../prisma/prisma.service';

export interface FeatureJobData {
  featureId: string;
  organizationId: string;
  userId: string;
}

@Processor('feature')
export class FeatureProcessor extends WorkerHost {
  private readonly logger = new Logger(FeatureProcessor.name);

  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async process(job: Job<FeatureJobData>): Promise<void> {
    const { featureId, organizationId, userId } = job.data;

    this.logger.log(`Processing job ${job.name} for feature ${featureId}`);

    try {
      switch (job.name) {
        case 'feature-created':
          await this.handleFeatureCreated(featureId, organizationId, userId);
          break;
        case 'feature-updated':
          await this.handleFeatureUpdated(featureId, organizationId, userId);
          break;
        default:
          this.logger.warn(`Unknown job name: ${job.name}`);
      }
    } catch (error) {
      this.logger.error(
        `Failed to process job ${job.name}: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  private async handleFeatureCreated(
    featureId: string,
    organizationId: string,
    userId: string,
  ): Promise<void> {
    // Example: Send notification, update analytics, etc.
    this.logger.log(`Feature ${featureId} created by ${userId}`);

    // Verify feature exists with organizationId filter
    const feature = await this.prisma.feature.findFirst({
      where: {
        id: featureId,
        organizationId,
      },
    });

    if (!feature) {
      throw new Error(`Feature ${featureId} not found in org ${organizationId}`);
    }

    // Add your business logic here
    // Example: Create audit log
    // await this.prisma.auditLog.create({ ... });
  }

  private async handleFeatureUpdated(
    featureId: string,
    organizationId: string,
    userId: string,
  ): Promise<void> {
    this.logger.log(`Feature ${featureId} updated by ${userId}`);
    // Add your business logic here
  }

  @OnWorkerEvent('completed')
  onCompleted(job: Job<FeatureJobData>): void {
    this.logger.log(
      `Job ${job.id} (${job.name}) completed for feature ${job.data.featureId}`,
    );
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job<FeatureJobData>, error: Error): void {
    this.logger.error(
      `Job ${job.id} (${job.name}) failed for feature ${job.data.featureId}: ${error.message}`,
    );
  }

  @OnWorkerEvent('active')
  onActive(job: Job<FeatureJobData>): void {
    this.logger.debug(
      `Job ${job.id} (${job.name}) started for feature ${job.data.featureId}`,
    );
  }
}
