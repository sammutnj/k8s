locals {
  certificate_arn = var.create_acm_certificate ? aws_acm_certificate.nginx[0].arn : var.acm_certificate_arn
}