# Data source to get the Route 53 hosted zone
data "aws_route53_zone" "main" {
  count = var.create_route53_record ? 1 : 0
  name  = var.route53_zone_name
}

# Request ACM certificate
resource "aws_acm_certificate" "main" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cert"
  }
}

# Create DNS record for certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = var.create_route53_record ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main[0].zone_id
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "main" {
  count                   = var.domain_name != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = var.create_route53_record ? [for record in aws_route53_record.cert_validation : record.fqdn] : []

  timeouts {
    create = "10m"
  }
}