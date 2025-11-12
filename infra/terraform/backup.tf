locals {
  backup_s3_prefix = "${local.name_prefix}/pgdump"
}

resource "aws_cloudwatch_log_group" "ecs_backup" {
  name              = "/aws/ecs/${local.name_prefix}-backup"
  retention_in_days = var.app_log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backup-logs"
  })
}

data "aws_iam_policy_document" "ecs_backup_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_backup_task" {
  name               = "${local.name_prefix}-backup-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_backup_task_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backup-task-role"
  })
}

resource "aws_iam_role_policy" "ecs_backup_task_s3" {
  name = "${local.name_prefix}-backup-task-s3"
  role = aws_iam_role.ecs_backup_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${local.rds_backup_bucket_name}",
          "arn:aws:s3:::${local.rds_backup_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_ecs_task_definition" "db_backup" {
  family                   = "${local.name_prefix}-db-backup"
  cpu                      = var.backup_task_cpu
  memory                   = var.backup_task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_backup_task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "db-backup"
      image     = var.backup_task_image
      essential = true
      command = [
        "/bin/sh",
        "-c",
        <<-EOF
          set -euo pipefail
          if ! command -v aws >/dev/null 2>&1; then
            apt-get update >/dev/null && apt-get install -y awscli >/dev/null
          fi
          export BACKUP_FILE="backup-$(date -u +%Y%m%dT%H%M%SZ).dump"
          pg_dump --clean --if-exists --format=custom --host="$PGHOST" --port="$PGPORT" --username="$PGUSER" "$PGDATABASE" | \
            aws s3 cp - "s3://$S3_BUCKET/$S3_PREFIX/$BACKUP_FILE"
          echo "BACKUP_SUCCESS $BACKUP_FILE"
        EOF
      ]
      environment = [
        { name = "PGHOST", value = aws_db_instance.postgres.address },
        { name = "PGPORT", value = "5432" },
        { name = "PGUSER", value = var.db_username },
        { name = "PGPASSWORD", value = var.db_password },
        { name = "PGDATABASE", value = var.db_name },
        { name = "S3_BUCKET", value = local.rds_backup_bucket_name },
        { name = "S3_PREFIX", value = local.backup_s3_prefix },
        { name = "AWS_DEFAULT_REGION", value = var.aws_region }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_backup.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "backup"
        }
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-backup-task"
  })
}

data "aws_iam_policy_document" "events_run_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events_run_task" {
  name               = "${local.name_prefix}-events-run-task"
  assume_role_policy = data.aws_iam_policy_document.events_run_task_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-events-run-task"
  })
}

resource "aws_iam_role_policy" "events_run_task" {
  name = "${local.name_prefix}-events-run-task"
  role = aws_iam_role.events_run_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks"
        ]
        Resource = [
          aws_ecs_task_definition.db_backup.arn,
          "${aws_ecs_task_definition.db_backup.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_backup_task.arn
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "db_backup_schedule" {
  name                = "${local.name_prefix}-db-backup-schedule"
  description         = "Daily pg_dump backup"
  schedule_expression = var.backup_schedule_cron
}

resource "aws_cloudwatch_event_target" "db_backup" {
  rule      = aws_cloudwatch_event_rule.db_backup_schedule.name
  target_id = "run-db-backup"
  arn       = aws_ecs_cluster.main.arn
  role_arn  = aws_iam_role.events_run_task.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.db_backup.arn
    launch_type         = "FARGATE"
    task_count          = 1

    network_configuration {
      subnets          = [for subnet in values(aws_subnet.private) : subnet.id]
      security_groups  = [aws_security_group.ecs_tasks.id]
      assign_public_ip = false
    }
  }
}

resource "aws_cloudwatch_event_rule" "db_backup_failures" {
  name        = "${local.name_prefix}-db-backup-failures"
  description = "Notify when scheduled backup task fails"
  event_pattern = jsonencode({
    "source" : ["aws.ecs"],
    "detail-type" : ["ECS Task State Change"],
    "detail" : {
      "clusterArn" : [aws_ecs_cluster.main.arn],
      "taskDefinitionArn" : [aws_ecs_task_definition.db_backup.arn],
      "lastStatus" : ["STOPPED"],
      "containers" : {
        "exitCode" : [
          {
            "numeric" : [">", 0]
          }
        ]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "db_backup_failure_alert" {
  rule      = aws_cloudwatch_event_rule.db_backup_failures.name
  target_id = "db-backup-failure-alert"
  arn       = aws_sns_topic.alerts.arn
}
