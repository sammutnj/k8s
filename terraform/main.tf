terraform {
  backend "s3" {
    bucket = "sammut-bucket"
    key    = "eks/terraform.tfstate"
    region = "ap-southeast-2"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

variable "cluster_name" {
  default = "my-k8s-cluster"
}

variable "namespace" {
  default = "kube-system"
}

variable "service_account_name" {
  default = "ebs-csi-controller-sa"
}

resource "aws_eks_cluster" "k8s_cluster" {
  name     = var.cluster_name
  role_arn = "arn:aws:iam::843960079237:role/GHA-CICD"

  vpc_config {
    subnet_ids = ["subnet-0750c0ee6baff8f23", "subnet-077c56108854be58b"]
  }
}

locals {
  cluster_oidc_issuer = aws_eks_cluster.k8s_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = local.cluster_oidc_issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd2a84e"]
}

# ALB Controller IAM Role and Policy
data "aws_iam_policy_document" "alb_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(local.cluster_oidc_issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "alb_ingress_controller" {
  name               = "alb-ingress-controller-role"
  assume_role_policy = data.aws_iam_policy_document.alb_assume_role.json
}

resource "aws_iam_policy" "alb_ingress_controller" {
  name = "AWSLoadBalancerControllerIAMPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:*",
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:GetCertificate",
          "iam:CreateServiceLinkedRole"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alb_ingress_controller_attach" {
  role       = aws_iam_role.alb_ingress_controller.name
  policy_arn = aws_iam_policy.alb_ingress_controller.arn
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.k8s_cluster.name
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = aws_eks_cluster.k8s_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.k8s_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  alias = "eks"
  kubernetes {
    host                   = aws_eks_cluster.k8s_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.k8s_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "kubernetes_service_account" "alb_ingress_controller" {
  provider = kubernetes.eks

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_ingress_controller.arn
    }
  }
}

resource "helm_release" "alb_ingress_controller" {
  provider   = helm.eks
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.k8s_cluster.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_ingress_controller.metadata[0].name
  }

  set {
    name  = "region"
    value = "ap-southeast-2"
  }

  set {
    name  = "vpcId"
    value = "vpc-0cd7460c7a84e9ed0"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/subnets"
    value = "subnet-0750c0ee6baff8f23,subnet-077c56108854be58b"
  }

  depends_on = [
    aws_iam_role_policy_attachment.alb_ingress_controller_attach,
    kubernetes_service_account.alb_ingress_controller
  ]
}

# EBS CSI Driver Role
data "aws_iam_policy_document" "ebs_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(local.cluster_oidc_issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

output "oidc_provider_url" {
  value = local.cluster_oidc_issuer
}
