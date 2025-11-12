variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Base name prefix for resources"
  type        = string
  default     = "poper-devops"
}

variable "environment" {
  description = "Deployment environment identifier"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the primary VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to span for subnets"
  type        = number
  default     = 2
}

variable "flow_logs_retention_days" {
  description = "CloudWatch Logs retention (days) for VPC flow logs"
  type        = number
  default     = 30
}

variable "app_image" {
  description = "Container image URI for the Laravel application"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:latest"
}

variable "container_port" {
  description = "Container port exposed by the application"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate task CPU units (e.g. 256, 512, 1024)"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory in MiB (e.g. 1024)"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Default desired count for the ECS service outside peak schedule"
  type        = number
  default     = 1
}

variable "scale_up_desired_count" {
  description = "Desired count during the scheduled peak window (17:00-17:59 JST)"
  type        = number
  default     = 2
}

variable "scale_up_cron" {
  description = "Cron expression (UTC) for scaling up to peak desired count"
  type        = string
  default     = "cron(0 8 * * ? *)" # 17:00 JST
}

variable "scale_down_cron" {
  description = "Cron expression (UTC) for scaling back after the peak window"
  type        = string
  default     = "cron(0 9 * * ? *)" # 18:00 JST
}

variable "alb_allowed_cidrs" {
  description = "List of CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_log_retention_days" {
  description = "Retention in days for ECS application CloudWatch logs"
  type        = number
  default     = 30
}

variable "alert_emails" {
  description = "Email addresses subscribed to SNS alerts (deploy, backup failures, etc.)"
  type        = list(string)
  default     = []
}

variable "backup_task_image" {
  description = "Container image that includes pg_dump and awscli for database backups"
  type        = string
  default     = "public.ecr.aws/docker/library/postgres:16"
}

variable "backup_task_cpu" {
  description = "Fargate CPU units for the backup task"
  type        = number
  default     = 256
}

variable "backup_task_memory" {
  description = "Fargate memory (MiB) for the backup task"
  type        = number
  default     = 512
}

variable "backup_schedule_cron" {
  description = "EventBridge cron expression (UTC) for daily pg_dump backups"
  type        = string
  default     = "cron(0 15 * * ? *)" # 00:00 JST
}

variable "db_instance_class" {
  description = "RDS PostgreSQL instance class (e.g., db.t4g.micro)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage (GiB) for the RDS instance"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial PostgreSQL database name"
  type        = string
  default     = "laravel"
}

variable "db_username" {
  description = "Master username for PostgreSQL"
  type        = string
  default     = "laravel"
}

variable "db_password" {
  description = "Master password for PostgreSQL"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated RDS backups"
  type        = number
  default     = 7
}

variable "create_rds_backup_bucket" {
  description = "Whether Terraform should create/manage the RDS backup S3 bucket"
  type        = bool
  default     = false
}

variable "external_rds_backup_bucket_name" {
  description = "Existing S3 bucket name to hold pg_dump backups when Terraform is not creating one"
  type        = string
  default     = ""
}
