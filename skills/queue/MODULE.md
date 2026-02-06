# Queue Skill Module

> Background jobs with BullMQ for Kuark projects

## Triggers

- processor, job, BullMQ, queue
- worker, background, scheduled
- async, batch processing
- "job oluştur", "processor yaz", "queue ekle"

## Technology Stack

- BullMQ 5+
- Redis 7+
- @nestjs/bullmq
- Bull Board (monitoring)

## Core Pattern

### Module Registration
```typescript
// feature.module.ts
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { FeatureController } from './feature.controller';
import { FeatureService } from './feature.service';
import { FeatureProcessor } from './processors/feature.processor';

@Module({
  imports: [
    BullModule.registerQueue(
      { name: 'feature' },
      { name: 'feature-email' },
      { name: 'feature-notification' },
    ),
  ],
  controllers: [FeatureController],
  providers: [FeatureService, FeatureProcessor],
  exports: [FeatureService],
})
export class FeatureModule {}
```

### Processor Template (Kuark Pattern)
```typescript
// processors/feature.processor.ts
import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { PrismaService } from '@/prisma/prisma.service';

interface FeatureJobData {
  featureId: string;
  organizationId: string;
  action: 'process' | 'notify' | 'cleanup';
}

@Processor('feature')
export class FeatureProcessor extends WorkerHost {
  private readonly logger = new Logger(FeatureProcessor.name);

  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async process(job: Job<FeatureJobData>): Promise<void> {
    const { featureId, organizationId, action } = job.data;

    this.logger.log(`Processing job ${job.id}: ${action} for feature ${featureId}`);

    try {
      // Verify organization context
      const feature = await this.prisma.feature.findFirst({
        where: { id: featureId, organizationId },
      });

      if (!feature) {
        throw new Error(`Feature ${featureId} not found for org ${organizationId}`);
      }

      // Update progress
      await job.updateProgress(10);

      switch (action) {
        case 'process':
          await this.processFeature(feature, job);
          break;
        case 'notify':
          await this.notifyFeature(feature, job);
          break;
        case 'cleanup':
          await this.cleanupFeature(feature, job);
          break;
        default:
          throw new Error(`Unknown action: ${action}`);
      }

      await job.updateProgress(100);
      this.logger.log(`Job ${job.id} completed successfully`);
    } catch (error) {
      this.logger.error(`Job ${job.id} failed: ${error.message}`, error.stack);
      throw error; // Re-throw for retry
    }
  }

  private async processFeature(feature: any, job: Job): Promise<void> {
    // Processing logic
    await job.updateProgress(50);
    // More processing
  }

  private async notifyFeature(feature: any, job: Job): Promise<void> {
    // Notification logic
    await job.updateProgress(50);
  }

  private async cleanupFeature(feature: any, job: Job): Promise<void> {
    // Cleanup logic
    await job.updateProgress(50);
  }

  @OnWorkerEvent('completed')
  onCompleted(job: Job<FeatureJobData>) {
    this.logger.log(`Job ${job.id} completed`);
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job<FeatureJobData>, error: Error) {
    this.logger.error(`Job ${job.id} failed: ${error.message}`);
  }

  @OnWorkerEvent('progress')
  onProgress(job: Job<FeatureJobData>, progress: number) {
    this.logger.debug(`Job ${job.id} progress: ${progress}%`);
  }

  @OnWorkerEvent('stalled')
  onStalled(jobId: string) {
    this.logger.warn(`Job ${jobId} stalled`);
  }
}
```

### Adding Jobs to Queue
```typescript
// feature.service.ts
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class FeatureService {
  constructor(
    @InjectQueue('feature') private readonly featureQueue: Queue,
  ) {}

  async processFeatureAsync(featureId: string, organizationId: string) {
    // Add job with default options
    await this.featureQueue.add(
      'process',
      { featureId, organizationId, action: 'process' },
      {
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 5000,
        },
        removeOnComplete: true,
        removeOnFail: false,
      },
    );

    return { message: 'Processing started', jobId: featureId };
  }

  async scheduleFeature(featureId: string, organizationId: string, scheduledAt: Date) {
    // Add delayed job
    const delay = scheduledAt.getTime() - Date.now();

    await this.featureQueue.add(
      'process',
      { featureId, organizationId, action: 'process' },
      {
        delay: delay > 0 ? delay : 0,
        jobId: `feature-${featureId}`,
        attempts: 3,
        backoff: { type: 'exponential', delay: 5000 },
      },
    );

    return { message: 'Feature scheduled', scheduledAt };
  }

  async addBatchJobs(items: Array<{ id: string; organizationId: string }>) {
    // Batch add jobs
    const jobs = items.map((item) => ({
      name: 'process',
      data: { featureId: item.id, organizationId: item.organizationId, action: 'process' },
      opts: {
        attempts: 3,
        backoff: { type: 'exponential', delay: 5000 },
      },
    }));

    await this.featureQueue.addBulk(jobs);

    return { message: `${items.length} jobs added` };
  }

  async cancelJob(featureId: string) {
    // Remove scheduled job
    await this.featureQueue.remove(`feature-${featureId}`);
    return { message: 'Job cancelled' };
  }
}
```

### Recurring Jobs (Cron)
```typescript
// Add repeatable job
await this.featureQueue.add(
  'cleanup',
  { action: 'cleanup' },
  {
    repeat: {
      pattern: '0 0 * * *', // Every day at midnight
    },
    jobId: 'daily-cleanup',
  },
);

// Add interval job
await this.featureQueue.add(
  'sync',
  { action: 'sync' },
  {
    repeat: {
      every: 60000, // Every minute
    },
    jobId: 'sync-job',
  },
);
```

### Job Options Reference

```typescript
interface JobOptions {
  // Retry configuration
  attempts: number;           // Number of retry attempts
  backoff: {
    type: 'fixed' | 'exponential';
    delay: number;            // Base delay in ms
  };

  // Timing
  delay: number;              // Delay before processing (ms)
  timeout: number;            // Job timeout (ms)

  // Job management
  jobId: string;              // Unique job ID
  priority: number;           // Job priority (lower = higher)

  // Cleanup
  removeOnComplete: boolean | number;  // Remove after complete (or keep N)
  removeOnFail: boolean | number;      // Remove on failure (or keep N)

  // Repeatable
  repeat: {
    pattern: string;          // Cron pattern
    every: number;            // Interval in ms
    limit: number;            // Max repetitions
    endDate: Date;            // End date
  };
}
```

## Batch Processing Pattern
```typescript
const BATCH_SIZE = 100;

@Processor('feature-batch')
export class FeatureBatchProcessor extends WorkerHost {
  async process(job: Job<BatchJobData>): Promise<void> {
    const { items, organizationId } = job.data;

    for (let i = 0; i < items.length; i += BATCH_SIZE) {
      const batch = items.slice(i, i + BATCH_SIZE);
      const batchNumber = Math.floor(i / BATCH_SIZE) + 1;

      this.logger.log(`Processing batch ${batchNumber}`);

      await Promise.all(
        batch.map((item) => this.processItem(item, organizationId)),
      );

      const progress = Math.round(((i + BATCH_SIZE) / items.length) * 100);
      await job.updateProgress(Math.min(progress, 100));
    }
  }

  private async processItem(item: any, organizationId: string) {
    // Process single item
  }
}
```

## Bull Board (Monitoring)
```typescript
// app.module.ts
import { BullBoardModule } from '@bull-board/nestjs';
import { ExpressAdapter } from '@bull-board/express';
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter';

@Module({
  imports: [
    BullBoardModule.forRoot({
      route: '/admin/queues',
      adapter: ExpressAdapter,
    }),
    BullBoardModule.forFeature({
      name: 'feature',
      adapter: BullMQAdapter,
    }),
  ],
})
export class AppModule {}
```

## Validation Checklist

- [ ] Processor extends WorkerHost
- [ ] Logger configured
- [ ] organizationId in job data
- [ ] Error handling with try/catch
- [ ] Progress updates
- [ ] Event handlers (@OnWorkerEvent)
- [ ] Retry configuration
- [ ] Job ID for deduplication
- [ ] Backoff strategy
- [ ] Batch processing for large datasets
