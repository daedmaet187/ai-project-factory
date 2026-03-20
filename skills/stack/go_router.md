# go_router 14.x — Navigation Patterns

Read this before writing any Flutter navigation code.

---

## Core Concepts

go_router provides declarative, URL-based navigation for Flutter. Key concepts:

- **GoRoute**: A route that matches a path
- **StatefulShellRoute**: Multiple branches with preserved state (bottom nav)
- **GoRouter redirect**: Auth guard — redirect before any route renders
- **refreshListenable**: Triggers re-evaluation of redirect when auth state changes

---

## Full Router Setup with Auth Guard

```dart
// lib/app/router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

// Error screen
class ErrorScreen extends StatelessWidget {
  final Exception? error;
  const ErrorScreen({super.key, this.error});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text('Error: ${error?.toString() ?? "Not found"}')),
  );
}

@riverpod
GoRouter router(RouterRef ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    debugLogDiagnostics: false,  // Set true during development
    errorBuilder: (context, state) => ErrorScreen(error: state.error),

    // Re-run redirect when auth state changes
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authProvider.stream)
    ),

    redirect: (context, state) {
      final authValue = authState.valueOrNull;
      final isLoading = authState.isLoading;
      final isAuthenticated = authValue?.status == AuthStatus.authenticated;
      final isOnAuthRoute = state.matchedLocation.startsWith('/auth');

      // Show loading screen while auth state is resolving
      if (isLoading) return '/loading';

      // Not authenticated → go to login
      if (!isAuthenticated && !isOnAuthRoute) {
        return '/auth/login?redirect=${Uri.encodeComponent(state.matchedLocation)}';
      }

      // Already authenticated → don't show login again
      if (isAuthenticated && isOnAuthRoute) return '/dashboard';

      return null;  // No redirect needed
    },

    routes: [
      // Loading splash
      GoRoute(
        path: '/loading',
        builder: (_, __) => const SplashScreen(),
      ),

      // Auth routes (unauthenticated)
      GoRoute(
        path: '/auth/login',
        builder: (_, state) => LoginScreen(
          redirect: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // Authenticated routes — bottom nav with state preservation
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainScaffold(navigationShell: shell),
        branches: [
          // Branch 0: Home/Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),

          // Branch 1: Feature list + detail (nested)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/habits',
                builder: (_, __) => const HabitsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',  // /habits/:id
                    builder: (_, state) => HabitDetailScreen(
                      id: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',  // /habits/:id/edit
                        builder: (_, state) => EditHabitScreen(
                          id: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
```

---

## Main Scaffold with Bottom Navigation

```dart
// lib/app/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,  // Renders current branch
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.track_changes), label: 'Habits'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
```

---

## Navigation Commands

```dart
// Push (add to stack — can go back)
context.push('/habits/${habit.id}');

// Go (replace current location — can't go back to previous)
context.go('/dashboard');

// Go with extra data (not serialized to URL)
context.go('/habits', extra: {'filter': 'active'});

// Named route navigation (more refactor-safe)
context.pushNamed('habit-detail', pathParameters: {'id': habitId});

// Pop back
context.pop();

// Pop with result
context.pop(result);  // Returns result to previous route's push() call
```

---

## GoRouterRefreshStream Helper

```dart
// lib/app/go_router_refresh_stream.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

// Converts any Stream into a Listenable for go_router
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

---

## Deep Linking Setup

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="https" android:host="app.example.com"/>
</intent-filter>
```

### iOS (ios/Runner/Runner.entitlements)
```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:app.example.com</string>
</array>
```

### GoRouter deep link config
```dart
GoRouter(
  // Handle deep links
  initialLocation: '/',
  // GoRouter automatically handles deep links when path matches a route
)
```

---

## Common Mistakes

### 1. Navigator.push inside go_router app
```dart
// ❌ WRONG — breaks go_router state
Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));

// ✅ CORRECT
context.push('/profile');
```

### 2. Missing pathParameters
```dart
// ❌ WRONG — will throw null safety error
state.pathParameters['id']

// ✅ CORRECT — use ! if you know it's there (route definition guarantees it)
state.pathParameters['id']!

// ✅ SAFER — nullable with fallback
state.pathParameters['id'] ?? ''
```

### 3. Using GoRoute inside StatefulShellBranch incorrectly
```dart
// ❌ WRONG — sub-routes as siblings, not children
StatefulShellBranch(routes: [
  GoRoute(path: '/habits', ...),
  GoRoute(path: '/habits/:id', ...),  // This won't work as expected
])

// ✅ CORRECT — sub-routes as children (routes parameter)
StatefulShellBranch(routes: [
  GoRoute(
    path: '/habits',
    routes: [
      GoRoute(path: ':id', ...),  // Nested routes
    ],
  ),
])
```

### 4. Context not available (navigation in provider)
```dart
// ❌ WRONG — can't use context in a provider
ref.listen(authProvider, (prev, next) {
  if (next.isUnauthenticated) context.go('/auth/login');  // context not available
});

// ✅ CORRECT — let go_router redirect handle auth
// The redirect function in router.dart handles auth state changes
// No need for manual navigation from providers
```
