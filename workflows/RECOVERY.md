# Recovery Workflow — Disaster Recovery and Rollback

When a deployed project fails, follow these procedures.

---

## Failure Classification

| Symptom | Classification | Procedure |
|---|---|---|
| API returning 5xx errors | Application failure | App Rollback |
| ECS tasks failing to start | Container failure | Container Debug |
| Database connection errors | Database failure | Database Recovery |
| CI/CD pipeline broken | Pipeline failure | Pipeline Fix |
| Infrastructure drift | Infra failure | Infra Recovery |
| Complete outage | Critical | Full Rollback |

---

## App Rollback (ECS)

When the current deployment is broken, roll back to the previous task definition:

```bash
# 1. Get current task definition
CURRENT=$(aws ecs describe-services \
  --cluster [cluster-name] \
  --services [service-name] \
  --query 'services[0].taskDefinition' \
  --output text)
echo "Current: $CURRENT"

# 2. Get previous revision number
CURRENT_REV=$(echo $CURRENT | grep -oE '[0-9]+$')
PREV_REV=$((CURRENT_REV - 1))
FAMILY=$(echo $CURRENT | sed 's/:[0-9]*$//')

# 3. Roll back
echo "Rolling back to $FAMILY:$PREV_REV"
aws ecs update-service \
  --cluster [cluster-name] \
  --service [service-name] \
  --task-definition "$FAMILY:$PREV_REV"

# 4. Wait for stabilization
aws ecs wait services-stable \
  --cluster [cluster-name] \
  --services [service-name]

# 5. Verify
curl -s https://api.[domain]/health
```

---

## Container Debug

When ECS tasks won't start:

```bash
# 1. Check recent task failures
aws ecs list-tasks \
  --cluster [cluster-name] \
  --service-name [service-name] \
  --desired-status STOPPED \
  --query 'taskArns[0:5]'

# 2. Get failure reason
TASK_ARN=$(aws ecs list-tasks --cluster [cluster] --service-name [service] --desired-status STOPPED --query 'taskArns[0]' --output text)
aws ecs describe-tasks \
  --cluster [cluster-name] \
  --tasks "$TASK_ARN" \
  --query 'tasks[0].{reason:stoppedReason,code:stopCode,containers:containers[*].{name:name,reason:reason,exitCode:exitCode}}'

# 3. Check CloudWatch logs
aws logs filter-log-events \
  --log-group-name /ecs/[project]-[env]-api \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR" \
  --limit 20

# Common issues:
# - "Essential container exited" → check container logs for startup errors
# - "CannotPullContainerError" → ECR permissions or image doesn't exist
# - "ResourceNotFoundException" → secrets not found
# - OOM killed → increase task memory in task definition
```

---

## Database Recovery

When database connections fail:

```bash
# 1. Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier [project]-[env] \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}'

# 2. If status is not "available", check events
aws rds describe-events \
  --source-identifier [project]-[env] \
  --source-type db-instance \
  --duration 60

# 3. Check security group allows ECS access
# (ECS tasks should be in a security group that RDS allows)

# 4. Test connection from local (if VPN/bastion available)
psql "postgresql://[user]:[password]@[endpoint]:5432/[dbname]" -c "SELECT 1"

# 5. If storage is full
aws rds modify-db-instance \
  --db-instance-identifier [project]-[env] \
  --allocated-storage 40 \
  --apply-immediately

# 6. If need to restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier [project]-[env]-restored \
  --db-snapshot-identifier [snapshot-id]
```

---

## Pipeline Fix

When GitHub Actions CI/CD is broken:

```bash
# 1. Check recent workflow runs
gh run list --limit 10

# 2. View failure details
gh run view [run-id] --log-failed

# 3. Common fixes:
# - "Resource not accessible by integration" → check GITHUB_TOKEN permissions
# - "Credentials not found" → re-add GitHub Secrets
# - "Image not found" → ECR image was deleted, rebuild and push

# 4. Re-run failed workflow
gh run rerun [run-id] --failed

# 5. Manual deploy (bypass CI)
# Build and push image
docker build -t [ecr-url]:latest backend/
aws ecr get-login-password | docker login --username AWS --password-stdin [ecr-url]
docker push [ecr-url]:latest

# Force new deployment
aws ecs update-service \
  --cluster [cluster] \
  --service [service] \
  --force-new-deployment
```

---

## Infra Recovery

When OpenTofu state drifts from reality:

```bash
# 1. Detect drift
cd infra
tofu plan
# Look for unexpected changes

# 2. If resource was manually modified, import current state
tofu import aws_ecs_service.api [cluster-name]/[service-name]

# 3. If resource was deleted outside tofu, recreate
tofu apply -target=module.compute.aws_ecs_service.api

# 4. If state is corrupted, refresh from cloud
tofu refresh

# 5. NEVER do this without Orchestrator approval:
# tofu destroy (destroys everything)
```

---

## Full Rollback

When everything is broken and you need to start fresh:

**⚠️ REQUIRES HUMAN APPROVAL — THIS IS DESTRUCTIVE**

```bash
# 1. Backup database first
aws rds create-db-snapshot \
  --db-instance-identifier [project]-[env] \
  --db-snapshot-identifier [project]-[env]-emergency-$(date +%Y%m%d-%H%M)

# 2. Get git history
cd [project]
git log --oneline -20
# Find the last known-good commit

# 3. Create rollback branch
git checkout -b rollback/[date] [good-commit]
git push origin rollback/[date]

# 4. Deploy rollback branch
# Update GitHub Actions to deploy from rollback branch, or:
gh workflow run backend-deploy.yml --ref rollback/[date]

# 5. If infra changes are needed
cd infra
git checkout [good-commit] -- .
tofu plan  # Review carefully
tofu apply

# 6. Document what happened
# Create incident report in brain/lessons/
```

---

## Post-Recovery

After any recovery:

1. **Document** what happened in `brain/lessons/[project]-incident-[date].md`
2. **Update** monitoring if the failure wasn't caught
3. **Add** to `brain/improvements/queue.md` if factory changes needed
4. **Notify** human with incident summary
