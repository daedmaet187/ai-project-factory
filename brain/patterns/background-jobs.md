# Pattern: Background Jobs

**Problem**: Process tasks asynchronously without blocking HTTP responses
**Applies to**: Node.js backend with Redis
**Last validated**: [Not yet validated — template]

---

## Solution Overview

1. HTTP handler enqueues a job and returns immediately (fast response)
2. BullMQ worker picks up job from Redis queue
3. Worker processes job, updates database with result
4. Optional: notify client via WebSocket/SSE when job completes

---

## Backend Implementation (BullMQ + Redis)

### Queue Setup

```javascript
// src/queues/index.js
import { Queue, Worker, QueueEvents } from 'bullmq';

const connection = {
  host: process.env.REDIS_HOST,
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD,
};

// Create queues
export const emailQueue = new Queue('email', { connection });
export const reportQueue = new Queue('reports', { connection });

// Queue events for monitoring
export const emailQueueEvents = new QueueEvents('email', { connection });
```

### Worker Definition

```javascript
// src/workers/email.worker.js
import { Worker } from 'bullmq';
import { sendEmail } from '../services/email.js';

const worker = new Worker(
  'email',
  async (job) => {
    const { to, subject, template, data } = job.data;

    // Update progress
    await job.updateProgress(10);

    const html = await renderTemplate(template, data);
    await job.updateProgress(50);

    await sendEmail({ to, subject, html });
    await job.updateProgress(100);

    return { sent: true, to };
  },
  {
    connection: {
      host: process.env.REDIS_HOST,
      port: parseInt(process.env.REDIS_PORT || '6379'),
      password: process.env.REDIS_PASSWORD,
    },
    concurrency: 5,
    // Retry failed jobs
    defaultJobOptions: {
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 1000,
      },
    },
  }
);

worker.on('completed', (job) => {
  console.log(`Job ${job.id} completed`);
});

worker.on('failed', (job, err) => {
  console.error(`Job ${job?.id} failed:`, err.message);
});

export default worker;
```

### Enqueuing Jobs

```javascript
// src/routes/reports.js
router.post('/reports/generate', requireAuth, async (req, res) => {
  const { reportType, dateRange } = req.body;

  // Enqueue job — returns immediately
  const job = await reportQueue.add('generate', {
    userId: req.user.id,
    reportType,
    dateRange,
  }, {
    // Job options
    priority: req.user.role === 'admin' ? 1 : 10,
    delay: 0,
  });

  res.status(202).json({
    jobId: job.id,
    status: 'queued',
    statusUrl: `/api/reports/status/${job.id}`,
  });
});

// Check job status
router.get('/reports/status/:jobId', requireAuth, async (req, res) => {
  const job = await reportQueue.getJob(req.params.jobId);

  if (!job) {
    return res.status(404).json({ error: 'Job not found' });
  }

  const state = await job.getState();
  const progress = job.progress;

  res.json({
    jobId: job.id,
    state,   // waiting, active, completed, failed
    progress,
    result: state === 'completed' ? job.returnvalue : null,
    error: state === 'failed' ? job.failedReason : null,
  });
});
```

---

## ECS Scheduled Tasks

For cron-like recurring jobs (nightly reports, cleanup tasks):

```hcl
# infra/modules/scheduled-tasks/main.tf
resource "aws_ecs_task_definition" "nightly_cleanup" {
  family                   = "${var.project_name}-nightly-cleanup"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([{
    name  = "cleanup"
    image = "${var.ecr_url}:latest"
    command = ["node", "src/scripts/nightly-cleanup.js"]
    environment = [
      { name = "NODE_ENV", value = "production" }
    ]
    secrets = [
      { name = "DATABASE_URL", valueFrom = "${var.secrets_arn}:DATABASE_URL::" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"  = "/ecs/${var.project_name}-cleanup"
        "awslogs-region" = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_scheduler_schedule" "nightly_cleanup" {
  name = "${var.project_name}-nightly-cleanup"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 2 * * ? *)"  # 2 AM UTC daily

  target {
    arn      = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.ecs_cluster_name}"
    role_arn = aws_iam_role.scheduler.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.nightly_cleanup.arn
      launch_type         = "FARGATE"

      network_configuration {
        subnets          = var.private_subnet_ids
        security_groups  = [aws_security_group.cleanup_task.id]
        assign_public_ip = false
      }
    }
  }
}
```

---

## Gotchas

1. **Always return 202 Accepted for async operations** — not 200, because work isn't done yet
2. **Set job TTL** — completed/failed jobs accumulate in Redis; set `removeOnComplete` and `removeOnFail`
3. **Handle duplicate jobs** — use job IDs based on business identity (e.g., `report-user123-2026-03`) to deduplicate
4. **Worker concurrency vs Redis connections** — each worker concurrent job uses one Redis connection
5. **Graceful shutdown** — call `worker.close()` on SIGTERM to finish in-flight jobs before exit

---

## See Also

- `stacks/backend/nodejs-express.md` — Redis setup
- `brain/patterns/realtime.md` — Notifying clients when jobs complete
