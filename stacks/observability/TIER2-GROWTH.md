# Tier 2: Growth Observability Setup (Grafana Cloud)

Upgrade from CloudWatch-only to full dashboards, distributed tracing, and unified alerting. Total setup time: 3–4 hours.

**Stack**: Grafana Cloud (LGTM) + OpenTelemetry + Sentry Team + continued Firebase Crashlytics

**Cost**: ~$30–80/month (Grafana free tier is generous — many teams never need to upgrade)

---

## Prerequisites

- Tier 1 setup completed (CloudWatch Logs flowing, Sentry wired in)
- Grafana Cloud account (free at grafana.com/products/cloud)
- Node.js backend is running on ECS Fargate

---

## Step 1: Create Grafana Cloud Account

1. Go to grafana.com/products/cloud → Start for free
2. Choose a stack name (e.g., `yourproject`) — this becomes your Grafana URL: `yourproject.grafana.net`
3. Select the region closest to your users

**Free tier limits** (generous):
- 50 GB logs/month (Loki)
- 10,000 active metrics series (Mimir/Prometheus)
- 50 GB traces/month (Tempo)
- 14-day retention

---

## Step 2: Get Your LGTM Endpoints

In Grafana Cloud → Home → My Account → Your Stack → Details:

Collect these values — you'll need them in the steps below:

```
GRAFANA_INSTANCE_ID:     (numeric, e.g., 123456)
GRAFANA_LOKI_URL:        https://logs-prod-us-central1.grafana.net
GRAFANA_TEMPO_URL:       https://tempo-us-central1.grafana.net
GRAFANA_PROMETHEUS_URL:  https://prometheus-us-central1.grafana.net
GRAFANA_CLOUD_API_KEY:   (create under My Account → API Keys → Add API key, role: MetricsPublisher)
```

Store all of these in AWS Secrets Manager:
```bash
aws secretsmanager create-secret \
  --name YOUR_PROJECT/production/grafana \
  --secret-string '{
    "GRAFANA_INSTANCE_ID": "123456",
    "GRAFANA_CLOUD_API_KEY": "your-api-key",
    "GRAFANA_LOKI_URL": "https://logs-prod-...",
    "GRAFANA_TEMPO_URL": "https://tempo-...",
    "GRAFANA_PROMETHEUS_URL": "https://prometheus-..."
  }'
```

---

## Step 3: Add OpenTelemetry to Node.js Backend

**3a. Install packages**
```bash
npm install \
  @opentelemetry/sdk-node \
  @opentelemetry/exporter-trace-otlp-http \
  @opentelemetry/exporter-metrics-otlp-http \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/sdk-metrics \
  @opentelemetry/resources \
  @opentelemetry/semantic-conventions
```

**3b. Create `backend/src/config/telemetry.js`**

This file must be loaded **before any other imports** in your app:

```javascript
import { NodeSDK } from '@opentelemetry/sdk-node'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http'
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node'
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics'
import { Resource } from '@opentelemetry/resources'
import { SEMRESATTRS_SERVICE_NAME, SEMRESATTRS_SERVICE_VERSION } from '@opentelemetry/semantic-conventions'

const resource = new Resource({
  [SEMRESATTRS_SERVICE_NAME]: process.env.SERVICE_NAME || 'api',
  [SEMRESATTRS_SERVICE_VERSION]: process.env.APP_VERSION || '1.0.0',
  environment: process.env.NODE_ENV || 'production',
})

const traceExporter = new OTLPTraceExporter({
  url: `${process.env.GRAFANA_TEMPO_URL}/otlp/v1/traces`,
  headers: {
    Authorization: `Basic ${Buffer.from(
      `${process.env.GRAFANA_INSTANCE_ID}:${process.env.GRAFANA_CLOUD_API_KEY}`
    ).toString('base64')}`,
  },
})

const metricExporter = new OTLPMetricExporter({
  url: `${process.env.GRAFANA_PROMETHEUS_URL}/otlp/v1/metrics`,
  headers: {
    Authorization: `Basic ${Buffer.from(
      `${process.env.GRAFANA_INSTANCE_ID}:${process.env.GRAFANA_CLOUD_API_KEY}`
    ).toString('base64')}`,
  },
})

const sdk = new NodeSDK({
  resource,
  traceExporter,
  metricReader: new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: 30000,  // every 30s
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-pg': { enhancedDatabaseReporting: true },
      '@opentelemetry/instrumentation-http': { ignoreIncomingPaths: ['/health'] },
    }),
  ],
})

sdk.start()

process.on('SIGTERM', () => sdk.shutdown())
```

**3c. Load telemetry before your app**

Update `backend/package.json`:
```json
{
  "scripts": {
    "start": "node --import ./src/config/telemetry.js src/index.js"
  }
}
```

Or in `backend/src/index.js`, make it the absolute first import:
```javascript
import './config/telemetry.js'  // Must be first — sets up instrumentation before any other module loads
import './config/sentry.js'
// ... rest of your imports
```

**3d. Add environment variables to ECS task definition**

Add to the `secrets` section of your ECS task:
```json
{
  "name": "GRAFANA_INSTANCE_ID",
  "valueFrom": "arn:aws:secretsmanager:...:YOUR_PROJECT/production/grafana:GRAFANA_INSTANCE_ID::"
},
{
  "name": "GRAFANA_CLOUD_API_KEY",
  "valueFrom": "arn:aws:secretsmanager:...:YOUR_PROJECT/production/grafana:GRAFANA_CLOUD_API_KEY::"
},
{
  "name": "GRAFANA_TEMPO_URL",
  "valueFrom": "arn:aws:secretsmanager:...:YOUR_PROJECT/production/grafana:GRAFANA_TEMPO_URL::"
},
{
  "name": "GRAFANA_PROMETHEUS_URL",
  "valueFrom": "arn:aws:secretsmanager:...:YOUR_PROJECT/production/grafana:GRAFANA_PROMETHEUS_URL::"
}
```

---

## Step 4: Ship Logs to Grafana Loki (Optional)

CloudWatch Logs is fine for Tier 1. For Tier 2, you can also send logs to Grafana Loki for unified searching alongside traces.

Option A: **CloudWatch → Loki via Lambda forwarder** (easiest, no code changes)
- Use the official `grafana/cloudwatch-logs-to-loki` Lambda function
- Triggers on CloudWatch log events and ships to Loki
- Setup: 30 minutes, no code changes to your app

Option B: **Pino transport for Loki** (direct, no Lambda needed)
```bash
npm install pino-loki
```
```javascript
// backend/src/config/logger.js
import pino from 'pino'
import pinoLoki from 'pino-loki'

const transport = pino.transport({
  targets: [
    {
      target: 'pino/file',  // keep stdout for CloudWatch
      options: { destination: 1 },
    },
    {
      target: 'pino-loki',
      options: {
        host: process.env.GRAFANA_LOKI_URL,
        basicAuth: {
          username: process.env.GRAFANA_INSTANCE_ID,
          password: process.env.GRAFANA_CLOUD_API_KEY,
        },
        labels: {
          service: process.env.SERVICE_NAME || 'api',
          env: process.env.NODE_ENV || 'production',
        },
      },
    },
  ],
})

export const logger = pino({ level: process.env.LOG_LEVEL || 'info' }, transport)
```

---

## Step 5: Import Pre-Built Grafana Dashboards

In Grafana Cloud → Dashboards → Import:

| Dashboard | Grafana ID | What it shows |
|---|---|---|
| Node.js | 11956 | Event loop lag, heap usage, GC, requests/sec |
| Express.js | 14565 | Route-level latency, error rates |
| AWS ECS | 12114 | Task CPU/memory, container health |
| PostgreSQL | 9628 | Query time, connections, cache hit rate |
| AWS RDS | 13154 | I/O, storage, connection pool |

Steps:
1. Grafana → Dashboards → Import
2. Enter the dashboard ID
3. Select your Prometheus/Loki data source
4. Click Import

You'll have production-grade dashboards running within 10 minutes.

---

## Step 6: Set Up Grafana Alerting

Replace CloudWatch alarms with Grafana alerts for a unified alerting experience.

**6a. Create a contact point** (Grafana → Alerting → Contact points)
- Add Email contact with your alert address
- Optional: Add Slack webhook for team notifications

**6b. Create alert rules**

In Grafana → Alerting → Alert rules → New alert rule:

**API Error Rate alert**:
```
# PromQL query (if using OTel metrics)
sum(rate(http_server_duration_count{status_code=~"5.."}[5m])) 
/ 
sum(rate(http_server_duration_count[5m])) > 0.05
```

**ECS CPU alert**:
```
# CloudWatch metric query via Grafana CloudWatch data source
SELECT AVG(CPUUtilization) 
FROM "AWS/ECS" 
WHERE ClusterName = 'your-cluster' 
  AND ServiceName = 'your-api'
```

**6c. Set notification policies**
- Default policy → your email contact point
- High-severity routes → also notify Slack/PagerDuty

---

## Step 7: Set Up Grafana Synthetic Monitoring (Uptime)

Grafana Cloud includes synthetic monitoring (uptime checks) for free.

1. Grafana → Synthetic Monitoring → New check
2. Type: HTTP
3. Target: `https://api.yourproject.com/health`
4. Frequency: every 60 seconds
5. Locations: select 3+ regions for redundancy
6. Alerts: enable on any failure

This gives you uptime checks from multiple geographic regions, alerting within 1 minute of downtime.

---

## Step 8: Upgrade Sentry to Team Plan

If you have >5k errors/month or need longer retention:

1. sentry.io → Settings → Billing → Upgrade to Team ($26/month)
2. Increase error quota to 100k/month
3. Increase transaction quota (for performance monitoring)

**Unified user context**: Configure user identification in Sentry so errors from backend and mobile are linked to the same user:

```javascript
// backend — set user context on authenticated requests
Sentry.setUser({ id: req.user.id, email: req.user.email })

// Clear on logout
Sentry.setUser(null)
```

```dart
// Flutter — identify user after login
await Sentry.configureScope((scope) {
  scope.setUser(SentryUser(id: user.id, email: user.email));
});
```

---

## Verification

After completing all steps:

```bash
# 1. Traces flowing to Grafana Tempo
# Make some API requests, then check:
# Grafana → Explore → Select Tempo data source → Search traces

# 2. Metrics in Prometheus/Mimir
# Grafana → Explore → Select Prometheus data source
# Query: http_server_duration_count

# 3. Dashboards populated
# Open Node.js dashboard — should show live data

# 4. Synthetic monitoring
# Grafana → Synthetic Monitoring → Checks — should show "Up"

# 5. Alerts configured
# Grafana → Alerting → Alert rules — all in Normal state
```

---

## What You Now Have (Tier 2)

| Capability | Where |
|---|---|
| Distributed traces | Grafana → Explore → Tempo |
| Live dashboards (ECS, Node.js, RDS) | Grafana → Dashboards |
| Unified log search | Grafana → Explore → Loki |
| Uptime monitoring | Grafana → Synthetic Monitoring |
| Unified alerting (all channels) | Grafana → Alerting |
| Backend exceptions | Sentry (100k errors/month) |
| Mobile crashes + backend correlation | Sentry (unified user context) |

Monthly cost: ~$55–80/month (Grafana free tier + Sentry Team $26 + Tier 1 base $6).

---

## When to Go to Tier 3

Consider Datadog when:
- You need enterprise SLAs and support contracts
- You have a 24/7 on-call rotation and need PagerDuty/OpsGenie deep integration
- Compliance requires vendor-certified security controls
- You're running multi-region and need global fleet dashboards
- Cost: $46+/host/month vs Grafana's model — only worth it at scale with compliance needs
