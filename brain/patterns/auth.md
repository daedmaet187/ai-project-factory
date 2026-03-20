# Pattern: Authentication

**Problem**: Secure user authentication with JWT access tokens and refresh token rotation
**Applies to**: All stacks (Node.js backend, React admin, Flutter mobile)
**Last validated**: [Not yet validated — template]

---

## Solution Overview

1. Short-lived access tokens (15 min) for API authorization
2. Long-lived refresh tokens (7 days) stored in database (revocable)
3. Refresh token rotation on every use (old token invalidated)
4. Secure storage on clients (httpOnly cookies for web, secure storage for mobile)

---

## Backend Implementation (Node.js/Express)

### Token Generation

```javascript
// src/utils/tokens.js
import jwt from 'jsonwebtoken';
import { randomBytes } from 'crypto';

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL_DAYS = 7;

export function generateAccessToken(user) {
  return jwt.sign(
    { sub: user.id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_TTL }
  );
}

export function generateRefreshToken() {
  return randomBytes(32).toString('hex');
}

export function getRefreshTokenExpiry() {
  return new Date(Date.now() + REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);
}
```

### Refresh Endpoint with Rotation

```javascript
// src/routes/auth.js
router.post('/refresh', async (req, res, next) => {
  const { refreshToken } = req.body;

  // Find and validate refresh token
  const stored = await db.query(
    'SELECT * FROM refresh_tokens WHERE token = $1 AND expires_at > NOW()',
    [refreshToken]
  );

  if (!stored.rows[0]) {
    return res.status(401).json({ error: 'Invalid refresh token' });
  }

  const userId = stored.rows[0].user_id;

  // Rotate: delete old token, create new one
  await db.query('DELETE FROM refresh_tokens WHERE token = $1', [refreshToken]);

  const newRefreshToken = generateRefreshToken();
  const expiresAt = getRefreshTokenExpiry();

  await db.query(
    'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
    [userId, newRefreshToken, expiresAt]
  );

  // Get user for new access token
  const user = await db.query('SELECT id, role FROM users WHERE id = $1', [userId]);
  const accessToken = generateAccessToken(user.rows[0]);

  res.json({ accessToken, refreshToken: newRefreshToken });
});
```

### Auth Middleware

```javascript
// src/middleware/auth.js
import jwt from 'jsonwebtoken';

export function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization header' });
  }

  const token = authHeader.slice(7);

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { id: payload.sub, role: payload.role };
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

export function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}
```

---

## Flutter Implementation

### Secure Token Storage

```dart
// lib/core/auth/token_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  static Future<String?> getAccessToken() => _storage.read(key: _accessKey);
  static Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
```

### Auto-Refresh Interceptor

```dart
// lib/core/api/auth_interceptor.dart
import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;

      try {
        final refreshToken = await TokenStorage.getRefreshToken();
        if (refreshToken == null) {
          return handler.reject(err);
        }

        final response = await _dio.post('/api/auth/refresh', data: {
          'refreshToken': refreshToken,
        });

        await TokenStorage.saveTokens(
          accessToken: response.data['accessToken'],
          refreshToken: response.data['refreshToken'],
        );

        // Retry original request
        final retryResponse = await _dio.fetch(err.requestOptions);
        return handler.resolve(retryResponse);
      } catch (e) {
        await TokenStorage.clearTokens();
        return handler.reject(err);
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}
```

---

## React/Admin Implementation

### Auth Context

```typescript
// src/contexts/AuthContext.tsx
import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { api } from '@/lib/api';

interface User {
  id: string;
  email: string;
  role: string;
}

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check for existing session on mount
    api.get('/api/auth/me')
      .then(res => setUser(res.data.user))
      .catch(() => setUser(null))
      .finally(() => setIsLoading(false));
  }, []);

  const login = async (email: string, password: string) => {
    const res = await api.post('/api/auth/login', { email, password });
    setUser(res.data.user);
  };

  const logout = async () => {
    await api.post('/api/auth/logout');
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
};
```

---

## Database Schema

```sql
-- migrations/001_auth.sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT UNIQUE NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_token ON refresh_tokens(token);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
```

---

## Gotchas

1. **Never store JWT secret in code** — always from Secrets Manager via environment variable
2. **Same error message for wrong email AND wrong password** — prevents user enumeration
3. **Rate limit login endpoint aggressively** — 10 attempts per 15 minutes max
4. **Refresh token rotation is critical** — without it, stolen refresh tokens are valid for 7 days
5. **Clear tokens on logout server-side** — client-side clear is not enough

---

## See Also

- `skills/general/jwt-auth.md` — JWT implementation details
- `skills/general/secrets-management.md` — How to handle JWT_SECRET
- `security/CHECKLIST.md` — Authentication security checklist
