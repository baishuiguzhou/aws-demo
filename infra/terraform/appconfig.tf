locals {
  appconfig_initial_content = file("${path.module}/../appconfig/config.json")
}

resource "aws_appconfig_application" "main" {
  name        = "${local.name_prefix}-appconfig"
  description = "Laravel runtime configuration managed via AWS AppConfig."
}

resource "aws_appconfig_environment" "main" {
  application_id = aws_appconfig_application.main.id
  name           = "${local.name_prefix}-env"
  description    = "Primary environment for ECS service configuration sync."
}

resource "aws_appconfig_configuration_profile" "main" {
  application_id = aws_appconfig_application.main.id
  name           = "${local.name_prefix}-config"
  description    = "Key-value settings consumed by the Laravel application."
  location_uri   = "hosted"
}

resource "aws_appconfig_deployment_strategy" "main" {
  name                           = "${local.name_prefix}-instant"
  description                    = "Instant deployment for containerized workloads."
  deployment_duration_in_minutes = 0
  final_bake_time_in_minutes     = 0
  growth_factor                  = 100
  growth_type                    = "LINEAR"
  replicate_to                   = "NONE"
}

resource "aws_appconfig_hosted_configuration_version" "main" {
  application_id           = aws_appconfig_application.main.id
  configuration_profile_id = aws_appconfig_configuration_profile.main.configuration_profile_id
  content_type             = "application/json"
  content                  = local.appconfig_initial_content
}

resource "aws_appconfig_deployment" "initial" {
  application_id           = aws_appconfig_application.main.id
  environment_id           = aws_appconfig_environment.main.environment_id
  configuration_profile_id = aws_appconfig_configuration_profile.main.configuration_profile_id
  configuration_version    = aws_appconfig_hosted_configuration_version.main.version_number
  deployment_strategy_id   = aws_appconfig_deployment_strategy.main.id
}

resource "aws_iam_role_policy" "ecs_task_appconfig" {
  name = "${local.name_prefix}-ecs-appconfig"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appconfig:StartConfigurationSession",
          "appconfig:GetLatestConfiguration",
          "appconfig:GetConfiguration"
        ]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "appconfig_sync" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/appconfig_sync"
  output_path = "${path.module}/appconfig_sync.zip"
}

resource "aws_iam_role" "appconfig_sync" {
  name = "${local.name_prefix}-appconfig-sync"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "appconfig_sync" {
  name = "${local.name_prefix}-appconfig-sync"
  role = aws_iam_role.appconfig_sync.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "appconfig_sync" {
  function_name    = "${local.name_prefix}-appconfig-sync"
  role             = aws_iam_role.appconfig_sync.arn
  runtime          = "python3.12"
  handler          = "main.lambda_handler"
  timeout          = 30
  filename         = data.archive_file.appconfig_sync.output_path
  source_code_hash = data.archive_file.appconfig_sync.output_base64sha256

  environment {
    variables = {
      ECS_CLUSTER   = aws_ecs_cluster.main.name
      ECS_SERVICE   = aws_ecs_service.app.name
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "appconfig_deployments" {
  name        = "${local.name_prefix}-appconfig-events"
  description = "Trigger ECS refresh and notifications when AppConfig releases change."
  event_pattern = jsonencode({
    "source" : ["aws.appconfig"],
    "detail-type" : ["AppConfig Deployment State Change"],
    "detail" : {
      "applicationId" : [aws_appconfig_application.main.id],
      "environmentId" : [aws_appconfig_environment.main.environment_id]
    }
  })
}

resource "aws_cloudwatch_event_target" "appconfig_deployments" {
  rule      = aws_cloudwatch_event_rule.appconfig_deployments.name
  target_id = "appconfig-sync"
  arn       = aws_lambda_function.appconfig_sync.arn
}

resource "aws_lambda_permission" "allow_eventbridge_appconfig" {
  statement_id  = "AllowAppConfigEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.appconfig_sync.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.appconfig_deployments.arn
}
