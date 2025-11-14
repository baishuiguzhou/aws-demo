resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cluster"
  })
}

resource "aws_cloudwatch_log_group" "ecs_app" {
  name              = "/aws/ecs/${local.name_prefix}-app"
  retention_in_days = var.app_log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-logs"
  })
}

data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name_prefix}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-exec-role"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-task-role"
  })
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}-task"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = local.app_image_uri
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "APP_ENV", value = var.environment },
        { name = "APP_NAME", value = var.project_name },
        { name = "APP_KEY", value = var.app_key },
        { name = "APP_DEBUG", value = "false" },
        { name = "DB_CONNECTION", value = "pgsql" },
        { name = "DB_HOST", value = aws_db_instance.postgres.address },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_DATABASE", value = var.db_name },
        { name = "DB_USERNAME", value = var.db_username },
        { name = "DB_PASSWORD", value = var.db_password },
        { name = "LOG_CHANNEL", value = "stack" },
        { name = "LOG_LEVEL", value = "info" },
        { name = "APP_KEY", value = var.app_key },
        { name = "APP_DEBUG", value = "true" },
        { name = "DB_CONNECTION", value = "pgsql" },
        { name = "DB_HOST", value = aws_db_instance.postgres.address },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_DATABASE", value = var.db_name },
        { name = "DB_USERNAME", value = var.db_username },
        { name = "DB_PASSWORD", value = var.db_password },
        { name = "LOG_CHANNEL", value = "stderr" },
        { name = "LOG_LEVEL", value = "debug" },
        { name = "APPCONFIG_APPLICATION_ID", value = aws_appconfig_application.main.id },
        { name = "APPCONFIG_ENVIRONMENT_ID", value = aws_appconfig_environment.main.environment_id },
        { name = "APPCONFIG_CONFIGURATION_PROFILE_ID", value = aws_appconfig_configuration_profile.main.configuration_profile_id },
        { name = "APPCONFIG_ENDPOINT", value = "http://127.0.0.1:2772/applications/${aws_appconfig_application.main.id}/environments/${aws_appconfig_environment.main.environment_id}/configurations/${aws_appconfig_configuration_profile.main.configuration_profile_id}" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "app"
        }
      }
    },
    {
      name      = "appconfig-agent"
      image     = "public.ecr.aws/aws-appconfig/aws-appconfig-agent:latest"
      essential = false
      portMappings = [
        {
          containerPort = 2772
          hostPort      = 2772
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "AWS_APPCONFIG_APPLICATION_ID", value = aws_appconfig_application.main.id },
        { name = "AWS_APPCONFIG_ENVIRONMENT_ID", value = aws_appconfig_environment.main.environment_id },
        { name = "AWS_APPCONFIG_CONFIGURATION_PROFILE_ID", value = aws_appconfig_configuration_profile.main.configuration_profile_id },
        { name = "AWS_APPCONFIG_POLL_INTERVAL_SECONDS", value = "30" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "appconfig-agent"
        }
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-task"
  })
}

resource "aws_ecs_service" "app" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  enable_execute_command             = true

  network_configuration {
    subnets          = [for subnet in values(aws_subnet.private) : subnet.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_lb_listener.http]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-service"
  })
}

resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = max(var.scale_up_desired_count, var.desired_count)
  min_capacity       = var.desired_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.app]
}

resource "aws_appautoscaling_scheduled_action" "scale_up" {
  name               = "${local.name_prefix}-scale-up"
  schedule           = var.scale_up_cron
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension

  scalable_target_action {
    min_capacity = var.scale_up_desired_count
    max_capacity = var.scale_up_desired_count
  }
}

resource "aws_appautoscaling_scheduled_action" "scale_down" {
  name               = "${local.name_prefix}-scale-down"
  schedule           = var.scale_down_cron
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension

  scalable_target_action {
    min_capacity = var.desired_count
    max_capacity = var.desired_count
  }
}
