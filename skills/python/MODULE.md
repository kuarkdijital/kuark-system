# Python Skill Module

> FastAPI microservice development for Kuark projects

## Triggers

- FastAPI, microservice, Python
- Pydantic, async, endpoint
- "Python API yaz", "microservice oluştur"

## Technology Stack

- Python 3.11+
- FastAPI
- Pydantic v2
- SQLAlchemy 2.0 / Prisma Python
- uvicorn
- pytest
- httpx

## Project Structure

```
app/
├── main.py
├── config.py
├── database.py
├── api/
│   ├── __init__.py
│   ├── deps.py          # Dependencies
│   └── v1/
│       ├── __init__.py
│       ├── router.py    # Main router
│       └── endpoints/
│           ├── __init__.py
│           ├── auth.py
│           └── features.py
├── core/
│   ├── __init__.py
│   ├── security.py
│   └── exceptions.py
├── models/
│   ├── __init__.py
│   └── feature.py
├── schemas/
│   ├── __init__.py
│   └── feature.py
├── services/
│   ├── __init__.py
│   └── feature.py
└── tests/
    ├── __init__.py
    ├── conftest.py
    └── test_features.py
```

## Core Patterns

### Main Application
```python
# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.api.v1.router import api_router
from app.config import settings
from app.database import engine

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    yield
    # Shutdown

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Router
app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
```

### Configuration
```python
# app/config.py
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    PROJECT_NAME: str = "Kuark API"
    API_V1_STR: str = "/api/v1"

    # Database
    DATABASE_URL: str

    # Auth
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 1 day

    # CORS
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000"]

    class Config:
        env_file = ".env"
        case_sensitive = True

@lru_cache()
def get_settings() -> Settings:
    return Settings()

settings = get_settings()
```

### Database Setup
```python
# app/database.py
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

engine = create_async_engine(settings.DATABASE_URL, echo=False)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

class Base(DeclarativeBase):
    pass

async def get_db() -> AsyncSession:
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()
```

### Model
```python
# app/models/feature.py
from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum

from app.database import Base

class FeatureStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"

class Feature(Base):
    __tablename__ = "features"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    status = Column(SQLEnum(FeatureStatus), default=FeatureStatus.ACTIVE)

    # Multi-tenant
    organization_id = Column(String, ForeignKey("organizations.id"), nullable=False)

    # Audit
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    deleted_at = Column(DateTime, nullable=True)

    # Relations
    organization = relationship("Organization", back_populates="features")
```

### Schemas (Pydantic)
```python
# app/schemas/feature.py
from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum
from typing import Optional

class FeatureStatus(str, Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"

# Base
class FeatureBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=200)
    description: Optional[str] = None
    status: FeatureStatus = FeatureStatus.ACTIVE

# Create
class FeatureCreate(FeatureBase):
    pass

# Update
class FeatureUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=200)
    description: Optional[str] = None
    status: Optional[FeatureStatus] = None

# Response
class FeatureResponse(FeatureBase):
    id: str
    organization_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# List Response
class FeatureListResponse(BaseModel):
    data: list[FeatureResponse]
    pagination: dict

# Query
class FeatureQuery(BaseModel):
    page: int = Field(default=1, ge=1)
    limit: int = Field(default=20, ge=1, le=100)
    search: Optional[str] = None
    status: Optional[FeatureStatus] = None
```

### Service
```python
# app/services/feature.py
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from typing import Optional
import uuid

from app.models.feature import Feature
from app.schemas.feature import FeatureCreate, FeatureUpdate, FeatureQuery
from app.core.exceptions import NotFoundException

class FeatureService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(
        self,
        organization_id: str,
        data: FeatureCreate,
        user_id: Optional[str] = None
    ) -> Feature:
        feature = Feature(
            id=str(uuid.uuid4()),
            organization_id=organization_id,
            **data.model_dump()
        )
        self.db.add(feature)
        await self.db.commit()
        await self.db.refresh(feature)
        return feature

    async def get_all(
        self,
        organization_id: str,
        query: FeatureQuery
    ) -> tuple[list[Feature], int]:
        # Base query
        stmt = select(Feature).where(
            Feature.organization_id == organization_id,
            Feature.deleted_at.is_(None)
        )

        # Filters
        if query.search:
            stmt = stmt.where(Feature.name.ilike(f"%{query.search}%"))
        if query.status:
            stmt = stmt.where(Feature.status == query.status)

        # Count
        count_stmt = select(func.count()).select_from(stmt.subquery())
        total = await self.db.scalar(count_stmt) or 0

        # Pagination
        stmt = stmt.offset((query.page - 1) * query.limit).limit(query.limit)
        stmt = stmt.order_by(Feature.created_at.desc())

        result = await self.db.execute(stmt)
        features = result.scalars().all()

        return list(features), total

    async def get_one(self, id: str, organization_id: str) -> Feature:
        stmt = select(Feature).where(
            Feature.id == id,
            Feature.organization_id == organization_id,
            Feature.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        feature = result.scalar_one_or_none()

        if not feature:
            raise NotFoundException("Feature not found")

        return feature

    async def update(
        self,
        id: str,
        organization_id: str,
        data: FeatureUpdate
    ) -> Feature:
        feature = await self.get_one(id, organization_id)

        update_data = data.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(feature, key, value)

        await self.db.commit()
        await self.db.refresh(feature)
        return feature

    async def delete(self, id: str, organization_id: str) -> None:
        feature = await self.get_one(id, organization_id)
        feature.deleted_at = datetime.utcnow()
        await self.db.commit()
```

### Endpoint
```python
# app/api/v1/endpoints/features.py
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.api.deps import get_current_user
from app.schemas.feature import (
    FeatureCreate,
    FeatureUpdate,
    FeatureResponse,
    FeatureListResponse,
    FeatureQuery
)
from app.schemas.user import UserInToken
from app.services.feature import FeatureService

router = APIRouter()

@router.post("", response_model=FeatureResponse, status_code=status.HTTP_201_CREATED)
async def create_feature(
    data: FeatureCreate,
    db: AsyncSession = Depends(get_db),
    current_user: UserInToken = Depends(get_current_user)
):
    service = FeatureService(db)
    return await service.create(
        organization_id=current_user.organization_id,
        data=data,
        user_id=current_user.sub
    )

@router.get("", response_model=FeatureListResponse)
async def get_features(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    search: str | None = None,
    status: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: UserInToken = Depends(get_current_user)
):
    service = FeatureService(db)
    query = FeatureQuery(page=page, limit=limit, search=search, status=status)
    features, total = await service.get_all(current_user.organization_id, query)

    return {
        "data": features,
        "pagination": {
            "page": page,
            "limit": limit,
            "total": total,
            "total_pages": (total + limit - 1) // limit
        }
    }

@router.get("/{id}", response_model=FeatureResponse)
async def get_feature(
    id: str,
    db: AsyncSession = Depends(get_db),
    current_user: UserInToken = Depends(get_current_user)
):
    service = FeatureService(db)
    return await service.get_one(id, current_user.organization_id)

@router.put("/{id}", response_model=FeatureResponse)
async def update_feature(
    id: str,
    data: FeatureUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: UserInToken = Depends(get_current_user)
):
    service = FeatureService(db)
    return await service.update(id, current_user.organization_id, data)

@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_feature(
    id: str,
    db: AsyncSession = Depends(get_db),
    current_user: UserInToken = Depends(get_current_user)
):
    service = FeatureService(db)
    await service.delete(id, current_user.organization_id)
```

### Dependencies
```python
# app/api/deps.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError

from app.config import settings
from app.schemas.user import UserInToken

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> UserInToken:
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.SECRET_KEY,
            algorithms=["HS256"]
        )
        return UserInToken(**payload)
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials"
        )
```

## Validation Checklist

- [ ] Pydantic models for all schemas
- [ ] Async database operations
- [ ] organization_id filtering
- [ ] Soft delete pattern
- [ ] Pagination implemented
- [ ] JWT authentication
- [ ] Error handling
- [ ] Type hints everywhere
- [ ] Tests with pytest
