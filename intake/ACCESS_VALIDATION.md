# Access Validation — Deep Credential Verification

Before running intake questions, validate that all provided credentials have sufficient permissions.

---

## Why Deep Validation?

Shallow validation (credential exists) catches typos.
Deep validation (credential has required permissions) prevents failures during infrastructure provisioning (Phase 2) or CI/CD verification (Phase 6).

---

## Validation Commands

Run these before proceeding with intake. All must pass.

### AWS Credentials

```bash
# 1. Verify identity
aws sts get-caller-identity
# Expected: returns AccountId, UserId, Arn

# 2. Check required permissions exist
# Create a test policy document
cat > /tmp/aws-perms-check.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ecs:CreateCluster",
      "ecs:CreateService",
      "ecr:CreateRepository",
      "rds:CreateDBInstance",
      "secretsmanager:CreateSecret",
      "s3:CreateBucket",
      "elasticloadbalancing:CreateLoadBalancer",
      "ec2:CreateVpc",
      "cloudwatch:PutMetricAlarm",
      "sns:CreateTopic",
      "cloudtrail:CreateTrail"
    ],
    "Resource": "*"
  }]
}
EOF

# 3. Simulate the policy (requires iam:SimulatePrincipalPolicy permission)
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
aws iam simulate-principal-policy \
  --policy-source-arn "$CALLER_ARN" \
  --action-names \
    ecs:CreateCluster \
    ecr:CreateRepository \
    rds:CreateDBInstance \
    secretsmanager:CreateSecret \
    s3:CreateBucket \
  --query 'EvaluationResults[*].{Action:EvalActionName,Decision:EvalDecision}' \
  --output table

# Expected: all actions show "allowed"
# If any show "implicitDeny" or "explicitDeny" → credential lacks permissions
```

### Cloudflare Credentials

```bash
# 1. Verify token works
curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.success'
# Expected: true

# 2. Check zone permissions (requires zone ID from ACCESS.md)
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '{
    name: .result.name,
    permissions: .result.permissions
  }'
# Expected: permissions array includes "dns_records:edit", "zone_settings:edit"

# 3. Check account-level permissions (for Pages)
curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.success'
# Expected: true (if using Cloudflare Pages)
```

### GitHub Credentials

```bash
# 1. Verify token and check scopes
curl -s -I -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user | grep -i "x-oauth-scopes"
# Expected: includes "repo", "workflow", "admin:repo_hook"

# 2. Verify org/repo access
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO" 2>/dev/null \
  | jq '{permissions: .permissions}'
# Expected: admin: true, push: true (or repo doesn't exist yet, which is fine)

# 3. Check Actions is enabled for the org
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/orgs/$GITHUB_ORG/actions/permissions" \
  | jq '.enabled_repositories'
# Expected: "all" or "selected" (not "none")
```

### Figma (Optional)

```bash
# Verify Figma token if provided
if [ -n "$FIGMA_TOKEN" ]; then
  curl -s -H "X-Figma-Token: $FIGMA_TOKEN" \
    "https://api.figma.com/v1/me" | jq '.email'
  # Expected: returns email (not error)
fi
```

---

## Validation Report Format

After running all checks, report to human:

```
ACCESS VALIDATION RESULTS

AWS:
  ✅ Identity verified: arn:aws:iam::123456789:user/deploy-user
  ✅ ECS permissions: allowed
  ✅ ECR permissions: allowed
  ✅ RDS permissions: allowed
  ✅ Secrets Manager permissions: allowed
  ✅ S3 permissions: allowed

Cloudflare:
  ✅ Token valid
  ✅ Zone access: example.com
  ✅ DNS edit permission: yes

GitHub:
  ✅ Token valid
  ✅ Scopes: repo, workflow, admin:repo_hook
  ✅ Org access: myorg

Figma:
  ⏭️ Not provided (will use style description instead)

All required credentials validated. Proceeding to intake.
```

If any check fails:

```
ACCESS VALIDATION FAILED

AWS:
  ❌ RDS permissions: implicitDeny
     Missing permission: rds:CreateDBInstance
     
     To fix: Add the following policy to your IAM user/role:
     {
       "Effect": "Allow",
       "Action": "rds:*",
       "Resource": "*"
     }

Cannot proceed until this is fixed. Update ACCESS.md and re-run validation.
```

---

## Integration with Generation Workflow

Update `workflows/GENERATION.md` Pre-Generation section:

```markdown
### Step 0: Deep Access Validation (NEW)

Before running preflight or intake:

1. Read `intake/ACCESS.md` for provided credentials
2. Run validation commands from `intake/ACCESS_VALIDATION.md`
3. If any validation fails → stop, report what's missing, help human fix
4. If all pass → proceed to Step 1 (Preflight)

Do not proceed to intake until all credentials are validated.
```
