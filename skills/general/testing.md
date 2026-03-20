# Testing Patterns

Patterns for writing tests across all layers.

---

## Backend Testing (Vitest)

### Setup

```json
// package.json
{
  "devDependencies": {
    "vitest": "^2.0.0",
    "supertest": "^7.0.0",
    "@vitest/coverage-v8": "^2.0.0"
  },
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage"
  }
}
```

### Test Database

```javascript
// tests/setup.js
import { beforeAll, afterAll, beforeEach } from 'vitest';
import { pool } from '../src/db.js';

beforeAll(async () => {
  // Run migrations on test database
  await pool.query(`CREATE TABLE IF NOT EXISTS users (...)`);
});

beforeEach(async () => {
  // Clean tables before each test
  await pool.query('TRUNCATE users, refresh_tokens CASCADE');
});

afterAll(async () => {
  await pool.end();
});
```

### API Testing Pattern

```javascript
import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../src/app.js';

describe('GET /api/users', () => {
  it('requires authentication', async () => {
    const res = await request(app).get('/api/users');
    expect(res.status).toBe(401);
  });

  it('returns users for authenticated request', async () => {
    const token = await getTestToken(); // helper function
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${token}`);
    
    expect(res.status).toBe(200);
    expect(res.body).toBeInstanceOf(Array);
  });
});
```

---

## Flutter Testing

### Widget Tests

```dart
testWidgets('LoginButton shows loading state', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => MockAuthNotifier(isLoading: true)),
      ],
      child: MaterialApp(home: LoginScreen()),
    ),
  );

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

### Provider Tests

```dart
test('AuthNotifier login updates state', () async {
  final container = ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWithValue(MockApiService()),
    ],
  );

  final notifier = container.read(authProvider.notifier);
  await notifier.login('test@example.com', 'password');

  expect(container.read(authProvider).user, isNotNull);
});
```

---

## React Testing

### Component Tests

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const wrapper = ({ children }) => (
  <QueryClientProvider client={new QueryClient()}>
    {children}
  </QueryClientProvider>
);

test('UserList shows loading state', async () => {
  render(<UserList />, { wrapper });
  expect(screen.getByRole('progressbar')).toBeInTheDocument();
});
```

---

## Coverage Thresholds

```javascript
// vitest.config.js
export default {
  test: {
    coverage: {
      provider: 'v8',
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 70,
        statements: 80,
      },
    },
  },
};
```
