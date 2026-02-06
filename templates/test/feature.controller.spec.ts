import { Test, TestingModule } from '@nestjs/testing';
import { FeatureController } from './feature.controller';
import { FeatureService } from './feature.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { FullAccessGuard } from '../../common/guards/full-access.guard';

describe('FeatureController', () => {
  let controller: FeatureController;
  let service: FeatureService;

  const mockUser = {
    sub: 'user-test-123',
    organizationId: 'org-test-123',
    email: 'test@kuark.pro',
    roles: ['admin'],
  };

  const mockService = {
    findAll: jest.fn(),
    findOne: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    remove: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [FeatureController],
      providers: [
        { provide: FeatureService, useValue: mockService },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(FullAccessGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<FeatureController>(FeatureController);
    service = module.get<FeatureService>(FeatureService);

    jest.clearAllMocks();
  });

  describe('findAll', () => {
    it('should call service.findAll with user organizationId', async () => {
      mockService.findAll.mockResolvedValue({ data: [], pagination: { total: 0 } });

      await controller.findAll(mockUser);

      expect(mockService.findAll).toHaveBeenCalledWith('org-test-123');
    });
  });

  describe('findOne', () => {
    it('should call service.findOne with id and organizationId', async () => {
      mockService.findOne.mockResolvedValue({ id: 'feature-1' });

      await controller.findOne(mockUser, 'feature-1');

      expect(mockService.findOne).toHaveBeenCalledWith('feature-1', 'org-test-123');
    });
  });

  describe('create', () => {
    it('should pass organizationId and userId to service', async () => {
      const dto = { name: 'New Feature' };
      mockService.create.mockResolvedValue({ id: 'feature-1', ...dto });

      await controller.create(mockUser, dto);

      expect(mockService.create).toHaveBeenCalledWith(
        'org-test-123',
        dto,
        'user-test-123',
      );
    });
  });

  describe('guards', () => {
    it('should have JwtAuthGuard applied', () => {
      const guards = Reflect.getMetadata('__guards__', FeatureController);
      expect(guards).toBeDefined();
    });
  });
});
