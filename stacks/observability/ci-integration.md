# Observability CI/CD Integration

Every deployment must record a deployment marker so you can correlate errors with code changes.

---

## 1. Sentry Release Tracking

Add to every backend deploy workflow **after** the successful ECS update step:

```yaml
- name: Create Sentry Release
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
    SENTRY_ORG: ${{ secrets.SENTRY_ORG }}
    SENTRY_PROJECT: ${{ secrets.SENTRY_PROJECT }}
  run: |
    npm install -g @sentry/cli
    sentry-cli releases new ${{ github.sha }}
    sentry-cli releases set-commits ${{ github.sha }} --auto
    sentry-cli releases finalize ${{ github.sha }}
    sentry-cli releases deploys ${{ github.sha }} new -e production
```

**Effect**: In Sentry, every error shows which release introduced it. "Regressions" are automatically detected when an issue reappears after being resolved in a previous release.

---

## 2. Grafana Deployment Annotations (Tier 2+)

When a deploy succeeds, POST an annotation to Grafana so dashboards show a vertical line at each deployment:

```yaml
- name: Annotate Grafana deployment
  env:
    GRAFANA_URL: ${{ secrets.GRAFANA_URL }}          # e.g. https://yourorg.grafana.net
    GRAFANA_API_KEY: ${{ secrets.GRAFANA_API_KEY }}
  run: |
    curl -s -X POST "$GRAFANA_URL/api/annotations" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $GRAFANA_API_KEY" \
      -d '{
        "text": "Deployed ${{ github.sha }} by ${{ github.actor }}",
        "tags": ["deployment", "production"],
        "time": '"$(date +%s%3N)"'
      }'
```

---

## 3. Health Check Verification After Deploy

Every deployment workflow must verify the API is healthy before marking success. Add **after** the ECS update:

```yaml
- name: Verify deployment health
  run: |
    echo "Waiting for ECS service to stabilize..."
    aws ecs wait services-stable \
      --cluster ${{ vars.ECS_CLUSTER }} \
      --services ${{ vars.ECS_SERVICE }}

    echo "Checking API health endpoint..."
    for i in 1 2 3 4 5; do
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://${{ vars.API_DOMAIN }}/health)
      if [ "$STATUS" = "200" ]; then
        echo "✅ Health check passed (attempt $i)"
        exit 0
      fi
      echo "⏳ Health check returned $STATUS, waiting 10s (attempt $i/5)..."
      sleep 10
    done
    echo "❌ Health check failed after 5 attempts"
    exit 1
```

---

## 4. Automatic Rollback on Health Check Failure

If health check fails post-deploy, roll back to the previous task definition:

```yaml
- name: Rollback on failure
  if: failure()
  run: |
    PREV_TASK_DEF=$(aws ecs describe-services \
      --cluster ${{ vars.ECS_CLUSTER }} \
      --services ${{ vars.ECS_SERVICE }} \
      --query 'services[0].deployments[?status==`PRIMARY`].taskDefinition | [0]' \
      --output text)

    PREV_REVISION=$(echo $PREV_TASK_DEF | sed 's/.*://')
    PREV_PREV=$((PREV_REVISION - 1))
    FAMILY=$(echo $PREV_TASK_DEF | cut -d: -f6 | cut -d/ -f2)

    echo "Rolling back to $FAMILY:$PREV_PREV"
    aws ecs update-service \
      --cluster ${{ vars.ECS_CLUSTER }} \
      --service ${{ vars.ECS_SERVICE }} \
      --task-definition "$FAMILY:$PREV_PREV"
```

---

## 5. Full Backend Deploy Workflow — Complete Reference

The complete `.github/workflows/backend-deploy.yml` with all observability steps integrated:

```yaml
name: Deploy Backend

on:
  push:
    branches: [main]
    paths: ['backend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Login to ECR
        id: ecr-login
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, push image
        env:
          ECR_REGISTRY: ${{ steps.ecr-login.outputs.registry }}
          ECR_REPOSITORY: ${{ vars.ECR_REPOSITORY }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build \
            --build-arg APP_VERSION=$IMAGE_TAG \
            -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
            backend/
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
                     $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster ${{ vars.ECS_CLUSTER }} \
            --service ${{ vars.ECS_SERVICE }} \
            --force-new-deployment

      - name: Verify deployment health
        run: |
          echo "Waiting for ECS service to stabilize..."
          aws ecs wait services-stable \
            --cluster ${{ vars.ECS_CLUSTER }} \
            --services ${{ vars.ECS_SERVICE }}

          echo "Checking API health endpoint..."
          for i in 1 2 3 4 5; do
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://${{ vars.API_DOMAIN }}/health)
            if [ "$STATUS" = "200" ]; then
              echo "✅ Health check passed (attempt $i)"
              exit 0
            fi
            echo "⏳ Health check returned $STATUS, waiting 10s (attempt $i/5)..."
            sleep 10
          done
          echo "❌ Health check failed after 5 attempts"
          exit 1

      - name: Rollback on failure
        if: failure()
        run: |
          PREV_TASK_DEF=$(aws ecs describe-services \
            --cluster ${{ vars.ECS_CLUSTER }} \
            --services ${{ vars.ECS_SERVICE }} \
            --query 'services[0].deployments[?status==`PRIMARY`].taskDefinition | [0]' \
            --output text)
          PREV_REVISION=$(echo $PREV_TASK_DEF | sed 's/.*://')
          PREV_PREV=$((PREV_REVISION - 1))
          FAMILY=$(echo $PREV_TASK_DEF | cut -d: -f6 | cut -d/ -f2)
          echo "Rolling back to $FAMILY:$PREV_PREV"
          aws ecs update-service \
            --cluster ${{ vars.ECS_CLUSTER }} \
            --service ${{ vars.ECS_SERVICE }} \
            --task-definition "$FAMILY:$PREV_PREV"

      - name: Create Sentry Release
        if: success() && env.SENTRY_AUTH_TOKEN != ''
        env:
          SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
          SENTRY_ORG: ${{ secrets.SENTRY_ORG }}
          SENTRY_PROJECT: ${{ secrets.SENTRY_PROJECT }}
        run: |
          npm install -g @sentry/cli
          sentry-cli releases new ${{ github.sha }}
          sentry-cli releases set-commits ${{ github.sha }} --auto
          sentry-cli releases finalize ${{ github.sha }}
          sentry-cli releases deploys ${{ github.sha }} new -e production

      - name: Annotate Grafana deployment
        if: success() && env.GRAFANA_URL != ''
        env:
          GRAFANA_URL: ${{ secrets.GRAFANA_URL }}
          GRAFANA_API_KEY: ${{ secrets.GRAFANA_API_KEY }}
        run: |
          curl -s -X POST "$GRAFANA_URL/api/annotations" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $GRAFANA_API_KEY" \
            -d '{
              "text": "Deployed ${{ github.sha }} by ${{ github.actor }}",
              "tags": ["deployment", "production"],
              "time": '"$(date +%s%3N)"'
            }'
```

---

## 6. GitHub Secrets Needed for Observability

Add these to GitHub Secrets in addition to existing AWS/CF credentials:

```
SENTRY_AUTH_TOKEN       # from sentry.io → Settings → Auth Tokens
SENTRY_ORG              # your Sentry organization slug
SENTRY_PROJECT          # your Sentry project slug (backend)
SENTRY_MOBILE_PROJECT   # your Sentry project slug (Flutter)
GRAFANA_URL             # https://yourorg.grafana.net (Tier 2+ only)
GRAFANA_API_KEY         # Grafana API key with Editor role (Tier 2+ only)
```

Sentry and Grafana steps are **conditional on secrets existing** — if not set, the steps are skipped cleanly. No broken builds from missing observability config.
