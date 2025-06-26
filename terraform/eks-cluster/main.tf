module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.15" # Latest as of 2023

  cluster_name                   = var.cluster_name
  cluster_version                = "1.28"
  cluster_endpoint_public_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      # Required for ALB controller
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  # Enable EBS CSI driver for persistent volumes
  enable_irsa = true
}

# AWS Load Balancer Controller
module "lb_controller" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Latest AWS Load Balancer Controller
  eks_addons = {
    aws-load-balancer-controller = {
      most_recent = true
    }
  }
}

# EBS CSI Driver
module "ebs_csi_driver" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
}

# ACM Certificate
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