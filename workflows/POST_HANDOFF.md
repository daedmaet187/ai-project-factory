# Post-Handoff Monitoring — Optional Continuous Health Checks

After a project is handed off, the human can opt into ongoing monitoring.

---

## What Gets Monitored

| Check | Frequency | Alert on |
|---|---|---|
| API health endpoint | Every 15 min | Non-200 response or timeout |
| SSL certificate expiry | Daily | < 14 days remaining |
| Dependency vulnerabilities | Weekly | High/critical CVEs |
| CloudWatch alarm status | Hourly | Any alarm in ALARM state |
| Database connection count | Hourly | > 80% of max connections |

---

## Opt-In During Handoff

In HANDOFF.md, add this section:

```markdown
## Ongoing Monitoring (Optional)

Want me to keep an eye on this project after handoff?

If yes, I'll:
- Ping your /health endpoint every 15 minutes
- Alert you if anything goes down
- Run weekly dependency audits
- Check for CloudWatch alarms

To enable: Add this GitHub Actions workflow to your repo:
.github/workflows/health-check.yml (generated below)

To disable later: Delete the workflow file or disable it in GitHub Actions.
```

---

## Generated Health Check Workflow

Create `.github/workflows/health-check.yml` in the generated project:

```yaml
name: Health Check

on:
  schedule:
    - cron: '*/15 * * * *'  # Every 15 minutes
  workflow_dispatch:

jobs:
  health:
    runs-on: ubuntu-latest
    steps:
      - name: Check API health
        id: health
        run: |
          RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 10 \
            "${{ vars.API_URL }}/health")
          echo "status=$RESPONSE" >> $GITHUB_OUTPUT
          if [ "$RESPONSE" != "200" ]; then
            echo "❌ Health check failed: HTTP $RESPONSE"
            exit 1
          fi
          echo "✅ Health check passed"

      - name: Alert on failure
        if: failure()
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
        run: |
          if [ -n "$SLACK_WEBHOOK" ]; then
            curl -X POST "$SLACK_WEBHOOK" \
              -H "Content-Type: application/json" \
              -d '{"text":"🚨 Health check failed for ${{ github.repository }}\nStatus: ${{ steps.health.outputs.status }}\nTime: '"$(date -u)"'"}'
          fi

  ssl-check:
    runs-on: ubuntu-latest
    if: github.event.schedule == '0 9 * * *'  # Daily at 9am
    steps:
      - name: Check SSL expiry
        run: |
          DOMAIN="${{ vars.API_DOMAIN }}"
          EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null \
            | openssl x509 -noout -enddate | cut -d= -f2)
          EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
          NOW_EPOCH=$(date +%s)
          DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
          
          echo "SSL certificate expires in $DAYS_LEFT days"
          if [ "$DAYS_LEFT" -lt 14 ]; then
            echo "⚠️ Certificate expiring soon!"
            exit 1
          fi

  dependency-audit:
    runs-on: ubuntu-latest
    if: github.event.schedule == '0 10 * * 1'  # Weekly on Monday
    steps:
      - uses: actions/checkout@v4
      
      - name: Audit npm dependencies
        working-directory: backend
        run: |
          npm audit --audit-level=high
        continue-on-error: true
      
      - name: Create issue if vulnerabilities found
        if: failure()
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh issue create \
            --title "Security: npm audit found vulnerabilities" \
            --body "Weekly dependency audit found high/critical vulnerabilities. Run \`npm audit\` in the backend directory for details." \
            --label "security"
```

---

## Factory Integration

Add to `brain/metrics/registry.json` schema:

```json
{
  "health_monitoring": {
    "enabled": true,
    "last_check": "2026-03-20T15:00:00Z",
    "status": "healthy",
    "uptime_30d": 99.9
  }
}
```

The Brain Agent can use this to track project health over time.
