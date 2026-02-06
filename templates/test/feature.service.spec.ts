import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { FeatureService } from './feature.service';
import { PrismaService } from '../../common/prisma/prisma.service';

describe('FeatureService', () => {
  let service: FeatureService;
  let prisma: PrismaService;

  const mockOrganizationId = 'org-test-123';
  const mockUserId = 'user-test-123';

  const mockFeature = {
    id: 'feature-1',
    name: 'Test Feature',
    organizationId: mockOrganizationId,
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
  };

  const mockPrisma = {
    feature: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FeatureService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<FeatureService>(FeatureService);
    prisma = module.get<PrismaService>(PrismaService);

    jest.clearAllMocks();
  });

  describe('findAll', () => {
    it('should return features filtered by organizationId', async () => {
      mockPrisma.feature.findMany.mockResolvedValue([mockFeature]);
      mockPrisma.feature.count.mockResolvedValue(1);

      const result = await service.findAll(mockOrganizationId);

      expect(result.data).toHaveLength(1);
      expect(result.pagination.total).toBe(1);
      expect(mockPrisma.feature.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ organizationId: mockOrganizationId }),
        }),
      );
    });

    it('should not return features from other organizations', async () => {
      mockPrisma.feature.findMany.mockResolvedValue([]);
      mockPrisma.feature.count.mockResolvedValue(0);

      const result = await service.findAll('other-org-id');

      expect(result.data).toHaveLength(0);
      expect(mockPrisma.feature.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ organizationId: 'other-org-id' }),
        }),
      );
    });

    it('should exclude soft-deleted records', async () => {
      mockPrisma.feature.findMany.mockResolvedValue([]);

      await service.findAll(mockOrganizationId);

      expect(mockPrisma.feature.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deletedAt: null }),
        }),
      );
    });
  });

  describe('findOne', () => {
    it('should return a feature by id and organizationId', async () => {
      mockPrisma.feature.findFirst.mockResolvedValue(mockFeature);

      const result = await service.findOne('feature-1', mockOrganizationId);

      expect(result).toEqual(mockFeature);
      expect(mockPrisma.feature.findFirst).toHaveBeenCalledWith({
        where: { id: 'feature-1', organizationId: mockOrganizationId },
      });
    });

    it('should throw NotFoundException when feature not found', async () => {
      mockPrisma.feature.findFirst.mockResolvedValue(null);

      await expect(
        service.findOne('nonexistent', mockOrganizationId),
      ).rejects.toThrow(NotFoundException);
    });

    it('should not return feature from another organization', async () => {
      mockPrisma.feature.findFirst.mockResolvedValue(null);

      await expect(
        service.findOne('feature-1', 'other-org-id'),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('create', () => {
    const createDto = { name: 'New Feature' };

    it('should create a feature with organizationId', async () => {
      mockPrisma.feature.create.mockResolvedValue({
        ...mockFeature,
        ...createDto,
      });

      const result = await service.create(
        mockOrganizationId,
        createDto,
        mockUserId,
      );

      expect(result.name).toBe('New Feature');
      expect(mockPrisma.feature.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          ...createDto,
          organizationId: mockOrganizationId,
          createdBy: mockUserId,
        }),
      });
    });
  });

  describe('update', () => {
    const updateDto = { name: 'Updated Feature' };

    it('should update only if feature belongs to organization', async () => {
      mockPrisma.feature.findFirst.mockResolvedValue(mockFeature);
      mockPrisma.feature.update.mockResolvedValue({
        ...mockFeature,
        ...updateDto,
      });

      const result = await service.update(
        'feature-1',
        mockOrganizationId,
        updateDto,
      );

      expect(result.name).toBe('Updated Feature');
    });

    it('should throw NotFoundException for wrong organization', async () => {
      mockPrisma.feature.findFirst.mockResolvedValue(null);

      await expect(
        service.update('feature-1', 'other-org-id', updateDto),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
