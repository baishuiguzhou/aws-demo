locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  app_image_uri = var.app_image != "" ? var.app_image : "${aws_ecr_repository.app.repository_url}:latest"

  selected_azs = slice(
    data.aws_availability_zones.available.names,
    0,
    min(length(data.aws_availability_zones.available.names), var.az_count)
  )

  public_subnet_definitions = {
    for idx, az in local.selected_azs :
    az => {
      az   = az
      cidr = cidrsubnet(var.vpc_cidr, 8, idx)
    }
  }

  private_subnet_definitions = {
    for idx, az in local.selected_azs :
    az => {
      az   = az
      cidr = cidrsubnet(var.vpc_cidr, 8, idx + length(local.selected_azs))
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required", "opted-in"]
  }
}
