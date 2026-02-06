import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  IsEnum,
  MinLength,
  MaxLength,
} from 'class-validator';
import { Transform } from 'class-transformer';

export enum FeatureStatus {
  DRAFT = 'DRAFT',
  ACTIVE = 'ACTIVE',
  INACTIVE = 'INACTIVE',
}

export class CreateFeatureDto {
  @ApiProperty({
    description: 'Feature name',
    example: 'My Feature',
    minLength: 2,
    maxLength: 200,
  })
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  @Transform(({ value }) => value?.trim())
  name: string;

  @ApiPropertyOptional({
    description: 'Feature description',
    example: 'This is a detailed description of the feature',
  })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  @Transform(({ value }) => value?.trim())
  description?: string;

  @ApiPropertyOptional({
    description: 'Feature status',
    enum: FeatureStatus,
    default: FeatureStatus.DRAFT,
  })
  @IsOptional()
  @IsEnum(FeatureStatus)
  status?: FeatureStatus = FeatureStatus.DRAFT;
}
