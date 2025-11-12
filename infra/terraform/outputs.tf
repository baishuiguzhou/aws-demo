output "caller_account_id" {
  description = "AWS account ID detected by Terraform"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "Region in use"
  value       = data.aws_region.current.name
}

output "vpc_id" {
  description = "ID of the primary VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs by AZ"
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "private_subnet_ids" {
  description = "Private subnet IDs by AZ"
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs"
  value       = { for az, nat in aws_nat_gateway.this : az => nat.id }
}

output "vpc_flow_log_group_name" {
  description = "CloudWatch Log Group collecting VPC flow logs"
  value       = aws_cloudwatch_log_group.vpc_flow.name
}

output "ecr_repository_url" {
  description = "URI of the application ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "Name of the application ECR repository"
  value       = aws_ecr_repository.app.name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "ecs_task_execution_role_arn" {
  description = "IAM role ARN used for ECS task execution"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_security_group_id" {
  description = "Security group applied to ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "alb_security_group_id" {
  description = "Security group applied to the ALB"
  value       = aws_security_group.alb.id
}

output "rds_endpoint" {
  description = "Primary endpoint for the PostgreSQL instance"
  value       = aws_db_instance.postgres.address
}

output "rds_security_group_id" {
  description = "Security group protecting the RDS instance"
  value       = aws_security_group.rds.id
}

output "rds_backup_bucket_name" {
  description = "S3 bucket receiving pg_dump backups"
  value       = local.rds_backup_bucket_name
}

output "appconfig_application_id" {
  description = "AppConfig application identifier"
  value       = aws_appconfig_application.main.id
}

output "appconfig_environment_id" {
  description = "AppConfig environment identifier"
  value       = aws_appconfig_environment.main.environment_id
}

output "appconfig_configuration_profile_id" {
  description = "AppConfig configuration profile identifier"
  value       = aws_appconfig_configuration_profile.main.configuration_profile_id
}

output "appconfig_lambda_name" {
  description = "Lambda handling AppConfig deployment events"
  value       = aws_lambda_function.appconfig_sync.function_name
}

output "alerts_topic_arn" {
  description = "SNS topic used for operational notifications"
  value       = aws_sns_topic.alerts.arn
}

output "github_actions_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions via OIDC"
  value       = aws_iam_role.github_oidc.arn
}
