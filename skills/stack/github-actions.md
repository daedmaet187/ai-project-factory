# GitHub Actions — CI/CD Pipeline Patterns

Read this before creating or modifying any CI/CD workflows.

---

## Workflow Organization

```
.github/
└── workflows/
    ├── backend-ci.yml        ← Lint + test on every push/PR
    ├── backend-deploy.yml    ← Deploy to ECS on main push
    ├── admin-ci.yml          ← Build + lint on every push/PR
    ├── admin-deploy.yml      ← Deploy to Cloudflare Pages on main push
    ├── mobile-ci.yml         ← Flutter analyze + test on every push/PR
    └── infra-plan.yml        ← tofu plan on PR, tofu apply on main merge
```

---

## Backend CI + Deploy

```yaml
# .github/workflows/backend-ci.yml
name: Backend CI

on:
  push:
    paths: ['backend/**', '.github/workflows/backend-*.yml']
  pull_request:
    paths: ['backend/**']

jobs:
  ci:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json
      
      - run: npm ci
      
      - name: Lint
        run: npm run lint
      
      - name: Test
        run: npm test
        env:
          NODE_ENV: test
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/testdb
      
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports: ['5432:5432']
```

```yaml
# .github/workflows/backend-deploy.yml
name: Backend Deploy

on:
  push:
    branches: [main]
    paths: ['backend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Login to ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push
        env:
          REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          REPO: ${{ vars.ECR_REPOSITORY }}
          SHA: ${{ github.sha }}
        run: |
          docker build -t $REGISTRY/$REPO:$SHA -t $REGISTRY/$REPO:latest backend/
          docker push $REGISTRY/$REPO:$SHA
          docker push $REGISTRY/$REPO:latest

      - name: Deploy to ECS
        env:
          CLUSTER: ${{ vars.ECS_CLUSTER }}
          SERVICE: ${{ vars.ECS_SERVICE }}
        run: |
          aws ecs update-service \
            --cluster $CLUSTER \
            --service $SERVICE \
            --force-new-deployment
          
          aws ecs wait services-stable \
            --cluster $CLUSTER \
            --services $SERVICE

      - name: Health check
        run: |
          sleep 10
          curl -f https://${{ vars.API_DOMAIN }}/health || exit 1
```

---

## Admin Frontend — Cloudflare Pages Deploy

```yaml
# .github/workflows/admin-deploy.yml
name: Admin Deploy

on:
  push:
    branches: [main]
    paths: ['admin/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: admin
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: admin/package-lock.json
      
      - run: npm ci
      
      - name: Build
        run: npm run build
        env:
          VITE_API_URL: ${{ vars.API_URL }}
      
      - name: Deploy to Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CF_API_TOKEN }}
          accountId: ${{ secrets.CF_ACCOUNT_ID }}
          command: pages deploy dist --project-name=${{ vars.CF_PAGES_PROJECT }}
          workingDirectory: admin
```

---

## Flutter Mobile CI

```yaml
# .github/workflows/mobile-ci.yml
name: Mobile CI

on:
  push:
    paths: ['mobile/**']
  pull_request:
    paths: ['mobile/**']

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: mobile
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'
          cache: true
      
      - run: flutter pub get
      
      - name: Generate code
        run: flutter pub run build_runner build --delete-conflicting-outputs
      
      - name: Analyze
        run: flutter analyze --no-fatal-infos
      
      - name: Test
        run: flutter test --coverage
      
      - name: Check coverage
        run: |
          lcov --summary coverage/lcov.info 2>&1 | grep "lines"
```

---

## Infrastructure Plan on PR

```yaml
# .github/workflows/infra-plan.yml
name: Infrastructure

on:
  pull_request:
    paths: ['infra/**']
  push:
    branches: [main]
    paths: ['infra/**']

jobs:
  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: infra
    steps:
      - uses: actions/checkout@v4
      
      - uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: '1.8.x'
      
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - run: tofu init
      
      - name: Plan
        id: plan
        run: tofu plan -no-color 2>&1 | tee plan.txt
        continue-on-error: true  # Don't fail job — we'll comment result
      
      - name: Comment plan on PR
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs')
            const plan = fs.readFileSync('infra/plan.txt', 'utf8')
            const truncated = plan.length > 65000 ? plan.slice(0, 65000) + '\n...(truncated)' : plan
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Infrastructure Plan\n\`\`\`\n${truncated}\n\`\`\``
            })

  apply:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval in GitHub
    defaults:
      run:
        working-directory: infra
    steps:
      - uses: actions/checkout@v4
      - uses: opentofu/setup-opentofu@v1
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - run: tofu init
      - run: tofu apply -auto-approve
```

---

## Required GitHub Secrets

Set these with `gh secret set`:

```bash
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set CF_API_TOKEN
gh secret set CF_ACCOUNT_ID
```

Set these as Variables (not secrets — non-sensitive):
```bash
gh variable set AWS_REGION --body "us-east-1"
gh variable set ECR_REPOSITORY --body "myproject-api"
gh variable set ECS_CLUSTER --body "myproject-production"
gh variable set ECS_SERVICE --body "myproject-api"
gh variable set API_DOMAIN --body "api.example.com"
gh variable set API_URL --body "https://api.example.com"
gh variable set CF_PAGES_PROJECT --body "myproject-admin"
```

---

## Monitoring Running Workflows

```bash
# List recent runs
gh run list --limit 10

# Watch a running workflow
gh run watch [run-id]

# View logs of failed run
gh run view [run-id] --log-failed

# Re-run failed job
gh run rerun [run-id] --failed

# Trigger workflow manually
gh workflow run backend-deploy.yml --ref main
```
