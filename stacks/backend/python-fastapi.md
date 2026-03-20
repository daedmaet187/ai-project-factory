# Backend Stack: Python + FastAPI

Use this when: team prefers Python, ML/AI integration needed, or existing Python infrastructure.

---

## When to Choose FastAPI vs Node.js

| Scenario | FastAPI | Node.js/Express |
|---|---|---|
| ML model inference | ✅ Native | ❌ (subprocess) |
| Python team | ✅ | ❌ |
| Pandas/NumPy integration | ✅ | ❌ |
| Pydantic schema-first | ✅ Built-in | ❌ (Zod middleware) |
| Async ecosystem maturity | ✅ Good | ✅ Excellent |
| Container image size | ❌ Larger | ✅ Smaller |

---

## Project Structure

```
src/
├── main.py               ← Entry point (uvicorn)
├── app.py                ← FastAPI instance, routers, middleware
├── config.py             ← Settings via pydantic-settings
├── database.py           ← AsyncPG pool
├── dependencies.py       ← FastAPI Depends() functions
├── routers/
│   ├── auth.py           ← /api/auth/* routes
│   └── users.py          ← /api/users/* routes
├── schemas/
│   ├── auth.py           ← Pydantic models for auth
│   └── users.py          ← Pydantic models for users
└── middleware/
    └── error_handler.py  ← Exception handlers
```

---

## app.py Setup

```python
# src/app.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from .routers import auth, users
from .middleware.error_handler import register_exception_handlers
import os

limiter = Limiter(key_func=get_remote_address)

def create_app() -> FastAPI:
    app = FastAPI(
        title="API",
        docs_url="/api/docs" if os.getenv("NODE_ENV") != "production" else None,
        redoc_url=None
    )

    # Rate limiting
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=os.getenv("ALLOWED_ORIGINS", "").split(","),
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
        allow_headers=["Content-Type", "Authorization"],
    )

    # Health check
    @app.get("/health")
    async def health():
        return {"status": "ok"}

    # Routers
    app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
    app.include_router(users.router, prefix="/api/users", tags=["users"])

    # Exception handlers
    register_exception_handlers(app)

    return app

app = create_app()
```

---

## Pydantic Schema + Route Pattern

```python
# src/schemas/auth.py
from pydantic import BaseModel, EmailStr, field_validator
import re

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        return v

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
```

```python
# src/routers/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from ..schemas.auth import LoginRequest, AuthResponse
from ..dependencies import get_db, get_current_user
from ..database import pool

router = APIRouter()

@router.post("/login", response_model=AuthResponse)
async def login(body: LoginRequest):  # Pydantic validates automatically
    row = await pool.fetchrow(
        "SELECT * FROM users WHERE email = $1",
        body.email  # parameterized — asyncpg always uses positional params
    )
    if not row:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    # verify password, generate tokens...
    return AuthResponse(access_token=access_token, refresh_token=refresh_token)
```

---

## Database — asyncpg

```python
# src/database.py
import asyncpg
import os
from contextlib import asynccontextmanager

_pool = None

async def get_pool():
    global _pool
    if _pool is None:
        _pool = await asyncpg.create_pool(
            dsn=os.getenv("DATABASE_URL"),
            min_size=2,
            max_size=20,
            command_timeout=60,
            ssl="require" if os.getenv("NODE_ENV") == "production" else None
        )
    return _pool

# Dependency for FastAPI
async def get_db():
    pool = await get_pool()
    async with pool.acquire() as conn:
        yield conn
```

---

## Error Handler

```python
# src/middleware/error_handler.py
from fastapi import Request
from fastapi.responses import JSONResponse
import logging

logger = logging.getLogger(__name__)

def register_exception_handlers(app):
    @app.exception_handler(Exception)
    async def unhandled_exception(request: Request, exc: Exception):
        logger.error(f"Unhandled error: {exc}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={"error": "Internal server error"}
        )
```

---

## Dockerfile

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

EXPOSE 3000

CMD ["uvicorn", "src.app:app", "--host", "0.0.0.0", "--port", "3000", "--workers", "2"]
```

---

## Key Differences from Node.js Stack

| Concept | Node.js/Express | FastAPI/Python |
|---|---|---|
| Validation | Zod middleware | Pydantic built-in |
| Parameterized SQL | `$1, $2` (pg) | `$1, $2` (asyncpg) |
| ORM option | None (raw pg) | SQLAlchemy async (optional) |
| Secret env | `process.env.KEY` | `os.getenv("KEY")` |
| Container start | `node src/index.js` | `uvicorn src.app:app` |
