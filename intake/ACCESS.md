# Access Configuration

Fill this file with your credentials before starting generation. The AI will validate each service before proceeding. Do not start the intake conversation until this file is filled.

**Security note**: This file contains secrets. Do not commit it to version control. Add it to `.gitignore` in your project.

---

## Required Services

These must all pass validation before generation can begin.

### GitHub
```
GITHUB_TOKEN:    (Personal Access Token — scopes required: repo, workflow, read:org)
GITHUB_USERNAME: 
GITHUB_ORG:      (optional — for org repos instead of personal repos)
```

**How to create a GitHub token**:
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Scopes: `repo` (full), `workflow`, `read:org`
3. Paste token above

**Validation commands the AI will run**:
```bash
gh auth login --with-token <<< "$GITHUB_TOKEN"
gh auth status
gh repo list --limit 1
```

---

### AWS
```
AWS_ACCESS_KEY_ID:     
AWS_SECRET_ACCESS_KEY: 
AWS_REGION:            (default: us-east-1)
```

**Required IAM permissions**:
- `iam:*` (for ECS task role creation)
- `ecs:*`
- `ecr:*`
- `rds:*`
- `s3:*`
- `cloudfront:*`
- `acm:*`
- `secretsmanager:*`
- `ec2:*` (VPC, subnets, security groups)
- `elasticloadbalancing:*`
- `logs:*`

**Validation commands the AI will run**:
```bash
aws sts get-caller-identity
aws ecr describe-repositories --max-items 1
aws ecs list-clusters --max-items 1
aws rds describe-db-instances --max-records 20
aws secretsmanager list-secrets --max-results 1
```

---

### Cloudflare
```
CF_API_TOKEN:   (Zone:Edit, DNS:Edit, Cloudflare Pages:Edit permissions)
CF_ZONE_ID:     (found at: Cloudflare dashboard → your domain → Overview → right side)
CF_ACCOUNT_ID:  (found at: Cloudflare dashboard → right side of any page)
```

**How to create a Cloudflare API token**:
1. Cloudflare → My Profile → API Tokens → Create Token
2. Permissions needed: Zone:Edit, DNS:Edit, Cloudflare Pages:Edit
3. Zone Resources: Include → Specific zone → your domain

**Validation commands the AI will run**:
```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" | jq '.success, .result.name'
```

---

### Domain
```
DOMAIN_NAME:      (e.g., example.com — must already be in Cloudflare DNS)
API_SUBDOMAIN:    (e.g., api — will become api.example.com)
ADMIN_SUBDOMAIN:  (e.g., admin — will become admin.example.com)
APP_SUBDOMAIN:    (e.g., app — mobile app backend, will become app.example.com)
```

**Requirement**: The domain must already have its nameservers pointed to Cloudflare. If not, do that first and wait for propagation (up to 24h, usually <1h).

---

## Optional Services

Fill these in if applicable to your project.

### Figma (for UI design ingestion)
```
FIGMA_TOKEN:    (Personal access token — Figma settings → Account → Personal access tokens)
FIGMA_FILE_KEY: (from Figma URL: figma.com/file/FILE_KEY/... — just the key part)
FIGMA_NODE_ID:  (optional — specific frame or page; leave blank to use all frames)
```

Without Figma, the AI will generate a design system from your style description in QUESTIONS.md.

**Validation commands the AI will run**:
```bash
curl -s -X GET "https://api.figma.com/v1/files/${FIGMA_FILE_KEY}" \
  -H "X-Figma-Token: ${FIGMA_TOKEN}" | jq '.name'
```

---

### Apple (for iOS App Store distribution)
```
APPLE_TEAM_ID:        (10-character string from Apple Developer account)
APPLE_BUNDLE_ID:      (e.g., com.yourcompany.appname)
APPLE_CERT_BASE64:    (base64-encoded .p12 distribution certificate)
APPLE_CERT_PASSWORD:  (certificate password)
APPLE_PROVISIONING:   (base64-encoded .mobileprovision profile)
```

Not needed for local development or TestFlight internal testing. Required for App Store submission.

---

### Google Play (for Android distribution)
```
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: (path to service account JSON file)
ANDROID_KEYSTORE_BASE64:          (base64-encoded keystore file)
ANDROID_KEYSTORE_PASSWORD:        
ANDROID_KEY_ALIAS:                
ANDROID_KEY_PASSWORD:             
```

Not needed for local development. Required for Play Store submission.

---

### Push Notifications (if real-time/notifications selected)
```
FCM_SERVER_KEY:      (Firebase Cloud Messaging — for Android)
APNS_KEY_ID:         (Apple Push Notification Service)
APNS_TEAM_ID:        (same as APPLE_TEAM_ID)
APNS_AUTH_KEY_P8:    (base64-encoded .p8 key from Apple Developer)
```

---

## Validation Results

*(The AI fills this section after running validation checks)*

| Service | Status | Notes |
|---|---|---|
| GitHub | ⏳ Pending | |
| AWS | ⏳ Pending | |
| Cloudflare | ⏳ Pending | |
| Domain | ⏳ Pending | |
| Figma | ⏳ Pending | |
| Apple | ⏳ Pending | |
| Google Play | ⏳ Pending | |

---

## Monitoring Services

### Sentry (recommended for all tiers)
```
SENTRY_DSN: (from sentry.io → Your Project → Settings → Client Keys → DSN)
SENTRY_ORG: (your Sentry organization slug — visible in the URL: sentry.io/organizations/YOUR_ORG/)
```

**How to create a Sentry project**:
1. sentry.io → New Project → Node.js
2. Copy the DSN from the setup page
3. Add `SENTRY_DSN` to AWS Secrets Manager (not as plaintext ECS env var)

**Validation**:
```bash
# DSN format check — should look like:
# https://abc123@o456789.ingest.sentry.io/123456
echo $SENTRY_DSN | grep -E "^https://[a-f0-9]+@o[0-9]+\.ingest\.sentry\.io/[0-9]+"
```

---

### Grafana Cloud (Tier 2+ only)
```
GRAFANA_INSTANCE_ID:    (numeric ID — Grafana Cloud → My Account → Stack details)
GRAFANA_CLOUD_API_KEY:  (Grafana Cloud → My Account → API Keys → Create, role: MetricsPublisher)
GRAFANA_LOKI_URL:       (Grafana Cloud → Connections → Data sources → Loki → Connection URL)
GRAFANA_TEMPO_URL:      (Grafana Cloud → Connections → Data sources → Tempo → Connection URL)
GRAFANA_PROMETHEUS_URL: (Grafana Cloud → Connections → Data sources → Prometheus → Connection URL)
```

**Validation**:
```bash
# Check Prometheus remote write endpoint
curl -s -u "${GRAFANA_INSTANCE_ID}:${GRAFANA_CLOUD_API_KEY}" \
  "${GRAFANA_PROMETHEUS_URL}/api/v1/labels" | jq '.status'
# Expected: "success"
```

---

### Firebase (for mobile crash reporting)
```
FIREBASE_PROJECT_ID: (from Firebase Console → Project settings → General → Project ID)
```

**Note**: `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are downloaded from Firebase Console and added directly to `mobile/android/app/` and `mobile/ios/Runner/`. These files are not secret but should not be committed publicly for production apps (add to `.gitignore` or use Firebase App Distribution for CI).

**Validation**:
```bash
# After FlutterFire configure runs:
ls mobile/lib/firebase_options.dart  # should exist
ls mobile/android/app/google-services.json  # should exist
ls mobile/ios/Runner/GoogleService-Info.plist  # should exist
```

---

## Notes

- Secrets in this file are used **only** to bootstrap your project. They are stored in AWS Secrets Manager during Phase 4 and accessed by your app exclusively from there.
- After generation, rotate your personal access tokens (GitHub, Cloudflare) and use the service-specific credentials that were created for the project.
- AWS credentials used here should be for a **human operator IAM user** with broad permissions. The running app will use a **service IAM role** with minimal permissions.
