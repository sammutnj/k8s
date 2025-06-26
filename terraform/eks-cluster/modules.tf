# EKS Cluster Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.15"

  cluster_name                   = var.CLUSTER_NAME
  cluster_version                = "1.28"
  cluster_endpoint_public_access = true

  # Use existing IAM role instead of creating new one
  create_iam_role = false
  iam_role_arn    = var.EKS_CLUSTER_IAM_ROLE_ARN

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 1
      desired_size = 1

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      # Use existing node group IAM role
      create_iam_role = false
      iam_role_arn    = var.EKS_NODEGROUP_IAM_ROLE_ARN

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  enable_irsa = true
}

# AWS Load Balancer Controller Module
module "lb_controller" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-load-balancer-controller = {
      most_recent = true
      configuration_values = jsonencode({
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = var.LB_CONTROLLER_IAM_ROLE_ARN
          }
        }
      })
    }
  }
}

# EBS CSI Driver Module
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
      configuration_values = jsonencode({
        controller = {
          serviceAccount = {
            annotations = {
              "eks.amazonaws.com/role-arn" = var.EBS_CSI_IAM_ROLE_ARN
            }
          }
        }
      })
    }
  }
}