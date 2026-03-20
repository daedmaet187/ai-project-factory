# Tier 1: MVP Observability Setup (Zero Extra Cost)

This guide walks through setting up full observability for a new project using only free/included services. Total setup time: 2–3 hours.

**Stack**: CloudWatch Logs + CloudWatch Alarms + Sentry (free) + Firebase Crashlytics + CloudTrail

---

## Prerequisites

- ECS Fargate task is deployed and running
- AWS CLI configured (`aws sts get-caller-identity` works)
- Firebase project exists (or you'll create one below)
- Sentry account created at sentry.io (free, no credit card)

---

## Step 1: Verify CloudWatch Logs Are Flowing

Your ECS task definition should already have the CloudWatch log driver configured (it's included in the factory's ECS module). Verify it's working:

```bash
# Find your log group
aws logs describe-log-groups --log-group-name-prefix "/ecs/" --query 'logGroups[*].logGroupName'

# Tail recent logs (replace with your actual log group)
aws logs tail /ecs/your-project-api --follow --since 10m
```

If no logs appear:
1. Check the ECS task definition has `logConfiguration` set:
```json
"logConfiguration": {
  "logDriver": "awslogs",
  "options": {
    "awslogs-group": "/ecs/your-project-api",
    "awslogs-region": "us-east-1",
    "awslogs-stream-prefix": "ecs"
  }
}
```
2. Verify ECS task role has `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` permissions.

**Set log retention** (CloudWatch charges for storage after free tier):
```bash
aws logs put-retention-policy \
  --log-group-name /ecs/your-project-api \
  --retention-in-days 30
```

---

## Step 2: Add Structured Logging with pino

Install pino in your backend:
```bash
npm install pino
```

Create `backend/src/config/logger.js`:
```javascript
import pino from 'pino'

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: { service: process.env.SERVICE_NAME || 'api' },
  timestamp: pino.stdTimeFunctions.isoTime,
})
```

Replace all `console.log` calls with structured logger calls:
```javascript
// Before (bad — unstructured, hard to query in CloudWatch Insights)
console.log('User created:', userId)

// After (good — JSON, queryable, includes context)
logger.info({ userId }, 'user.created')
logger.error({ err, userId }, 'user.create.failed')
```

**Query your logs** in CloudWatch Logs Insights:
```
fields @timestamp, @message
| filter service = "api"
| filter level = "error"
| sort @timestamp desc
| limit 50
```

---

## Step 3: Create CloudWatch Alarms

Create the three essential alarms. Replace `YOUR_PROJECT`, `YOUR_ALB_ARN_SUFFIX`, and `YOUR_TG_ARN_SUFFIX` with your actual values.

### Alarm 1: API 5xx error rate
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "YOUR_PROJECT-api-5xx-rate" \
  --alarm-description "API 5xx error rate exceeding threshold" \
  --metric-name HTTPCode_Target_5XX_Count \
  --namespace AWS/ApplicationELB \
  --dimensions Name=LoadBalancer,Value=YOUR_ALB_ARN_SUFFIX \
               Name=TargetGroup,Value=YOUR_TG_ARN_SUFFIX \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions YOUR_SNS_TOPIC_ARN \
  --treat-missing-data notBreaching
```

### Alarm 2: ECS CPU high
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "YOUR_PROJECT-ecs-cpu-high" \
  --alarm-description "ECS CPU utilization above 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --dimensions Name=ClusterName,Value=YOUR_PROJECT-cluster \
               Name=ServiceName,Value=YOUR_PROJECT-api \
  --statistic Average \
  --period 60 \
  --evaluation-periods 3 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions YOUR_SNS_TOPIC_ARN
```

### Alarm 3: RDS storage
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "YOUR_PROJECT-rds-storage-low" \
  --alarm-description "RDS free storage below 20%" \
  --metric-name FreeStorageSpace \
  --namespace AWS/RDS \
  --dimensions Name=DBInstanceIdentifier,Value=YOUR_PROJECT-db \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 5368709120 \
  --comparison-operator LessThanThreshold \
  --alarm-actions YOUR_SNS_TOPIC_ARN
```

### Create SNS topic and email subscription first
```bash
# Create topic
SNS_ARN=$(aws sns create-topic --name YOUR_PROJECT-alerts --query TopicArn --output text)
echo "SNS ARN: $SNS_ARN"

# Subscribe email
aws sns subscribe \
  --topic-arn $SNS_ARN \
  --protocol email \
  --notification-endpoint your-alert-email@example.com
```

Check your email and click the confirmation link. Alarms won't fire until subscription is confirmed.

---

## Step 4: Set Up Sentry (Node.js)

**4a. Create a Sentry project**
1. Go to sentry.io → New Project → Node.js
2. Note the DSN (looks like `https://abc123@o123.ingest.sentry.io/456`)

**4b. Install Sentry SDK**
```bash
npm install @sentry/node @sentry/profiling-node
```

**4c. Create `backend/src/config/sentry.js`**
```javascript
import * as Sentry from '@sentry/node'
import { nodeProfilingIntegration } from '@sentry/profiling-node'

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV || 'production',
  integrations: [nodeProfilingIntegration()],
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  profilesSampleRate: 0.1,
})

export { Sentry }
```

**4d. Wire into Express (`backend/src/index.js`)**
```javascript
// At the very top — before any other imports
import './config/sentry.js'

// ... your app setup, routes, etc. ...

// After ALL routes — Sentry must be the last middleware
app.use(Sentry.expressErrorHandler())
```

**4e. Add SENTRY_DSN to AWS Secrets Manager**
```bash
aws secretsmanager create-secret \
  --name YOUR_PROJECT/production/sentry-dsn \
  --secret-string "https://your-dsn@sentry.io/..."
```

Then reference it in your ECS task definition's `secrets` array (not `environment`).

**4f. Test it's working**
```javascript
// Temporary test route — remove after verifying
app.get('/debug-sentry', function mainHandler(req, res) {
  throw new Error('My first Sentry error!')
})
```

Hit the endpoint, then check Sentry dashboard — error should appear within seconds.

---

## Step 5: Set Up Firebase Crashlytics (Flutter)

**5a. Create Firebase project**
1. Go to console.firebase.google.com → Add project
2. Name it the same as your app project
3. Disable Google Analytics for now (can enable later)

**5b. Add your apps to Firebase**
- Click "Add app" → iOS → enter your bundle ID (e.g., `com.yourcompany.appname`)
- Click "Add app" → Android → enter your package name

**5c. Download config files**
- iOS: download `GoogleService-Info.plist` → place in `mobile/ios/Runner/`
- Android: download `google-services.json` → place in `mobile/android/app/`

**5d. Add dependencies to `mobile/pubspec.yaml`**
```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_crashlytics: ^4.1.3
  firebase_performance: ^0.10.0+8
```

**5e. Configure Android (`mobile/android/app/build.gradle`)**
```gradle
apply plugin: 'com.google.gms.google-services'
apply plugin: 'com.google.firebase.crashlytics'
```

And in `mobile/android/build.gradle`:
```gradle
dependencies {
  classpath 'com.google.gms:google-services:4.4.0'
  classpath 'com.google.firebase:firebase-crashlytics-gradle:3.0.1'
}
```

**5f. Update `mobile/lib/main.dart`**
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart'; // generated by FlutterFire CLI

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ProviderScope(child: MyApp()));
}
```

**5g. Generate firebase_options.dart using FlutterFire CLI**
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=your-firebase-project-id
```

This generates `mobile/lib/firebase_options.dart` — commit this file (it's not secret).

**5h. Test Crashlytics**
```dart
// Temporary test button — remove after verifying
ElevatedButton(
  onPressed: () => FirebaseCrashlytics.instance.crash(),
  child: const Text('Test Crash'),
)
```

Build and run the app, press the button. Check Firebase Console → Crashlytics — crash should appear within a few minutes.

---

## Step 6: Enable CloudTrail

```bash
# Create S3 bucket for CloudTrail logs
aws s3api create-bucket \
  --bucket YOUR_PROJECT-cloudtrail-logs \
  --region us-east-1

# Add bucket policy (required for CloudTrail)
aws s3api put-bucket-policy \
  --bucket YOUR_PROJECT-cloudtrail-logs \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AWSCloudTrailAclCheck",
        "Effect": "Allow",
        "Principal": {"Service": "cloudtrail.amazonaws.com"},
        "Action": "s3:GetBucketAcl",
        "Resource": "arn:aws:s3:::YOUR_PROJECT-cloudtrail-logs"
      },
      {
        "Sid": "AWSCloudTrailWrite",
        "Effect": "Allow",
        "Principal": {"Service": "cloudtrail.amazonaws.com"},
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::YOUR_PROJECT-cloudtrail-logs/AWSLogs/*",
        "Condition": {"StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}}
      }
    ]
  }'

# Create the trail
aws cloudtrail create-trail \
  --name YOUR_PROJECT-trail \
  --s3-bucket-name YOUR_PROJECT-cloudtrail-logs \
  --include-global-service-events \
  --no-is-multi-region-trail

# Start logging
aws cloudtrail start-logging --name YOUR_PROJECT-trail
```

---

## Verification Checklist

After completing all steps, verify each piece is working:

```bash
# 1. CloudWatch Logs flowing
aws logs tail /ecs/YOUR_PROJECT-api --since 5m
# Expected: JSON log lines from your API

# 2. CloudWatch Alarms created
aws cloudwatch describe-alarms --alarm-names "YOUR_PROJECT-api-5xx-rate" "YOUR_PROJECT-ecs-cpu-high"
# Expected: Both alarms in OK state

# 3. SNS subscription confirmed
aws sns list-subscriptions-by-topic --topic-arn YOUR_SNS_ARN
# Expected: subscription with SubscriptionArn (not PendingConfirmation)

# 4. CloudTrail logging
aws cloudtrail get-trail-status --name YOUR_PROJECT-trail
# Expected: IsLogging: true

# 5. Sentry: hit your test endpoint and check sentry.io dashboard

# 6. Firebase: run test crash, check Firebase Console → Crashlytics
```

---

## What You Now Have

| What | Where to check |
|---|---|
| API logs (JSON, searchable) | CloudWatch → Log groups → /ecs/YOUR_PROJECT-api |
| CPU/memory metrics | CloudWatch → Metrics → ECS |
| Error alerts | Email from YOUR_SNS |
| Backend exceptions + stack traces | sentry.io → Your project |
| Mobile crash reports | Firebase Console → Crashlytics |
| AWS API audit trail | S3 → YOUR_PROJECT-cloudtrail-logs |

Total monthly cost added: ~$5–6/month.

---

## Next Step: Tier 2

When you have paying customers and need dashboards + distributed tracing, see [TIER2-GROWTH.md](TIER2-GROWTH.md).
