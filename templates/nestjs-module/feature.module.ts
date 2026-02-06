import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';

import { FeatureController } from './feature.controller';
import { FeatureService } from './feature.service';
import { FeatureProcessor } from './processors/feature.processor';

@Module({
  imports: [
    BullModule.registerQueue({
      name: 'feature',
      defaultJobOptions: {
        removeOnComplete: 100,
        removeOnFail: 50,
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 1000,
        },
      },
    }),
  ],
  controllers: [FeatureController],
  providers: [FeatureService, FeatureProcessor],
  exports: [FeatureService],
})
export class FeatureModule {}
