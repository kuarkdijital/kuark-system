import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../app.module';
import { PrismaService } from '../../common/prisma/prisma.service';

describe('Feature (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let authToken: string;

  const testOrganizationId = 'org-e2e-test';

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );

    await app.init();
    prisma = app.get(PrismaService);

    // Get auth token for test user
    const loginResponse = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        email: 'e2e-test@kuark.pro',
        password: 'test-password-123',
      });

    authToken = loginResponse.body.data.accessToken;
  });

  afterAll(async () => {
    // Cleanup test data
    await prisma.feature.deleteMany({
      where: { organizationId: testOrganizationId },
    });
    await app.close();
  });

  describe('POST /api/features', () => {
    it('should create a feature (201)', () => {
      return request(app.getHttpServer())
        .post('/api/features')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: 'E2E Test Feature' })
        .expect(201)
        .expect((res) => {
          expect(res.body.data.name).toBe('E2E Test Feature');
          expect(res.body.data.organizationId).toBe(testOrganizationId);
        });
    });

    it('should reject without auth (401)', () => {
      return request(app.getHttpServer())
        .post('/api/features')
        .send({ name: 'No Auth' })
        .expect(401);
    });

    it('should reject invalid body (400)', () => {
      return request(app.getHttpServer())
        .post('/api/features')
        .set('Authorization', `Bearer ${authToken}`)
        .send({})
        .expect(400);
    });
  });

  describe('GET /api/features', () => {
    it('should list features for organization (200)', () => {
      return request(app.getHttpServer())
        .get('/api/features')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.data).toBeInstanceOf(Array);
          expect(res.body.pagination).toBeDefined();
          // Verify all returned items belong to the organization
          res.body.data.forEach((item: { organizationId: string }) => {
            expect(item.organizationId).toBe(testOrganizationId);
          });
        });
    });
  });

  describe('GET /api/features/:id', () => {
    it('should return 404 for non-existent feature', () => {
      return request(app.getHttpServer())
        .get('/api/features/nonexistent-id')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);
    });
  });

  describe('Multi-tenant isolation', () => {
    it('should not return features from other organizations', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/features')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      response.body.data.forEach((item: { organizationId: string }) => {
        expect(item.organizationId).toBe(testOrganizationId);
        expect(item.organizationId).not.toBe('other-organization');
      });
    });
  });
});
