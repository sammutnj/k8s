resource "aws_acm_certificate" "nginx" {
  count = var.create_acm_certificate ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Route53 validation (if using Route53)
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.nginx.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "nginx" {
  certificate_arn         = aws_acm_certificate.nginx.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}