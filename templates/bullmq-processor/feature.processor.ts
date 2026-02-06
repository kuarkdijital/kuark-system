import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Logger, Injectable } from '@nestjs/common';
import { Job } from 'bullmq';

import { PrismaService } from '../../prisma/prisma.service';

// ============================================
// JOB DATA INTERFACES
// ============================================

export interface FeatureCreatedJobData {
  featureId: string;
  organizationId: string;
  userId: string;
}

export interface FeatureUpdatedJobData {
  featureId: string;
  organizationId: string;
  userId: string;
  changes: Record<string, unknown>;
}

export interface FeatureBulkJobData {
  featureIds: string[];
  organizationId: string;
  userId: string;
  action: 'activate' | 'deactivate' | 'delete';
}

export type FeatureJobData =
  | FeatureCreatedJobData
  | FeatureUpdatedJobData
  | FeatureBulkJobData;

// ============================================
// PROCESSOR
// ============================================

@Processor('feature', {
  concurrency: 5, // Max concurrent jobs
  limiter: {
    max: 100,
    duration: 60000, // 100 jobs per minute
  },
})
export class FeatureProcessor extends WorkerHost {
  private readonly logger = new Logger(FeatureProcessor.name);

  constructor(private readonly prisma: PrismaService) {
    super();
  }

  // ============================================
  // MAIN PROCESS METHOD
  // ============================================

  async process(job: Job<FeatureJobData>): Promise<unknown> {
    this.logger.log(`Processing job ${job.id} (${job.name})`);

    try {
      switch (job.name) {
        case 'feature.created':
          return await this.handleFeatureCreated(
            job as Job<FeatureCreatedJobData>,
          );

        case 'feature.updated':
          return await this.handleFeatureUpdated(
            job as Job<FeatureUpdatedJobData>,
          );

        case 'feature.bulk':
          return await this.handleBulkOperation(
            job as Job<FeatureBulkJobData>,
          );

        default:
          this.logger.warn(`Unknown job name: ${job.name}`);
          return null;
      }
    } catch (error) {
      this.logger.error(
        `Job ${job.id} failed: ${error.message}`,
        error.stack,
      );
      throw error; // Re-throw for retry mechanism
    }
  }

  // ============================================
  // JOB HANDLERS
  // ============================================

  private async handleFeatureCreated(
    job: Job<FeatureCreatedJobData>,
  ): Promise<void> {
    const { featureId, organizationId, userId } = job.data;

    // ZORUNLU: organizationId ile veri doğrulama
    const feature = await this.prisma.feature.findFirst({
      where: {
        id: featureId,
        organizationId,
        deletedAt: null,
      },
    });

    if (!feature) {
      throw new Error(
        `Feature ${featureId} not found in organization ${organizationId}`,
      );
    }

    // Business logic: Send notification, update analytics, etc.
    this.logger.log(
      `Feature "${feature.name}" created by user ${userId}`,
    );

    // Example: Create audit log
    await this.prisma.auditLog.create({
      data: {
        organizationId,
        userId,
        action: 'FEATURE_CREATED',
        resourceType: 'Feature',
        resourceId: featureId,
        metadata: { featureName: feature.name },
      },
    });
  }

  private async handleFeatureUpdated(
    job: Job<FeatureUpdatedJobData>,
  ): Promise<void> {
    const { featureId, organizationId, userId, changes } = job.data;

    const feature = await this.prisma.feature.findFirst({
      where: {
        id: featureId,
        organizationId,
      },
    });

    if (!feature) {
      throw new Error(
        `Feature ${featureId} not found in organization ${organizationId}`,
      );
    }

    this.logger.log(
      `Feature "${feature.name}" updated by user ${userId}`,
    );

    // Log changes
    await this.prisma.auditLog.create({
      data: {
        organizationId,
        userId,
        action: 'FEATURE_UPDATED',
        resourceType: 'Feature',
        resourceId: featureId,
        metadata: { changes },
      },
    });
  }

  private async handleBulkOperation(
    job: Job<FeatureBulkJobData>,
  ): Promise<{ processed: number; failed: number }> {
    const { featureIds, organizationId, userId, action } = job.data;

    let processed = 0;
    let failed = 0;

    for (const featureId of featureIds) {
      try {
        // Verify ownership
        const feature = await this.prisma.feature.findFirst({
          where: {
            id: featureId,
            organizationId,
            deletedAt: null,
          },
        });

        if (!feature) {
          failed++;
          continue;
        }

        switch (action) {
          case 'activate':
            await this.prisma.feature.update({
              where: { id: featureId },
              data: { status: 'ACTIVE', updatedBy: userId },
            });
            break;

          case 'deactivate':
            await this.prisma.feature.update({
              where: { id: featureId },
              data: { status: 'INACTIVE', updatedBy: userId },
            });
            break;

          case 'delete':
            await this.prisma.feature.update({
              where: { id: featureId },
              data: {
                deletedAt: new Date(),
                deletedBy: userId,
              },
            });
            break;
        }

        processed++;

        // Update progress
        await job.updateProgress((processed / featureIds.length) * 100);
      } catch (error) {
        this.logger.error(
          `Failed to process feature ${featureId}: ${error.message}`,
        );
        failed++;
      }
    }

    return { processed, failed };
  }

  // ============================================
  // WORKER EVENTS
  // ============================================

  @OnWorkerEvent('active')
  onActive(job: Job<FeatureJobData>): void {
    this.logger.debug(`Job ${job.id} started processing`);
  }

  @OnWorkerEvent('completed')
  onCompleted(job: Job<FeatureJobData>, result: unknown): void {
    this.logger.log(
      `Job ${job.id} completed successfully`,
      result ? JSON.stringify(result) : undefined,
    );
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job<FeatureJobData>, error: Error): void {
    this.logger.error(
      `Job ${job.id} failed after ${job.attemptsMade} attempts: ${error.message}`,
    );

    // Notify on final failure (after all retries)
    if (job.attemptsMade >= (job.opts.attempts || 3)) {
      // Send alert, create incident, etc.
      this.logger.error(`Job ${job.id} exhausted all retry attempts`);
    }
  }

  @OnWorkerEvent('progress')
  onProgress(job: Job<FeatureJobData>, progress: number): void {
    this.logger.debug(`Job ${job.id} progress: ${progress}%`);
  }

  @OnWorkerEvent('stalled')
  onStalled(jobId: string): void {
    this.logger.warn(`Job ${jobId} has stalled`);
  }
}

// ============================================
// PROCESSOR CHECKLIST
// ============================================
// [✓] WorkerHost extended
// [✓] organizationId validation in all handlers
// [✓] Error handling with re-throw for retries
// [✓] Logger integration
// [✓] Worker events handled
// [✓] Job progress tracking
// [✓] Concurrency and rate limiting configured
// ============================================
