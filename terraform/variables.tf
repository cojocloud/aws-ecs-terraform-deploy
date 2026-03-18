#Variables for AWS infrastructure
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "attendance-app"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8000
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "attendancedb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "ecs_task_cpu" {
  description = "Fargate task CPU units"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "Fargate task memory in MB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 2
}

variable "health_check_path" {
  description = "Health check endpoint"
  type        = string
  default     = "/login"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "cojocloudsolutions.com"
}

variable "route53_zone_name" {
  description = "Route 53 hosted zone name (cojocloudsolutions.com)"
  type        = string
  default     = "cojocloudsolutions.com"
}

variable "create_route53_record" {
  description = "Whether to create Route 53 DNS record"
  type        = bool
  default     = false
}
