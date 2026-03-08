output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Application URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.main.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "ecr_push_commands" {
  description = "Commands to push Docker image to ECR"
  value = <<-EOT
    # Login to ECR
    aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.main.repository_url}
    
    # Tag your image
    docker tag attendance-app:latest ${aws_ecr_repository.main.repository_url}:latest
    
    # Push to ECR
    docker push ${aws_ecr_repository.main.repository_url}:latest
  EOT
}

output "application_url" {
  description = "Application URL (custom domain or ALB DNS)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].arn : "N/A - No certificate created"
}

output "route53_record" {
  description = "Route 53 DNS record"
  value       = var.create_route53_record ? aws_route53_record.main[0].fqdn : "N/A - No Route 53 record created"
}
