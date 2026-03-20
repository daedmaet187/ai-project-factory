# Mobile Observability — Flutter

Complete observability wiring for Flutter apps. Generate these patterns into every mobile scaffold.

---

## Package Setup — Add to `pubspec.yaml`

```yaml
dependencies:
  # Tier 1 — always include
  firebase_core: ^3.6.0
  firebase_crashlytics: ^4.1.3
  firebase_performance: ^0.10.0+8

  # Tier 2+ — add when Sentry is configured (same account as backend)
  sentry_flutter: ^8.8.0
```

---

## `lib/main.dart` — Full Observability Wiring

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Crashlytics + Performance)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Disable Crashlytics in debug mode — only collect crashes in production
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  // Catch Flutter framework errors
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Catch async errors outside Flutter framework (isolate errors, etc.)
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ProviderScope(child: MyApp()));
}
```

---

## Sentry Integration (Tier 2+ — wrap instead of `runApp`)

When `SENTRY_DSN` is provided at build time, wrap the app with Sentry. Replaces the plain `runApp` call above:

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Sentry wraps runApp — use dart-define to inject DSN at build time
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = const String.fromEnvironment('ENV', defaultValue: 'production');
        options.release = const String.fromEnvironment('APP_VERSION');
        options.tracesSampleRate = kDebugMode ? 1.0 : 0.1;
        options.attachScreenshot = true;     // captures screenshot on error
        options.attachViewHierarchy = true;  // captures widget tree on error
      },
      appRunner: () => runApp(const ProviderScope(child: MyApp())),
    );
  } else {
    runApp(const ProviderScope(child: MyApp()));
  }
}
```

Build with DSN injected:
```bash
flutter build apk --release \
  --dart-define=SENTRY_DSN=your-dsn \
  --dart-define=APP_VERSION=1.0.0 \
  --dart-define=ENV=production
```

---

## User Context — Set After Login, Clear on Logout

```dart
// In auth_provider.dart — after successful login:
Future<void> _onLoginSuccess(User user) async {
  // Set user context for crash reports (ID only — no email for privacy)
  await FirebaseCrashlytics.instance.setUserIdentifier(user.id);
  await Sentry.configureScope((scope) {
    scope.setUser(SentryUser(id: user.id));  // no email — privacy
  });
}

// After logout:
Future<void> _onLogout() async {
  await FirebaseCrashlytics.instance.setUserIdentifier('');
  await Sentry.configureScope((scope) => scope.setUser(null));
}
```

---

## Performance Monitoring — HTTP API Calls via Dio

Wrap all Dio HTTP calls with Firebase Performance traces. Add to `lib/services/api_service.dart`:

```dart
import 'package:firebase_performance/firebase_performance.dart';
import 'package:dio/dio.dart';

void _addPerformanceInterceptor(Dio dio) {
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      // Start a Firebase Performance HTTP metric trace
      final trace = FirebasePerformance.instance.newHttpMetric(
        options.uri.toString(),
        HttpMethod.values.firstWhere(
          (m) => m.name.toUpperCase() == options.method,
          orElse: () => HttpMethod.Get,
        ),
      );
      await trace.start();
      options.extra['_perf_trace'] = trace;
      handler.next(options);
    },
    onResponse: (response, handler) async {
      final trace = response.requestOptions.extra['_perf_trace'] as HttpMetric?;
      if (trace != null) {
        trace.httpResponseCode = response.statusCode;
        trace.responseContentType = response.headers.value('content-type');
        await trace.stop();
      }
      handler.next(response);
    },
    onError: (error, handler) async {
      final trace = error.requestOptions.extra['_perf_trace'] as HttpMetric?;
      if (trace != null) {
        trace.httpResponseCode = error.response?.statusCode;
        await trace.stop();
      }
      handler.next(error);
    },
  ));
}
```

Call `_addPerformanceInterceptor(_dio)` in your `ApiService` constructor after creating the Dio instance.

**Effect**: Every API call appears in Firebase Performance → Network Requests with latency, success rate, and payload size — broken down by endpoint.

---

## CI/CD — Build with Sentry Release

Add to `.github/workflows/mobile.yml`:

```yaml
- name: Build APK with observability
  run: |
    flutter build apk --release \
      --dart-define=API_URL=${{ vars.API_URL }} \
      --dart-define=SENTRY_DSN=${{ secrets.SENTRY_MOBILE_DSN }} \
      --dart-define=APP_VERSION=${{ github.sha }} \
      --dart-define=ENV=production

- name: Create Sentry mobile release
  if: env.SENTRY_AUTH_TOKEN != ''
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
    SENTRY_ORG: ${{ secrets.SENTRY_ORG }}
    SENTRY_PROJECT: ${{ secrets.SENTRY_MOBILE_PROJECT }}
  run: |
    npm install -g @sentry/cli
    sentry-cli releases new ${{ github.sha }}
    sentry-cli releases finalize ${{ github.sha }}
    sentry-cli releases deploys ${{ github.sha }} new -e production
```

---

## Summary — What to Generate

| File | What to add |
|---|---|
| `pubspec.yaml` | `firebase_core`, `firebase_crashlytics`, `firebase_performance`, optionally `sentry_flutter` |
| `lib/main.dart` | Firebase init, Crashlytics error handlers, optional Sentry wrapper |
| `lib/services/api_service.dart` | `_addPerformanceInterceptor` call on Dio instance |
| `lib/features/auth/auth_provider.dart` | User identifier set/clear on login/logout |
| `.github/workflows/mobile.yml` | `--dart-define` build args + Sentry release step |
