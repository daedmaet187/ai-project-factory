# Mobile Stack: Flutter + Riverpod 2 + go_router 14

Default mobile stack. Single codebase for iOS and Android.

---

## Project Structure

```
lib/
├── main.dart                   ← Entry point, ProviderScope, app bootstrap
├── app.dart                    ← MaterialApp.router, GoRouter config
├── core/
│   ├── config/
│   │   └── env.dart            ← API base URL, app config
│   ├── network/
│   │   └── api_client.dart     ← Dio client with interceptors
│   ├── error/
│   │   └── app_exception.dart  ← Custom exception types
│   └── theme/
│       ├── app_theme.dart      ← ThemeData from design tokens
│       └── app_colors.dart     ← Color constants
├── features/
│   └── [feature]/
│       ├── data/
│       │   ├── api/            ← API calls for this feature
│       │   └── models/         ← JSON serializable models
│       ├── providers/          ← Riverpod providers
│       └── ui/
│           ├── screens/        ← Full screen widgets
│           └── widgets/        ← Reusable UI components
└── shared/
    ├── providers/
    │   └── auth_provider.dart  ← Auth state — AsyncNotifierProvider
    └── widgets/                ← App-wide reusable widgets
```

---

## pubspec.yaml Key Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  go_router: ^14.0.0
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  json_annotation: ^4.9.0
  freezed_annotation: ^2.4.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.0
  flutter_lints: ^4.0.0
```

---

## main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No runApp before async init complete
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
```

---

## API Client with Interceptors

```dart
// lib/core/network/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient(String baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Attempt refresh...
            // If refresh fails, clear tokens and signal auth provider
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) =>
    _dio.get(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
    _dio.post(path, data: data);
}
```

---

## Auth Provider Pattern

```dart
// lib/shared/providers/auth_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

part 'auth_provider.g.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  const AuthState({required this.status, this.user});
}

@riverpod
class Auth extends _$Auth {
  final _storage = const FlutterSecureStorage();

  @override
  Future<AuthState> build() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    try {
      final user = await ref.read(apiClientProvider).get<Map>('/api/auth/me');
      return AuthState(status: AuthStatus.authenticated, user: User.fromJson(user.data!));
    } catch (_) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await ref.read(apiClientProvider).post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      await _storage.write(key: 'access_token', value: response.data['accessToken']);
      await _storage.write(key: 'refresh_token', value: response.data['refreshToken']);
      final user = User.fromJson(response.data['user']);
      return AuthState(status: AuthStatus.authenticated, user: user);
    });
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AsyncValue.data(AuthState(status: AuthStatus.unauthenticated));
  }
}
```

---

## go_router Setup with Auth Guard

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'shared/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull?.status == AuthStatus.authenticated;
      final isLoading = authState.isLoading;
      final isAuthRoute = state.matchedLocation.startsWith('/login');

      if (isLoading) return '/loading';
      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/dashboard';
      return null;
    },
    refreshListenable: GoRouterRefreshStream(ref.watch(authProvider.stream)),
    routes: [
      GoRoute(path: '/loading', builder: (_, __) => const LoadingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
              routes: [
                GoRoute(path: 'edit', builder: (_, __) => const EditProfileScreen()),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
    );
  }
}
```

---

## Token Storage Rule

**Always use `flutter_secure_storage`** for tokens. Never `SharedPreferences`.

```dart
// ❌ WRONG — tokens in SharedPreferences (not encrypted)
final prefs = await SharedPreferences.getInstance();
prefs.setString('token', accessToken);

// ✅ CORRECT — tokens in secure storage (Keychain/Keystore)
const storage = FlutterSecureStorage();
await storage.write(key: 'access_token', value: accessToken);
```

---

## Anti-Patterns

```dart
// ❌ WRONG — Navigator.push inside go_router app
Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));

// ✅ CORRECT — go_router named routes
context.go('/profile');
context.push('/profile/edit');  // pushes onto stack

// ❌ WRONG — ref.watch in callbacks
onPressed: () {
  final user = ref.watch(userProvider);  // Watch is for build() only
}

// ✅ CORRECT — ref.read in callbacks
onPressed: () {
  final user = ref.read(userProvider);
}

// ❌ WRONG — hardcoded API URL
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

// ✅ CORRECT — from env config
final dio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));
```
